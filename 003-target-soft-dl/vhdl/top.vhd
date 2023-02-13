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
-- 6502 board top

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library r65c02_tc;
use r65c02_tc.all;

library b65;
use b65.PACK.all;

-------------------------------------------------------------------------------
-- Entity

entity top is
port	(
			-- General
			clock					: in		std_logic;								-- Clock
			reset					: in		std_logic;								-- reset

			-- Interface
			led						: out		std_logic_vector(15 downto 0);			-- Output leds
			slide					: in		std_logic_vector(15 downto 0);			-- Input slides
			push					: in		std_logic_vector( 3 downto 0);			-- Input push buttons

			-- 4x 7segments digits
			anode					: out		std_logic_vector(3 downto 0);			-- Anode  7 segments driver
			cathode					: out		std_logic_vector(7 downto 0);			-- Cathod 7 segments driver (DOT,G,F,E,D,C,B,A)

			-- UART
			uart_rx					: in		std_logic;								-- UART receive
			uart_tx					: out		std_logic								-- UART transmit
		);
end top;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of top is

	----------------------------------------------------------------------------
	-- Signals

	-- Clock
	signal clock_50M			: std_logic;								-- System clock @ 50MHz
	signal clock_5M				: std_logic;								-- CPU    clock @  1MHz

	-- General
	signal locked				: std_logic;
	signal locked_delay			: std_logic_vector ( 7 downto 0);
	signal reset_system			: std_logic							:= '1';	-- Reset
	signal reset_cpu			: std_logic							:= '0';	-- Reset (CPU only)

	-- Ram
	signal ram_enable			: std_logic;
	signal ram_read_data		: std_logic_vector ( 7 downto 0);
	signal ram_write_data		: std_logic_vector ( 7 downto 0);
	signal ram_write_enable		: std_logic_vector ( 0 downto 0);
	signal ram_address			: std_logic_vector (15 downto 0);

	-- Rom
	signal rom_enable			: std_logic;
	signal rom_enable_cpu		: std_logic;
	signal rom_data				: std_logic_vector ( 7 downto 0);
	signal rom_base				: std_logic_vector (15 downto 0);
	signal rom_address			: std_logic_vector (12 downto 0);
	signal rom_address_cpu		: std_logic_vector (12 downto 0);
	signal rom_address_soft_dl	: std_logic_vector (12 downto 0)	:= (others => '0');
	signal rom_write_data		: std_logic_vector ( 7 downto 0)	:= (others => '0');
	signal rom_write_enable		: std_logic_vector ( 0 downto 0)	:= (others => '0');

	-- I/O Extension
	signal ext_enable			: std_logic;
	signal ext_read_data		: std_logic_vector ( 7 downto 0);
	signal ext_write_data		: std_logic_vector ( 7 downto 0);
	signal ext_write_enable		: std_logic;
	signal ext_address			: std_logic_vector ( 3 downto 0);
	signal ext_base				: std_logic_vector (15 downto 0);
	signal ext_digit			: LED7X4;

	-- 6502 CPU
	signal cpu_address			: std_logic_vector (15 downto 0);
	signal cpu_data_in			: std_logic_vector ( 7 downto 0);
	signal cpu_data_out			: std_logic_vector ( 7 downto 0);
	signal cpu_write_enable		: std_logic;
	signal cpu_irq				: std_logic;

	-- 7 segments driver
	signal digit_delay			: std_logic_vector(23 downto 0);
	signal digit_select			: std_logic_vector( 3 downto 0);
	signal digit_select_id		: integer range 0 to 3;
	
	-- UART serializer component
	signal uart_busy			: std_logic;
	signal uart_rx_byte			: std_logic_vector(7 downto 0);
	signal uart_rx_valid		: std_logic;
	signal uart_tx_byte			: std_logic_vector(7 downto 0);
	signal uart_tx_valid		: std_logic;

	-- Led (muxed between ext and soft-dl)
	signal led_ext				: std_logic_vector(15 downto 0);
	signal led_soft_dl			: std_logic_vector(15 downto 0);

	----------------------------------------------------------------------------
	-- Components

	component core is
	port	(
				clk_clk_i				: in		std_logic ;
				d_i						: in		std_logic_vector( 7 downto 0);
				irq_n_i					: in		std_logic ;
				nmi_n_i					: in		std_logic ;
				rdy_i					: in		std_logic ;
				rst_rst_n_i 			: in		std_logic ;
				so_n_i					: in		std_logic ;
				a_o						: out		std_logic_vector(15 downto 0);
				d_o						: out		std_logic_vector( 7 downto 0);
				rd_o					: out		std_logic ;
				sync_o					: out		std_logic ;
				wr_n_o					: out		std_logic ;
				wr_o					: out		std_logic 
			);
	end component;
 
