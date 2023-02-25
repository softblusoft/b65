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
-- Inputs debounce

----------------------------------------------------------------------------------
-- Libraries

-- standard libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library b65;
use b65.PACK.all;

----------------------------------------------------------------------------------
-- Entity

entity debounce is
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
end debounce;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of debounce is

	constant DEBOUNCE_DELAY : integer := 65535;										-- 1.3ms @ 50MHz

	----------------------------------------------------------------------------
	-- Data types

	-- FSM - Debounce FSM
	type FSM_DEBOUNCE		is (d_idle, d_down, d_up);

	----------------------------------------------------------------------------
	-- Signals

	signal deb_state			: FSM_DEBOUNCE;										-- debounce state
	signal deb_delay			: std_logic_vector(15 downto 0);					-- debounce delay
	
	signal signal_in_resampled	: std_logic_vector(2  downto 0);					-- Input signal resampled on clock

begin

	--------------------------------------------------
	-- Processes

	resample_process : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				signal_in_resampled			<= "000";
			else
				signal_in_resampled(2)		<= signal_in;
				signal_in_resampled(1)		<= signal_in_resampled(2);
				signal_in_resampled(0)		<= signal_in_resampled(1);
			end if;
		end if;
	end process;

	debounce_process : process(clock) begin
		if (clock'event and clock='1') then
			-- If (system is in reset state)
			if (reset = '1') then
				button_down					<= '0';
				button_up					<= '0';
				deb_state					<= d_idle;								-- After reset go to d_idle state
				deb_delay					<= (others => '0');						-- Reset debounce counter
			else

				-- Clean events
				button_down					<= '0';
				button_up					<= '0';

				-- Debounce FSM
				case deb_state is

					-- Wait for button down event
					when d_idle  =>
						if (signal_in_resampled(0) = active_high) then
							button_down		<= '1';
							deb_state		<= d_down;
							deb_delay		<= (others => '0');
						end if;
					
					-- Debounce down
					when d_down =>
						if (deb_delay = DEBOUNCE_DELAY) then
							if (signal_in_resampled(0) = not active_high) then
								button_up	<= '1';
								deb_state	<= d_up;
								deb_delay	<= (others => '0');
							end if;
						else
							deb_delay		<= deb_delay + 1;
						end if;

					-- Debounce up
					when d_up =>
						if (deb_delay = DEBOUNCE_DELAY) then
							if (signal_in_resampled(0) = not active_high) then
								deb_state	<= d_idle;
							end if;
						else
							deb_delay		<= deb_delay + 1;
						end if;

				end case;
			end if;
		end if;
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
