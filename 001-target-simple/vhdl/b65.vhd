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
-- 6502 board simulation top

-------------------------------------------------------------------------------
-- Libraries

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

library r65c02_tc;
use r65c02_tc.all;

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
	-- Signals

	-- Clock
	signal clock			: std_logic;								-- System clock @ 50MHz
	signal clock_ph0		: std_logic;								-- CPU    clock @  5MHz
	signal clock_ph1		: std_logic;								-- CPU    clock @  5MHz
	signal clock_ph2		: std_logic;								-- CPU    clock @  5MHz - inverted

	-- Reset
	signal reset			: std_logic;								-- Reset
	signal reset_cpu		: std_logic;								-- Reset (CPU only)

	-- Ram
	signal ram_read_data	: std_logic_vector ( 7 downto 0) := x"00";
	signal ram_write_data	: std_logic_vector ( 7 downto 0) := x"00";
	signal ram_write_enable	: std_logic;
	signal ram_address		: std_logic_vector (15 downto 0) := x"0000";

	-- Rom
	signal rom_data			: std_logic_vector ( 7 downto 0) := x"00";
	signal rom_address		: std_logic_vector (15 downto 0) := x"0000";

	-- 6502 CPU
	signal cpu_address		: std_logic_vector (15 downto 0) := x"0000";
	signal cpu_data_in		: std_logic_vector ( 7 downto 0) := x"00";
	signal cpu_data_out		: std_logic_vector ( 7 downto 0) := x"00";	-- cpu out data only go to ram write bus
	signal cpu_write_enable	: std_logic						 := '0';
	signal cpu_ready		: std_logic						 := '0';	-- cpu INPUT  ready
	signal cpu_irq			: std_logic						 := '0';	-- cpu INPUT  interrupt              (active low)
	signal cpu_nmi			: std_logic						 := '0';	-- cpu INPUT  non maskable interrupt (active low)
	signal cpu_set_overflow	: std_logic						 := '0';	-- cpu INPUT  set overflow
	signal cpu_sync			: std_logic						 := '0';	-- cpu OUTPUT high during ph1 (OP fetch)

	----------------------------------------------------------------------------
	-- Components

	component core is
	port	(
				clk_clk_i				: in		std_logic ;
				d_i						: in		std_logic_vector( 7 downto 0);
				irq_n_i					: in		std_logic ;
				nmi_n_i					: in		std_logic ;
				rdy_i					: in		std_logic ;
				rst_rst_n_i 			: in		std_logic ;
				so_n_i					: in		std_logic ;
				a_o						: out		std_logic_vector(15 downto 0);
				d_o						: out		std_logic_vector( 7 downto 0);
				rd_o					: out		std_logic ;
				sync_o					: out		std_logic ;
				wr_n_o					: out		std_logic ;
				wr_o					: out		std_logic 
			);
	end component;
 
