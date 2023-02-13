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
	-- Constants

	constant filename	: string	:= "b65.rom";	-- rom filename

	----------------------------------------------------------------------------
	-- Data types

	-- FSM - UART Control
	TYPE FSM_CTRL	is (ct_reset, ct_wait, ct_complete);

	-- FSM - Donwload softwaew
	TYPE FSM_DL	is (dl_wait, dl_run, dl_pause, dl_restart, dl_done);

	-- File types
	type CHAR_FILE is file of character;

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
	signal uart_tx_byte_echo	: std_logic_vector(7 downto 0);
	signal uart_tx_valid_echo	: std_logic;
	signal uart_tx_byte_soft_dl	: std_logic_vector(7 downto 0);
	signal uart_tx_valid_soft_dl: std_logic;
	
	-- Software download simulation
	signal download_control		: FSM_DL;												-- Download control FSM
	signal download_done		: std_logic							:= '0';				-- Download done flag
	signal download_wait		: integer range 0 to 63;								-- Download wait

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
	---------------------------------------------------------------------------
	-- Hardwired

	uart_tx_byte	<= uart_tx_byte_soft_dl		when (download_done = '0') else uart_tx_byte_echo;
	uart_tx_valid	<= uart_tx_valid_soft_dl	when (download_done = '0') else uart_tx_valid_echo;

	----------------------------------------------------------------------------
	-- Components map

	int_top : top
	port map	(
					-- General
					clock						=> clock,
					reset						=> reset,

					led							=> open,
					slide						=> slide,
					push						=> push,
					anode						=> open,
					cathode						=> open,
					uart_rx						=> uart_rx,
					uart_tx						=> uart_tx
			);
 	
	inst_uart : uart
	generic map	(
					clock_frequency				=> 50000000,		-- clock frequency in hertz
					baud_rate					=> 921600,			-- desired baud rate
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

		-- wait for software downloaded flag
		wait until rising_edge(download_done);
		wait for 1 ms;
		Log("Continuing with inputs simulation");

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
				uart_tx_byte_echo					<= x"00";
				uart_tx_valid_echo					<= '0';
				uart_control						<= ct_reset;
			else
				case (uart_control) is

					-- reset state
					when ct_reset =>
						uart_control				<= ct_reset;
						uart_tx_byte_echo			<= x"00";
						uart_tx_valid_echo			<= '0';
						
						-- if UART is not busy, wait for an incoming data
						if (uart_busy = '0') then
							uart_control			<= ct_wait;
						end if;

					-- wait for an incoming byte and echo it
					when ct_wait =>
						uart_control				<= ct_wait;
						uart_tx_byte_echo			<= x"00";
						uart_tx_valid_echo			<= '0';

						-- if UART is not busy and new data is incoming
						if (uart_busy = '0' and uart_rx_valid = '1') then
							uart_tx_byte_echo		<= uart_rx_byte;
							uart_tx_valid_echo		<= '1';
							uart_control			<= ct_complete;
						end if;

					-- complete sending operation
					when ct_complete =>
						uart_control				<= ct_complete;
						uart_tx_byte_echo			<= x"00";
						uart_tx_valid_echo			<= '0';

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

	-- download software rom file
	download_software : process(clock)
		file		var_file_handle		: CHAR_FILE;
		variable	var_char			: character;
		variable	var_offset			: integer;
	begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				-- reset state
				download_done						<= '0';
				download_wait						<= 0;
				download_control					<= dl_wait;

				uart_tx_valid_soft_dl				<= '0';
				uart_tx_byte_soft_dl				<= (others => '0');
			else
				case (download_control) is

					-- reset state
					when dl_wait =>
						if (download_wait = 63) then
							download_control		<= dl_run;
							var_offset				:= 0;
							file_open(var_file_handle, filename);
							Log("Software download start");
						else
							download_wait			<= download_wait + 1;
						end if;

					-- download software rom file throught UART
					when dl_run =>
						if (endfile(var_file_handle)) then
							download_control		<= dl_done;
						else
							read(var_file_handle, var_char);

							var_offset				:= var_offset + 1;
							download_control		<= dl_pause;
							uart_tx_byte_soft_dl	<= std_logic_vector(to_unsigned(character'pos(var_char), 8));
							uart_tx_valid_soft_dl	<= '1';
							
							if (var_offset /= 0) and (var_offset mod 1024 = 0) then
								Log("Downloaded [" & integer'image(var_offset) & "] byte");
							end if;
							
						end if;

					-- Wait for uart busy
					when dl_pause =>
						uart_tx_valid_soft_dl		<= '0';

						if (uart_busy = '1') then
							download_control		<= dl_restart;							
						end if;

					-- wait for restart
					when dl_restart =>

						if (uart_busy = '0') then
							if (endfile(var_file_handle)) then
								download_control	<= dl_done;
								download_done		<= '1';
								Log("Software download completed");
							else
								download_control	<= dl_run;							
							end if;
						end if;

					-- Download done
					when dl_done =>
						file_close(var_file_handle);

					-- Alignment state
					when others =>
						download_control			<= dl_wait;
				end case;
				
			end if; -- reset
		end if; -- clock
	end process;	

end behavioral;

-------------------------------------------------------------------------------
-- EOF
