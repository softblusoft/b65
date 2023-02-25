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

----------------------------------------------------------------------------------
-- Software download block

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library b65;
use b65.PACK.all;

-------------------------------------------------------------------------------
-- Entity

entity soft_dl is
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
end soft_dl;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of soft_dl is

	----------------------------------------------------------------------------
	-- Data types

	-- FSM
	TYPE SOFT_DL_FSM is (dl_start, dl_run, dl_done, dl_restart);							-- Download FSM

	----------------------------------------------------------------------------
	-- Signals
	
	signal download_state	: SOFT_DL_FSM;
	signal download_reset	: std_logic							:= '0';						-- Reset CPU (active low)
	signal download_wait	: integer range 0 to 15;
	signal data_address		: std_logic_vector(15	downto 0)	:= (others => '0');			-- data Address

begin
	---------------------------------------------------------------------------
	-- Hardwired

	write_address	<= data_address(12 downto 0);

	-- Reset CPU is active low
	reset_cpu		<= download_reset;
	reset_devices	<= not download_reset;

	---------------------------------------------------------------------------
	-- Processes

	-- Reset handling
	proc_soft_dl : process(clock) begin
		if (clock'event and clock='1') then
			-- If reset
			if (reset = '1') then
				download_state											<= dl_start;
				led														<= x"0001";
				data_address											<= (others => '1');
				write_enable(0)											<= '0';
				write_data												<= (others => '0');
				download_reset											<= '0';
				download_wait											<= 0;
			else
				case download_state is
					when dl_start =>
						download_state									<= dl_run;
						led												<= x"0001";
						data_address									<= (others => '1');
						write_enable(0)									<= '0';
						write_data										<= (others => '0');
						download_reset									<= '0';
				
					when dl_run =>
						write_enable(0)									<= '0';
						download_reset									<= '0';

						if  (data_address = x"0200") then	led(1)		<= '1'; end if;
						if  (data_address = x"0400") then	led(2)		<= '1'; end if;
						if  (data_address = x"0600") then	led(3)		<= '1'; end if;
						if  (data_address = x"0800") then	led(4)		<= '1'; end if;
						if  (data_address = x"0A00") then	led(5)		<= '1'; end if;
						if  (data_address = x"0C00") then	led(6)		<= '1'; end if;
						if  (data_address = x"0E00") then	led(7)		<= '1'; end if;
						if  (data_address = x"1000") then	led(8)		<= '1'; end if;
						if  (data_address = x"1200") then	led(9)		<= '1'; end if;
						if  (data_address = x"1400") then	led(10)		<= '1'; end if;
						if  (data_address = x"1600") then	led(11)		<= '1'; end if;
						if  (data_address = x"1800") then	led(12)		<= '1'; end if;
						if  (data_address = x"1A00") then	led(13)		<= '1'; end if;
						if  (data_address = x"1C00") then	led(14)		<= '1'; end if;
						if  (data_address = x"1FFE") then	led(15)		<= '1'; end if;

						if (uart_rx_valid = '1') then
							write_enable(0)								<= '1';
							write_data									<= uart_rx_data;
							data_address								<= data_address + 1;
							led(0)										<= '1';
						end if;

						-- software download completed
						if  (data_address = x"1FFF") then
							download_state								<= dl_done;
							led											<= x"0000";
						end if;

					when dl_done =>
						download_reset									<= '1';
						if (upgrade = '1') then
							download_state								<= dl_restart;
							download_reset								<= '0';
							download_wait								<= 0;
							
							Log("Restarting software download");
						end if;

					when dl_restart =>
						if (download_wait < 15) then
							download_wait								<= download_wait + 1;
						else
							download_state								<= dl_start;
						end if;
				end case;
			end if; -- reset
		end if; -- clock event
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