begin
	---------------------------------------------------------------------------
	-- Hardwired

--  ram_base			<= it's cpu_address;
	ext_base			<= cpu_address - MAP_START_REG;
	rom_base			<= cpu_address - MAP_START_ROM;

	-- Mux selecting CPU or soft-dl blocks
	rom_address			<= rom_address_soft_dl	when (reset_cpu = '0') else rom_address_cpu;
	rom_enable			<= '1'					when (reset_cpu = '0') else rom_enable_cpu;

	led					<= led_soft_dl			when (reset_cpu = '0') else led_ext;

	----------------------------------------------------------------------------
	-- Components map

	-- CPU is clocked at 5MHz because the FPGA cannot generate lower frequencies clocks

	inst_clock_manager : clock_manager
	port map	(
					-- General
					clk_in1						=> clock,				-- Input clock
					reset						=> reset,
					locked						=> locked,

					-- Generated clocks
					clk_out1					=> clock_50M,			-- fpga 50MHz clock
					clk_out2					=> clock_5M				-- CPU 6502 (6502 chip pin 37) input clock (5MHz)
				);

	inst_core6502 : core
	port map	(
					 clk_clk_i					=> clock_5M,
					 d_i						=> cpu_data_in,			-- data in                    input
					 irq_n_i					=> cpu_irq,				-- interrupt                  input (active low)
					 nmi_n_i					=> '1',					-- non maskable interrupt     input (active low)
					 rdy_i						=> '1',					-- ready                      input
					 rst_rst_n_i				=> reset_cpu,			-- reset                      input (active low)
					 so_n_i						=> '1',					-- set overflow               input (active low)

					 a_o						=> cpu_address,			-- address                    output
					 d_o						=> cpu_data_out,		-- data out                   output
					 rd_o						=> open,
					 sync_o						=> open,				-- high during ph1 (op fetch) output
					 wr_n_o						=> open,
					 wr_o						=> cpu_write_enable		-- write enable               output
				);

	-- RAM and ROM are synchronous @50MHz vs CPU at @5MHz: it's like having asynchronous devices as in retro boards
	--                      ___     ___     ___     ___     ___     ___     ___     ___     ___     ___     __
	--  50MHz          ____|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|   |___|
	--                      _______________________________________                                         __
	--   5MHz          ____|                                       |_______________________________________|
	--                      __________________________________________________________________________________
	--  CPU address    ____/ VALID address out
	--                     \__________________________________________________________________________________
	--                              __________________________________________________________________________
	--  Device enable  ____________|
	--                              __________________________________________________________________________
	--  Device address ____________/ VALID address to the device (RAM/ROM) input
	--                             \__________________________________________________________________________
	--                                      __________________________________________________________________
	--  Data           ____________________/ VALID data
	--                                     \__________________________________________________________________
	--                 
	--                     |<---- Ta ----->|
	--
	-- Ta (Access time) is the equivalent asynchronous device access time, in this case it's 40ns (2 clock pulses at 50MHz)

	inst_ram : ram
	port map	(
					-- General
					clka						=> clock_50M,
					ena							=> ram_enable,
					rsta						=> reset_system,
					rsta_busy					=> open,

					-- Read / Write interface
					addra						=> ram_address,
					wea							=> ram_write_enable,
					dina						=> ram_write_data,
					douta						=> ram_read_data
				);

	-- Code ram - the rom in previous targets
	inst_ram_code : ram_code
	port map	(
					-- General
					clka						=> clock_50M,
					ena							=> rom_enable,
					rsta						=> reset_system,

					-- Read interface   
					addra						=> rom_address,
					wea							=> rom_write_enable,
					douta						=> rom_data,
					dina						=> rom_write_data					
				);
	
	inst_uart : uart
	port map	(
					-- General
					clock						=> clock_50M,
					reset						=> reset_system,
					busy						=> uart_busy,

					-- Serial interface
					uart_rx						=> uart_rx,
					uart_tx						=> uart_tx,
		
					-- incoming data
					rx_byte						=> uart_rx_byte,
					rx_valid					=> uart_rx_valid,

					-- outgoing data
					tx_byte						=> uart_tx_byte,
					tx_valid					=> uart_tx_valid
				);

	inst_ext : ext
	port map	(
					-- General
					clock						=> clock_50M,
					reset						=> reset_system,
					enable						=> ext_enable,
					enable_inputs				=> reset_cpu,
					interrupt					=> cpu_irq,

					-- Write interface
					write_address				=> ext_address,
					write_enable				=> ext_write_enable,
					write_data					=> ext_write_data,

					-- Read interface
					read_address				=> ext_address,
					read_data					=> ext_read_data,
					
					-- I/O
					outputs						=> led_ext,
					inputs						=> "0000" & push & slide,			-- TODO : debounce slide and push
					digit						=> ext_digit,

					-- UART
					uart_busy					=> uart_busy,

					uart_rx_byte				=> uart_rx_byte,
					uart_rx_valid				=> uart_rx_valid,
					uart_tx_byte				=> uart_tx_byte,
					uart_tx_valid				=> uart_tx_valid
				);

	inst_soft_dl: soft_dl
	port map	(
					-- General
					clock						=> clock_50M,
					reset						=> reset_system,
					reset_cpu					=> reset_cpu,
					led							=> led_soft_dl,

					-- UART data receive
					uart_rx_data				=> uart_rx_byte,
					uart_rx_valid				=> uart_rx_valid,

					-- Code ram write interface
					write_address				=> rom_address_soft_dl,
					write_enable				=> rom_write_enable,
					write_data					=> rom_write_data
				);

	---------------------------------------------------------------------------
	-- Processes

	-- Reset handling
	proc_lock : process(clock_50M) begin
		if (clock_50M'event and clock_50M='1') then
			-- If reset
			if (reset = '1') then
				reset_system									<= '1';
				locked_delay									<= (others => '0');
			else
				if (locked = '0') then
					locked_delay								<= (others => '0');
				else
					if (locked_delay /= x"20") then
						locked_delay							<= locked_delay + 1;
					end if;
					
					-- Remove system reset
					if (locked_delay = x"10") then
						reset_system							<= '0';
					end if;

					-- Remove system and CPU reset
					if (locked_delay = x"20") then
						reset_system							<= '0';
					end if;
				end if;
			end if;
		end if; -- clock event
	end process;

	-- Select the target component
	proc_select : process(clock_50M) begin
		if (clock_50M'event and clock_50M='1') then
			-- If reset
			if (reset_system = '1') then
				cpu_data_in										<= (others => '0');

				ram_enable										<= '0';
				ram_address										<= (others => '0');

				ext_enable										<= '0';
				ext_write_data									<= (others => '0');
				ext_address										<= (others => '0');

				rom_enable_cpu									<= '0';
				rom_address_cpu									<= (others => '0');
			else
				ram_enable										<= '0';
				ext_enable										<= '0';
				rom_enable_cpu									<= '0';
				
				if (conv_integer(cpu_address) >= MAP_START_ROM) then
					-- ROM access
					rom_enable_cpu								<= '1';
					rom_address_cpu								<= rom_base(12 downto 0);
					cpu_data_in									<= rom_data;

				elsif (conv_integer(cpu_address) >= MAP_START_REG) and (conv_integer(cpu_address) <= MAP_START_REG + 15) then
					-- I/O EXTENSION access
					ext_enable									<= reset_cpu;			-- disable ext if cpu is reset
					cpu_data_in									<= ext_read_data;
					ext_address									<= ext_base(3 downto 0);
					ext_write_data								<= cpu_data_out;
					ext_write_enable							<= cpu_write_enable;

				elsif (conv_integer(cpu_address) >= MAP_START_REG) then
					-- Registers access - unused

				else
					-- RAM access
					ram_enable									<= '1';
					cpu_data_in									<= ram_read_data;
					ram_address									<= cpu_address;
					ram_write_data								<= cpu_data_out;
					ram_write_enable(0)							<= cpu_write_enable;
				end if;
			end if; -- reset
		end if; -- clock event
	end process;

	-- Generate 7 segments digits signals
	digits_gen : process(clock_50M) begin
		if (clock_50M'event and clock_50M='1') then
			-- If (system is in reset state)
			if (reset_system = '1') then
				anode											<= (others => '1');
				cathode											<= (others => '1');
				digit_delay										<= (others => '0');
				digit_select									<= "1000";
				digit_select_id									<= 3;
			else
				-- Drive the output inverting the signals
				anode											<= not digit_select;
				cathode											<= not ext_digit(digit_select_id);

				digit_delay										<= digit_delay + 1;

				-- Wait for refresh delay:  50MHz clock and a delay of 4ms : 4m * 50M = 200000 = x030D40
				if (digit_delay = x"030D40") then
					digit_delay									<= (others => '0');
					digit_select								<= digit_select(2 downto 0) & digit_select(3);
					
					if (digit_select_id = 3) then
						digit_select_id							<= 0;
					else
						digit_select_id							<= digit_select_id + 1;
					end if;
				end if;
			end if;
		end if;
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
