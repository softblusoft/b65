-- Copyright 2023 Luca Bertossi
--
-- This file is part of B65.
-- 
--     B65 is free software: you can redistribute it and/or modify
--     it under the terms of the GNU General Public License as published by
--     the Free Software Foundation, either version 3 of the License, or
--     (at your option) any later version.
-- 
--     B65 is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--     GNU General Public License for more details.
-- 
--     You should have received a copy of the GNU General Public License
--     along with B65.  If not, see <http://www.gnu.org/licenses/>.

-------------------------------------------------------------------------------
-- b65 memory map (see software b65.cfg configuration file)
--
--		0x0000       0         RAM          (56320 bytes = 55 KB)
--		                       |
--		0xDBFF   56319         v        <-- (Stack is 0x400 bytes, growing from 0xDBFF to 0xD800)
--		0xDC00   56320         \
--		                        | Registers (1024 bytes =  1 KB)
--		0xDFFF   57343         /
--		0xE000   57344         ^
--		                       |
--		                       |
--		0xFFFF   65535        ROM start     (8192 bytes =  8 KB)

-------------------------------------------------------------------------------
-- The 6502 chip mirrors out the input clock, in this design this is
-- done in clockgenerator
---
--  - ph0 and ph1,ph2 could have a minimum delay (neglected)
--  - ph1 and ph2 are inverted without delay
--
--		                    +------+
--		 1MHz input ph0 -->	|      | ---> ph1
--		                    | 6502 |
--		                    |      | ---> ph2
--		                    +------+
--		         ___     ___     ___
--		 ph0 ___|   |___|   |___|   |___
--		         ___     ___     ___
--		 ph1 ___|   |___|   |___|   |___
--		     ___     ___     ___     ___
--		 ph2    |___|   |___|   |___|

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library b65;

-------------------------------------------------------------------------------
-- Package

