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
-- b65 memory map (see software b65.cfg configuration file)
--
--		0x0000       0         RAM          (56320 bytes = 55 KB)
--		                       |
--		0xDBFF   56319         v        <-- (Stack is 0x400 bytes, growing from 0xDBFF to 0xD800)
--		0xDC00   56320         \
--		                        | Registers (1024 bytes =  1 KB)
--		0xDFFF   57343         /
--		0xE000   57344         ^
--		                       |
--		                       |
--		0xFFFF   65535        ROM start     (8192 bytes =  8 KB)

-------------------------------------------------------------------------------
-- The 6502 chip mirrors out the input clock, in this design this is
-- done in clockgenerator
---
--  - ph0 and ph1,ph2 could have a minimum delay (neglected)
--  - ph1 and ph2 are inverted without delay
--
--		                    +------+
--		 5MHz input ph0 -->	|      | ---> ph1
--		                    | 6502 |
--		                    |      | ---> ph2
--		                    +------+
--		         ___     ___     ___
--		 ph0 ___|   |___|   |___|   |___
--		         ___     ___     ___
--		 ph1 ___|   |___|   |___|   |___
--		     ___     ___     ___     ___
--		 ph2    |___|   |___|   |___|

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library b65;

-------------------------------------------------------------------------------
-- Package

package PACK is

	----------------------------------------------------------------------------
	-- Constants

	constant ROM_FILE		: string			:= "b65.rom";								-- rom filename
	constant ROM_FILL		: std_logic_vector	:= x"FF";									-- rom fill value

	constant MAP_START_RAM	: integer			:= conv_integer(x"0000");					-- start address     0 : RAM
	constant MAP_START_REG	: integer			:= conv_integer(x"DC00");					-- start address 56320 : devices registers
	constant MAP_START_ROM	: integer			:= conv_integer(x"E000");					-- start address 57344 : ROM (growing from 0xFFFF down to 0xE000)

	constant MAP_SIZE_RAM	: integer			:= conv_integer(x"DC00");					-- size  in bytes      : RAM
	constant MAP_SIZE_REG	: integer			:= conv_integer(x"0400");					-- size  in bytes      : devices registers
	constant MAP_SIZE_ROM	: integer			:= conv_integer(x"2000");					-- size  in bytes      : ROM

	----------------------------------------------------------------------------
	-- Procedures
	
	procedure Log(message : in string);

	----------------------------------------------------------------------------
	-- Components

	component clockgenerator is
	port	(
				clock					: out		std_logic;								-- 50MHz FPGA
				clock_ph0				: out		std_logic;								--  5MHz 6502 CPU ph0 input
				clock_ph1				: out		std_logic;								--  5MHz 6502 CPU ph1 output (the same as ph0)
				clock_ph2				: out		std_logic								--  5MHz 6502 CPU ph2 output (ph0 inverted)
			);
	end component;

	component ram is
	generic	(
				ram_cells				:			integer				:= 10;				-- number of ram cells (ram size is = ram_cells * data_width bit)
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
	end component;

	component rom is
	generic	(
				rom_cells				:			integer				:= 1024;			-- number of memory cells
				reset_value				:			std_logic_vector	:= x"FF";			-- ROM reset value
				filename				:			string				:= ""				-- ROM initialization binary file
			);
	port	(
				-- General
				clock					: in		std_logic;								-- Clock
				reset					: in		std_logic;								-- reset

				-- Read interface
				read_address			: in		std_logic_vector(15	downto 0);			-- Ram read Address
				read_data				: out		std_logic_vector( 7	downto 0)			-- Data OUT
			);
	end component;

end PACK;

package body PACK is

	----------------------------------------------------------------------------
	-- Procedures implementation
	
	procedure Log(message : in string) is
		variable var_log	: line;	
	begin
		-- Insert timestamp
		write(var_log, now, right, 12);
		write(var_log, string'(": "));
		
		-- Insert user log message
		write(var_log, message);

		-- Write to output
		writeline(output, var_log);
	end Log;

end PACK;

-------------------------------------------------------------------------------
-- EOF
