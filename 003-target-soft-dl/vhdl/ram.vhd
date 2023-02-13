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
-- Static RAM memory

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library b65;

-------------------------------------------------------------------------------
-- Entity

entity ram is
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
end ram;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of ram is

	constant ram_cells : integer := 56320; -- number of memory cells

	----------------------------------------------------------------------------
	-- Data types

	-- Memory data
	type RAM_MEMORY is array(0 to ram_cells-1) of std_logic_vector(7 downto 0);

	----------------------------------------------------------------------------
	-- Signals

	-- Memory
	signal memory : RAM_MEMORY;

begin

	---------------------------------------------------------------------------
	-- Hardwired

	rsta_busy <= '0';

	----------------------------------------------------------------------------
	-- Processes

	-- Memory read
	ram_read  : process(clka) begin
		if (clka'event and clka='1') then
			-- If reset
			if (rsta = '1') then
				douta <= (others => '0');
			elsif (ena = '1') and (conv_integer(addra) < ram_cells) then
				douta <= memory(conv_integer(addra));
			end if; -- reset
		end if; -- clock event
	end process;

	-- Memory write
	ram_write  : process(clka) begin
		if (clka'event and clka='1') then
			-- If reset
			if (rsta = '1')then
				-- Reset RAM
				for address in 0 to ram_cells-1 loop
					memory(address) <= (others => '0');
				end loop;				
			elsif (ena = '1') and (wea(0) = '1') and (conv_integer(addra) < ram_cells) then
				-- Memory Write
				memory(conv_integer(addra)) <= dina;
			end if; -- reset
		end if; -- clock event
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
