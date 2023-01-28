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

-- Note :	in the real worls this is a PLL generating the output clocks from the
--			input one. In simulation the input clocks are ignores and the output
--			ones are synthetic

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;

library b65;

-------------------------------------------------------------------------------
-- Entity

entity clock_manager is
	port	(
				-- General
				clk_in1					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset
				locked					: out		std_logic;								-- locked
				
				-- Generated clocks
				clk_out1				: out		std_logic;								-- 50MHz FPGA
				clk_out2				: out		std_logic								--  5MHz 6502 CPU ph0
			);
end clock_manager;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of clock_manager is

begin

	----------------------------------------------------------------------------
	-- Processes

	-- Locked generator
	gen_locked : process begin
		locked		<= '0';
		wait for (500 ns);
		locked		<= '1';
		wait;
	end process;

	-- FPGA clock generator
	fpga_clock : process begin
		clk_out1		<= '0';
		wait for (10 ns);
		loop
			clk_out1	<= '0';
			wait for (10 ns);
			clk_out1	<= '1';
			wait for (10 ns);
		end loop;
	end process;

	-- 6502 CPU clock generator
	cpu_clock : process begin
		clk_out2		<= '0';
		loop
			clk_out2	<= '0';
			wait for (100 ns);
			clk_out2	<= '1';
			wait for (100 ns);
		end loop;
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