begin
	----------------------------------------------------------------------------
	-- Components map

	inst_clocksource : clockgenerator
	port map	(
					clock						=> clock,				-- fpga clock
					clock_ph0					=> clock_ph0,			-- cpu 6502 (6502 chip pin 37) input  clock
					clock_ph1					=> clock_ph1,			-- cpu 6502 (6502 chip pin  3) output clock
					clock_ph2					=> clock_ph2			-- cpu 6502 (6502 chip pin 39) output clock (inverted)
				);

	inst_core6502 : core
	port map	(
					 clk_clk_i					=> clock_ph0,
					 d_i						=> cpu_data_in,			-- data in                    input
					 irq_n_i					=> cpu_irq,				-- interrupt                  input (active low)
					 nmi_n_i					=> cpu_nmi,				-- non maskable interrupt     input (active low)
					 rdy_i						=> cpu_ready,			-- ready                      input
					 rst_rst_n_i				=> reset_cpu,			-- reset                      input
					 so_n_i						=> cpu_set_overflow,	-- set overflow               input (active low)

					 a_o						=> cpu_address,			-- address                    output
					 d_o						=> cpu_data_out,		-- data out                   output
					 rd_o						=> open,
					 sync_o						=> cpu_sync,			-- high during ph1 (op fetch) output
					 wr_n_o						=> open,
					 wr_o						=> cpu_write_enable		-- write enable               output
				);

	inst_ram : ram
	generic	map (
					ram_cells					=> MAP_SIZE_RAM,
					reset_value					=> x"00"
				)
	port map	(
					-- General
					clock						=> clock,
					reset						=> reset,

					-- Write interface
					write_address				=> ram_address,
					write_enable				=> ram_write_enable,
					write_data					=> ram_write_data,

					-- Read interface
					read_address				=> ram_address,
					read_data					=> ram_read_data
				);

	inst_rom : rom
	generic	map (
					rom_cells					=> MAP_SIZE_ROM,
					reset_value					=> ROM_FILL,
					filename					=> ROM_FILE
				)
	port map	(
					-- General
					clock						=> clock,
					reset						=> reset,
		
					-- Read interface   
					read_address				=> rom_address,
					read_data					=> rom_data
				);
	
	---------------------------------------------------------------------------
	-- Hardwired

	cpu_ready			<= '1';

	cpu_set_overflow	<= '1';	-- active low

	---------------------------------------------------------------------------
	-- Processes

	-- System reset
	proc_reset : process begin
		cpu_irq		<= '1';	-- active low
		cpu_nmi		<= '1';	-- active low

		reset		<= '1';
		reset_cpu	<= '0';
		wait for  500 ns;
		wait until rising_edge(clock);
		reset		<= '0';
		wait for  500 ns;
		wait until rising_edge(clock);
		reset_cpu	<= '1';

		-- Generate interrupt, ensure software enabled interrupts with asm("cli");
		wait for  2000 us;
		wait until rising_edge(clock);
		cpu_irq		<= '0';	-- generate interrupt
		wait for  2000 ns;  -- pulse shorter than 2000ns is not correcty handled by the CPU
		cpu_irq		<= '1';	-- active low
	
		wait for  1000 us;
		wait until rising_edge(clock);
		cpu_nmi		<= '0';	-- generate interrupt
		wait for   2000 ns;
		cpu_nmi		<= '1';	-- active low

		wait;
	end process;

	-- Assign address/data
	proc_assign : process(clock) begin
		if (clock'event and clock='1') then
			-- If reset
			if (reset = '1') then
				cpu_data_in				<= x"00";
				ram_address				<= x"0000";
				rom_address				<= x"0000";
			else
				if (conv_integer(cpu_address) >= MAP_START_ROM) then
					-- ROM access
					rom_address			<= cpu_address - MAP_START_ROM;
					cpu_data_in			<= rom_data;
				elsif (conv_integer(cpu_address) >= MAP_START_REG) then
					-- Registers access
				else
					-- RAM access
					cpu_data_in			<= ram_read_data;
					ram_address			<= cpu_address;
					ram_write_data		<= cpu_data_out;
					ram_write_enable	<= cpu_write_enable;
				end if;

			end if; -- reset
		end if; -- clock event
	end process;

	-- test.c memory access check: (*(unsigned char*) 0x0240) = 0xBB;
	proc_check : process(clock_ph0)
		variable	var_debug_line		: line;
	begin
		if (clock_ph0'event and clock_ph0='1') then
			-- If not reset (active low for cpu)
			if (reset_cpu = '1') then

				if (cpu_address = x"0240") and (cpu_data_out = x"BB") and (cpu_write_enable = '1')  then
					Log("INFO : test.c write@[0x240]=0xBB; -- MEMORY WRITE TEST SUCCESS");
				end if;

				if (cpu_address = x"0250") and (cpu_data_out = x"35") and (cpu_write_enable = '1')  then
					Log("INFO : test.c write@[0x250]=0x35; -- IRQ TEST SUCCESS");
				end if;

				if (cpu_address = x"0260") and (cpu_data_out = x"9F") and (cpu_write_enable = '1')  then
					Log("INFO : test.c write@[0x260]=0x9F; -- NMI TEST SUCCESS");
				end if;

			end if; -- reset_cpu
		end if; -- clock_ph0 event
	end process;

end behavioral;

-------------------------------------------------------------------------------
-- EOF
