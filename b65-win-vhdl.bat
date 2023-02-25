@echo off
rem Copyright 2023 Luca Bertossi
rem
rem This file is part of B65.
rem 
rem     B65 is free software: you can redistribute it and/or modify
rem     it under the terms of the GNU General Public License as published by
rem     the Free Software Foundation, either version 3 of the License, or
rem     (at your option) any later version.
rem 
rem     B65 is distributed in the hope that it will be useful,
rem     but WITHOUT ANY WARRANTY; without even the implied warranty of
rem     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
rem     GNU General Public License for more details.
rem 
rem     You should have received a copy of the GNU General Public License
rem     along with B65.  If not, see <http://www.gnu.org/licenses/>.

rem Settings
set FOLDER_OUTPUT=out
set FOLDER_6502=cpu65c02_true_cycle
set TARGET=%1
set SIMRUNTIME=%2
set WAVE=%3

if "%TARGET%" EQU "" (
	echo ERROR : target not specified, please specify a valid target folder
	pause
	exit 1
)

if "%SIMRUNTIME%" EQU "" (
	set SIMRUNTIME=20ms
)

rem Create the output folder
if not exist "%FOLDER_OUTPUT%\%TARGET%\vhdl" mkdir %FOLDER_OUTPUT%\%TARGET%\vhdl
cd %FOLDER_OUTPUT%\%TARGET%\vhdl

rem VHDL build
if not exist "r65c02_tc-obj08.cf" (
	echo INFO  : building 6502 cpu VHDL
	
	if not exist "..\..\..\%FOLDER_6502%" (
		echo ERROR : cannot find [%FOLDER_6502%] folder
		pause
		exit 1
	)
	
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ..\..\..\%FOLDER_6502%\trunk\released\rtl\vhdl\fsm_execution_unit.vhd
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ..\..\..\%FOLDER_6502%\trunk\released\rtl\vhdl\fsm_intnmi.vhd
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ..\..\..\%FOLDER_6502%\trunk\released\rtl\vhdl\reg_pc.vhd
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ..\..\..\%FOLDER_6502%\trunk\released\rtl\vhdl\reg_sp.vhd
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ..\..\..\%FOLDER_6502%\trunk\released\rtl\vhdl\regbank_axy.vhd
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ..\..\..\%FOLDER_6502%\trunk\released\rtl\vhdl\core.vhd
)

echo INFO  : building b65 board

rem Pack must be compiled first
echo         ..\..\..\%TARGET%\vhdl\pack.vhd
ghdl -a --ieee=synopsys -fexplicit --std=08 --work=b65 ..\..\..\%TARGET%\vhdl\pack.vhd

for %%* in (..\..\..\%TARGET%\vhdl\*.vhd) do (
	if "%%~n*" NEQ "pack" (
		if "%%~n*" NEQ "b65" (
			if "%%~n*" NEQ "top" (
				echo         %%~*
				ghdl -a --ieee=synopsys -fexplicit --std=08 --work=b65 %%~*
			)
		)
	)
)

echo INFO  : Linking b65 board

rem Analyze top
if exist ..\..\..\%TARGET%\vhdl\top.vhd (
	ghdl -a --ieee=synopsys -fexplicit --std=08 ..\..\..\%TARGET%\vhdl\top.vhd
)

ghdl -a --ieee=synopsys -fexplicit --std=08 ..\..\..\%TARGET%\vhdl\b65.vhd

rem Elaborate (generate the executable)
ghdl -e --ieee=synopsys -fexplicit --std=08 board

rem vhdl simulation
echo INFO  : Running b65 board for %SIMRUNTIME%
echo.

rem copy software rom file to board.exe folder
if not exist "..\soft\b65.rom" (
	echo ERROR : cannot find rom file [%FOLDER_OUTPUT%\%TARGET%\soft\b65.rom], something went wrong building software
	pause
	exit 1
)

copy ..\soft\b65.rom . >NUL

if "%WAVE%" EQU "wave" (

	rem write the (optional) GHDL signals-to-save file
	rem use --write-wave-opt=<filename> to generate signals hierarchy (tip : run for 1ns to avoid useless waits)
	rem use --read-wave-opt=<filename>  to save only indicated signals to simulation file

	echo $ version 1.1							 > signals.ghd
	echo /board/*								>> signals.ghd
rem	echo /board/inst_uart/*						>> signals.ghd
	echo /board/int_top/*						>> signals.ghd
rem	echo /board/int_top/inst_clock_manager/*	>> signals.ghd
rem	echo /board/int_top/inst_core6502/*			>> signals.ghd
rem	echo /board/int_top/inst_ram/*				>> signals.ghd
rem	echo /board/int_top/inst_ram_code/*			>> signals.ghd
rem	echo /board/int_top/inst_uart/*				>> signals.ghd
rem	echo /board/int_top/inst_ext/*				>> signals.ghd
rem	echo /board/int_top/inst_soft_dl/*			>> signals.ghd

	rem --ieee-asserts=disable-at-0 disables some warnings from r65c02_tc at 0ms
rem	board.exe --ieee-asserts=disable-at-0 --wave=cpu.ghw --stop-time=%SIMRUNTIME%
rem	board.exe --ieee-asserts=disable-at-0 --write-wave-opt=signals.ghd --wave=cpu.ghw --stop-time=1ns
	board.exe --ieee-asserts=disable-at-0 --read-wave-opt=signals.ghd  --wave=cpu.ghw --stop-time=%SIMRUNTIME%

	rem open waveform viewer
	gtkwave -f cpu.ghw --save ..\..\..\%TARGET%\wave.gtkw
) else (
	rem --ieee-asserts=disable-at-0 disables some warnings from r65c02_tc at 0ms
	board.exe --ieee-asserts=disable-at-0 --stop-time=%SIMRUNTIME%
)

cd ..\..\..
echo INFO  : All done
pause