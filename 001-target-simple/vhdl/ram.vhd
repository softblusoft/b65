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
	generic	(
				ram_cells				:			integer				:= 10;				-- number of memory cells
				reset_value				:			std_logic_vector	:= "0000"			-- RAM reset value
			);
	port	(
				-- General
				clock					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset

				-- Write interface
				write_address			: in		std_logic_vector(15	downto 0);			-- Ram write Address
				write_enable			: in		std_logic;								-- Write enable
				write_data				: in		std_logic_vector( 7	downto 0);			-- Data IN

				-- Read interface
				read_address			: in		std_logic_vector(15	downto 0);			-- Ram read Address
				read_data				: out		std_logic_vector( 7	downto 0)			-- Data OUT
			);
end ram;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of ram is

	----------------------------------------------------------------------------
	-- Data types

	-- Memory data
	type RAM_MEMORY is array(0 to ram_cells-1) of std_logic_vector(7 downto 0);

	----------------------------------------------------------------------------
	-- Signals

	-- Memory
	signal memory : RAM_MEMORY;

begin

	----------------------------------------------------------------------------
	-- Hardwired connections

	-- Memory read
	ram_read  : process(clock) begin
		if (clock'event and clock='1') then
			-- If reset
			if (reset = '1') or (conv_integer(read_address) > ram_cells) then
				read_data				<= (others => '0');
			else
				read_data				<= memory(conv_integer(read_address));
			end if; -- reset
		end if; -- clock event
	end process;

	-- Memory write
	ram_write  : process(clock) begin
		if (clock'event and clock='1') then
			-- If reset
			if (reset = '1') then
				-- Reset RAM
				for address in 0 to ram_cells-1 loop
					memory(address)		<= reset_value;
				end loop;				
			else
				-- Memory Write
				if (write_enable = '1') and (conv_integer(write_address) < ram_cells) then
					memory(conv_integer(write_address)) <= write_data;
				end if;
			end if; -- reset
		end if; -- clock event
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
