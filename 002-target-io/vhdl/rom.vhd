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
-- Binary file initialized read only memory

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library b65;
use b65.PACK.Log;

-------------------------------------------------------------------------------
-- Entity

entity rom is
	port	(
				-- General
				clka					: in		std_logic;								-- Clock
				ena						: in		std_logic;								-- enable
				rsta					: in		std_logic;								-- Reset

				-- Read interface
				addra					: in		std_logic_vector(12	downto 0);			-- Ram read Address
				wea						: in		std_logic_vector(0	downto 0);			-- 
				douta					: out		std_logic_vector( 7	downto 0);			-- Data OUT
				dina					: in		std_logic_vector( 7	downto 0)			--
			);
end rom;

-------------------------------------------------------------------------------
-- Architecture

architecture behavioral of rom is

	----------------------------------------------------------------------------
	-- Constants

	constant filename	: string	:= "b65.rom";	-- rom filename
	constant rom_cells	: integer	:= 8192;		-- number of memory cells

	----------------------------------------------------------------------------
	-- Data types

	-- Memory data
	type ROM_MEMORY is array(0 to rom_cells-1) of std_logic_vector(7 downto 0);

	----------------------------------------------------------------------------
	-- Signals

	-- Memory
	signal memory		: ROM_MEMORY;
	signal initialized	: std_logic		:= '0';

	-- File types
	type CHAR_FILE is file of character;

begin

	----------------------------------------------------------------------------
	-- Processes

	-- Memory read
	ram_read  : process(clka) begin
		if (clka'event and clka='1') then
			-- If reset
			if (rsta = '1') then
				douta				<= (others => '0');
			elsif (ena = '1') and (conv_integer(addra) < rom_cells) then
				douta				<= memory(conv_integer(addra));
			end if; -- reset
		end if; -- clock event
	end process;

	-- Rom initialization from binary file
	rom_initialize : process(clka)
		file		var_file_handle		: CHAR_FILE;
		variable	var_char			: character;
		variable	var_address			: integer;
	begin
		if (clka'event and clka='1') then
			if (rsta = '1') and (initialized = '0') then

				-- Reset ROM
				for mem_address in 0 to rom_cells-1 loop
					memory(mem_address)	<= (others => '0');
				end loop;

				-- Initialize ROM from binary file
				file_open(var_file_handle, filename);
				var_address				:= 0;
				while (var_address < rom_cells) and (not endfile(var_file_handle)) loop
					read(var_file_handle, var_char);
					memory(var_address)	<= std_logic_vector(to_unsigned(character'pos(var_char), 8));
					var_address			:= var_address + 1;
				end loop;
				file_close(var_file_handle);

				initialized				<= '1';
				Log("INFO : rom initialized with [" & filename & "]");				

			end if; -- reset
		end if; -- clock event
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
