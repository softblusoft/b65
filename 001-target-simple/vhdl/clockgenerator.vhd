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
-- Simulated clock generator

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;

library b65;

-------------------------------------------------------------------------------
-- Entity

entity clockgenerator is
	port	(
				clock					: out		std_logic;								-- 50MHz FPGA
				clock_ph0				: out		std_logic;								--  5MHz 6502 CPU ph0 input
				clock_ph1				: out		std_logic;								--  5MHz 6502 CPU ph1 output (the same as ph0)
				clock_ph2				: out		std_logic								--  5MHz 6502 CPU ph2 output (ph0 inverted)
			);
end clockgenerator;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of clockgenerator is

begin

	----------------------------------------------------------------------------
	-- Processes

	-- FPGA clock generator
	fpga_clock : process begin
		clock			<= '0';
		wait for (10 ns);
		loop
			clock		<= '0';
			wait for (10 ns);
			clock		<= '1';
			wait for (10 ns);
		end loop;
	end process;

	-- 6502 CPU clock generator
	cpu_clock : process begin
		clock_ph0		<= '0';
		clock_ph1		<= '0';
		clock_ph2		<= '1';
		loop
			clock_ph0	<= '0';
			clock_ph1	<= '0';
			clock_ph2	<= '1';
			wait for (100 ns);
			clock_ph0	<= '1';
			clock_ph1	<= '1';
			clock_ph2	<= '0';
			wait for (100 ns);
		end loop;
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
