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
-- 6502 board simulation testbench

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library b65;
use b65.PACK.all;

-------------------------------------------------------------------------------
-- Entity

entity board is
end board;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of board is

	----------------------------------------------------------------------------
	-- Data types

	-- FSM - UART Control
	TYPE FSM_CTRL	is (ct_reset, ct_wait, ct_complete);

	----------------------------------------------------------------------------
	-- Signals

	-- Clock
	signal clock				: std_logic;											-- System clock @ 50MHz

	-- Reset
	signal reset				: std_logic;											-- Reset

	-- I/O
	signal slide				: std_logic_vector(15 downto 0);						-- Input slides
	signal push					: std_logic_vector( 3 downto 0);						-- Input push buttons

	-- UART serializer component
	signal uart_control			: FSM_CTRL;												-- UART echo control FSM state
	signal uart_rx				: std_logic;
	signal uart_tx				: std_logic;
	signal uart_busy			: std_logic;
	signal uart_rx_byte			: std_logic_vector(7 downto 0);
	signal uart_rx_valid		: std_logic;
	signal uart_tx_byte			: std_logic_vector(7 downto 0);
	signal uart_tx_valid		: std_logic;

	----------------------------------------------------------------------------
	-- Components

	component top is
	port(
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
	end component;
 
begin
	----------------------------------------------------------------------------
	-- Components map

	int_top : top
	port map	(
					-- General
					clock					=> clock,
					reset					=> reset,

					led						=> open,
					slide					=> slide,
					push					=> push,
					anode					=> open,
					cathode					=> open,
					uart_rx					=> uart_rx,
					uart_tx					=> uart_tx
			);
 
 	----------------------------------------------------------------------------
	-- Components map
	
	inst_uart : uart
	generic map	(
					clock_frequency				=> 50000000,		-- clock frequency in hertz
					baud_rate					=> 9600,			-- desired baud rate
					start_silence				=> 32				-- Number of bytes to discard at start if line is not idle
				)
	port map	(
					-- General
					clock						=> clock,
					reset						=> reset,
					busy						=> uart_busy,

					-- Serial interface
					uart_rx						=> uart_tx,	-- Invert RX/TX respect to CPU
					uart_tx						=> uart_rx,
		
					-- incoming data
					rx_byte						=> uart_rx_byte,
					rx_valid					=> uart_rx_valid,

					-- outgoing data
					tx_byte						=> uart_tx_byte,
					tx_valid					=> uart_tx_valid
		);

	---------------------------------------------------------------------------
	-- Processes

	-- FPGA clock generator
	fpga_clock : process begin
		clock		<= '0';
		wait for (10 ns);
		loop
			clock	<= '0';
			wait for (10 ns);
			clock	<= '1';
			wait for (10 ns);
		end loop;
	end process;

	-- Simulation
	proc_reset : process begin

		push		<= (others => '0');
		slide		<= (others => '0');
		reset		<= '1';

		wait for  500 ns;
		wait until rising_edge(clock);
		reset		<= '0';

		-- push a button
		wait for  2 ms;
		push(0)		<= '1';
		wait for  1 ms;
		push(0)		<= '0';

		-- move a slide
		wait for  2 ms;
		slide(8)	<= '1';

		wait;
	end process;
	
	-- UART echo
	uart_echo : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				-- reset state
				uart_tx_byte						<= x"00";
				uart_tx_valid						<= '0';
				uart_control						<= ct_reset;
			else
				case (uart_control) is

					-- reset state
					when ct_reset =>
						uart_control				<= ct_reset;
						uart_tx_byte				<= x"00";
						uart_tx_valid				<= '0';
						
						-- if UART is not busy, wait for an incoming data
						if (uart_busy = '0') then
							uart_control			<= ct_wait;
						end if;

					-- wait for an incoming byte and echo it
					when ct_wait =>
						uart_control				<= ct_wait;
						uart_tx_byte				<= x"00";
						uart_tx_valid				<= '0';

						-- if UART is not busy and new data is incoming
						if (uart_busy = '0' and uart_rx_valid = '1') then
							uart_tx_byte			<= uart_rx_byte;
							uart_tx_valid			<= '1';
							uart_control			<= ct_complete;
						end if;

					-- complete sending operation
					when ct_complete =>
						uart_control				<= ct_complete;
						uart_tx_byte				<= x"00";
						uart_tx_valid				<= '0';

						-- when UART accepted transmission, go to reset state
						if (uart_busy = '1') then
							uart_control			<= ct_reset;
						end if;

					-- Alignment state
					when others =>
						uart_control				<= ct_reset;
				end case;
			end if; -- reset
		end if; -- clock
	end process;	

end behavioral;

-------------------------------------------------------------------------------
-- EOF