package PACK is

	----------------------------------------------------------------------------
	-- Constants

	constant ROM_FILE		: string			:= "b65.rom";								-- rom filename
	constant ROM_FILL		: std_logic_vector	:= x"FF";									-- rom fill value

	constant MAP_START_RAM	: integer			:= conv_integer(x"0000");					-- start address     0 : RAM
	constant MAP_START_REG	: integer			:= conv_integer(x"DC00");					-- start address 56320 : devices registers
	constant MAP_START_ROM	: integer			:= conv_integer(x"E000");					-- start address 57344 : ROM (growing from 0xFFFF down to 0xE000)

	constant MAP_SIZE_RAM	: integer			:= conv_integer(x"DC00");					-- size  in bytes      : RAM
	constant MAP_SIZE_REG	: integer			:= conv_integer(x"0400");					-- size  in bytes      : devices registers
	constant MAP_SIZE_ROM	: integer			:= conv_integer(x"2000");					-- size  in bytes      : ROM

	----------------------------------------------------------------------------
	-- Data types

	-- 7 segments (+ dot) LED display x 4 digits
	--
	--   --      --      --      --             a
	--  |  |    |  |    |  |    |  |          f   b
	--   --      --      --      --      ->     g
	--  |  |    |  |    |  |    |  |          e   c 
	--   --  .   --  .   --  .   --  .          d   .
	--
	--
	--   0       1       2       3     -> array(0 to 3)
	--
	-- std_logic_vector(7 downto 0) is organized as '.gfedcba'
	--                                               |
	--                                           display dot bit 7
	--
	type LED7X4 is array(0 to 3) of std_logic_vector(7 downto 0);

	----------------------------------------------------------------------------
	-- Procedures
	
	procedure Log(message : in string);

	----------------------------------------------------------------------------
	-- Components

	component clock_manager is
	port	(
				-- General
				clk_in1					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset
				locked					: out		std_logic;								-- locked
				
				-- Generated clocks
				clk_out1				: out		std_logic;								-- 50MHz FPGA
				clk_out2				: out		std_logic								--  5MHz 6502 CPU ph0
			);
	end component;

	component ram is
	port	(
				-- General
				clka					: in		std_logic;								-- Clock
				ena						: in		std_logic;								-- enable
				rsta					: in		std_logic;								-- reset
				rsta_busy				: out		std_logic;								-- busy

				-- Read / Write interface
				addra					: in		std_logic_vector(15	downto 0);			-- Ram write Address
				wea						: in		std_logic_vector(0	downto 0);			-- Write enable
				dina					: in		std_logic_vector( 7	downto 0);			-- Data IN
				douta					: out		std_logic_vector( 7	downto 0)			-- Data OUT
			);
	end component;

	component ram_code is
	port	(
				-- General
				clka					: in		std_logic;								-- Clock
				ena						: in		std_logic;								-- enable
				rsta					: in		std_logic;								-- reset
				rsta_busy				: out		std_logic;								-- busy

				-- Read / Write interface
				addra					: in		std_logic_vector(12	downto 0);			-- Ram write Address
				wea						: in		std_logic_vector(0	downto 0);			-- Write enable
				dina					: in		std_logic_vector( 7	downto 0);			-- Data IN
				douta					: out		std_logic_vector( 7	downto 0)			-- Data OUT
			);
	end component;

	component ext is
	port	(
				-- General
				clock					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset
				enable					: in		std_logic;								-- block enable
				enable_inputs			: in		std_logic;								-- enable inputs and Rx
				interrupt				: out		std_logic;								-- interrupt
				upgrade					: out		std_logic;								-- upgrade restart

				-- Write interface
				write_address			: in		std_logic_vector( 3	downto 0);			-- write Address
				write_enable			: in		std_logic;								-- Write enable
				write_data				: in		std_logic_vector( 7	downto 0);			-- Data IN

				-- Read interface
				read_address			: in		std_logic_vector( 3	downto 0);			-- read Address
				read_data				: out		std_logic_vector( 7	downto 0);			-- Data OUT
				
				-- I/O
				outputs					: out		std_logic_vector(15	downto 0);			-- Output wires
				inputs					: in		std_logic_vector(23	downto 0);			-- Input  wires
				digit					: out		LED7X4;									-- 4x 7-segments digits

				-- UART
				uart_busy				: in		std_logic;								-- UART busy
				uart_rx_byte			: in		std_logic_vector(7 downto 0);			-- Received data
				uart_rx_valid			: in		std_logic;								-- High if received data is valid
				uart_tx_byte			: out		std_logic_vector(7 downto 0);			-- Byte to send
				uart_tx_valid			: out		std_logic								-- High for one clock pulse to start transmission
			);
	end component;

	component uart is
	generic	(
				clock_frequency			:			integer				:= 50000000;		-- clock frequency in hertz
				baud_rate				:			integer				:= 921600;			-- desired baud rate
				start_silence			:			integer				:= 32				-- Number of bytes to discard at start if line is not idle
			);
	port	(
				-- General
				clock					: in		std_logic;								-- Main clock (assumed to be 32 MHz)
				reset					: in		std_logic;								-- Reset FSM
				busy					: out		std_logic;								-- High if busy

				-- Serial interface
				uart_rx					: in		std_logic;								-- UART receive pin
				uart_tx					: out		std_logic;								-- UART transmit pin
				
				-- incoming data
				rx_byte					: out		std_logic_vector(7 downto 0);			-- Received data
				rx_valid				: out		std_logic;								-- High if received_data is valid

				-- outgoing data
				tx_byte					: in		std_logic_vector(7 downto 0);			-- Byte to send to UART
				tx_valid				: in		std_logic								-- High for one clock pulse to start transmission
		);
	end component;
	
	component soft_dl is
	port	(
				-- General
				clock					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset
				reset_cpu				: out		std_logic;								-- CPU reset
				reset_devices			: out		std_logic;								-- CPU devices
				led						: out		std_logic_vector(15 downto 0);			-- Led
				upgrade					: in		std_logic;								-- upgrade restart

				-- UART data receive
				uart_rx_data			: in		std_logic_vector(7 downto 0);			-- UART received data
				uart_rx_valid			: in		std_logic;								-- UART received data valid

				-- Code ram write interface
				write_address			: out		std_logic_vector(12	downto 0);			-- write Address
				write_enable			: out		std_logic_vector( 0 downto 0);			-- Write enable
				write_data				: out		std_logic_vector( 7	downto 0)			-- Data IN
			);
	end component;

	component debounce is
	generic (
				active_high				: 			std_logic			:= '1'				-- Button logic (active high = signal_in is high if button is pressed)
			);
	port	(
				-- General
				clock					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- Reset

				-- Signal input
				signal_in				: in		std_logic;								-- Input signal

				-- Signal output
				button_down				: out		std_logic;								-- "button down" event (1CK on button event)
				button_up				: out		std_logic								-- "button up" event   (1CK on button event)
			);
	end component;

end PACK;

package body PACK is

	----------------------------------------------------------------------------
	-- Procedures implementation
	
	procedure Log(message : in string) is
		variable var_log	: line;	
	begin
		-- Insert timestamp
		write(var_log, now, right, 12);
		write(var_log, string'(": "));
		
		-- Insert user log message
		write(var_log, message);

		-- Write to output
		writeline(output, var_log);
	end Log;

end PACK;

-------------------------------------------------------------------------------
-- EOF
