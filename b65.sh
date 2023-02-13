# Copyright 2023 Luca Bertossi
#
# This file is part of B65.
# 
#     B65 is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
# 
#     B65 is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
# 
#     You should have received a copy of the GNU General Public License
#     along with B65.  If not, see <http://www.gnu.org/licenses/>.

# Settings
SIMRUNTIME=20ms
FOLDER_OUTPUT=out
FOLDER_CC65=cc65-2.19
FOLDER_ROM2COE=rom2coe
FOLDER_6502=cpu65c02_true_cycle
FILENAME_CC65=download/${FOLDER_CC65}.tar.gz
FILENAME_6502=download/${FOLDER_6502}_latest.tar.gz
FOUND_GHDL=no
FOUND_GTKWAVE=no

b65Help()
{
	echo "This script builds a target b65 board"
	echo "usage: b65-linux.sh <target folder> [wave]"
	echo
	echo "If wave is specified, waveform is saved and gtkwave is opened"
}

b65Prerequisites()
{
	gcc --version &> /dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR : gcc not found, please install gcc compiler"
		exit 1
	fi

	make --version &> /dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR : make not found, please install make"
		exit 1
	fi

	tar --version &> /dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR : tar not found, please install tar"
		exit 1
	fi

	# if not MSYS environment
	ghdl --version &> /dev/null
	if [ $? -ne 0 ]; then
		FOUND_GHDL='no'
	else
		FOUND_GHDL='yes'
	fi

	gtkwave --version &> /dev/null
	if [ $? -ne 0 ]; then
		FOUND_GTKWAVE='no'
	else
		FOUND_GTKWAVE='yes'
	fi
}

b65Extract()
{
	if [ ! -d "$FOLDER_CC65" ]; then
		if [ ! -e "$FILENAME_CC65" ]; then
			echo "ERROR : cc65 source file [$FILENAME_CC65] not found"
			exit 1
		else
			echo "INFO  : extracting cc65 compiler [$FILENAME_CC65]"
			tar -xf "$FILENAME_CC65"
		fi
	fi

	if [ ! -d "$FOLDER_6502" ]; then
		if [ ! -e "$FILENAME_6502" ]; then
			echo "ERROR : cpu6502 source file [$FILENAME_6502] not found"
			exit 1
		else
			echo "INFO  : extracting cpu 6502 sources [$FILENAME_6502]"
			tar -xf "$FILENAME_6502"
		fi
	fi
}

b65Compilecc65()
{
	if [ ! -d "$FOLDER_CC65/bin" ]; then
		# Build only needed parts of cc65
		echo "INFO  : building cc65 compiler"
		
		cd "$FOLDER_CC65"
		make -C src
		make -C libsrc TARGETS=supervision
		cd ..
	fi
}

b65CompileRomToCoe()
{
	if [ ! -d "$FOLDER_OUTPUT/rom2coe" ]; then

		mkdir "$FOLDER_OUTPUT/rom2coe"
		cd "$FOLDER_ROM2COE"

		echo "INFO  : building rom2coe file convert utility"
		pwd

		cp -R --preserve=timestamps * "../$FOLDER_OUTPUT/rom2coe"
		cd "../$FOLDER_OUTPUT/rom2coe"
		make
		cd ../..
		
		echo all done
		pwd
	fi
}

b65Compile6502CPU()
{
	local Target=$1

	# Compile CPU sources only once (it's supposed no changes in the CPU sources)
	if [ ! -e "$FOLDER_OUTPUT/$Target/vhdl/r65c02_tc-obj08.cf" ]; then

		cd "$FOLDER_OUTPUT/$Target/vhdl"

		if [ ! -e "../../../$FOLDER_6502" ]; then
			echo "ERROR : cannot find [$FOLDER_6502] folder"
			exit 1
		fi

		echo "INFO  : building 6502 cpu VHDL"
		ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ../../../$FOLDER_6502/trunk/released/rtl/vhdl/fsm_execution_unit.vhd
		ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ../../../$FOLDER_6502/trunk/released/rtl/vhdl/fsm_intnmi.vhd
		ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ../../../$FOLDER_6502/trunk/released/rtl/vhdl/reg_pc.vhd
		ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ../../../$FOLDER_6502/trunk/released/rtl/vhdl/reg_sp.vhd
		ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ../../../$FOLDER_6502/trunk/released/rtl/vhdl/regbank_axy.vhd
		ghdl -a --ieee=synopsys -fexplicit --std=08 --work=r65c02_tc ../../../$FOLDER_6502/trunk/released/rtl/vhdl/core.vhd
		
		cd ../../..
	fi
}

b65CompileBoard()
{
	local Target=$1
	cd "$FOLDER_OUTPUT/$Target/vhdl"

	echo "INFO  : building b65 board"

	echo "       ../../../$Target/vhdl/pack.vhd"
	ghdl -a --ieee=synopsys -fexplicit --std=08 --work=b65 ../../../$Target/vhdl/pack.vhd

	for Source in ../../../$Target/vhdl/*.vhd; do
		if  [ $(basename $Source) != 'b65.vhd' ] && [ $(basename $Source) != 'top.vhd' ] && [ $(basename $Source) != 'pack.vhd' ]; then
			echo "       $Source"
			ghdl -a --ieee=synopsys -fexplicit --std=08 --work=b65 $Source
		fi
	done
	
	cd ../../..
}

b65LinkBoard()
{
	local Target=$1
	cd "$FOLDER_OUTPUT/$Target/vhdl"

	echo "INFO  : Linking b65 board"

	# Analyze top and board
	if [ -e ../../../$Target/vhdl/top.vhd ]; then
		ghdl -a --ieee=synopsys -fexplicit --std=08 ../../../$Target/vhdl/top.vhd
	fi
	ghdl -a --ieee=synopsys -fexplicit --std=08 ../../../$Target/vhdl/b65.vhd

	# Elaborate (generate the executable)
	ghdl -e --ieee=synopsys -fexplicit --std=08 board

	cd ../../..
}

b65BuildSoftware()
{
	local Target=$1
	local LinkFiles=""

	if [ ! -e "$FOLDER_CC65/lib/supervision.lib" ]; then
		echo "ERROR : cannot find compiler library [$FOLDER_CC65/lib/supervision.lib], something went wrong in cc65 build process"
		exit 1	
	fi

	cd "$FOLDER_OUTPUT/$Target/soft"

	echo "INFO  : compiling software"

	# Customize library
	# Instructions from https://cc65.github.io/doc/customizing.html
	cp ../../../$FOLDER_CC65/lib/supervision.lib b65.lib
	../../../$FOLDER_CC65/bin/ca65 ../../../$Target/soft/crt0.s -o crt0.o
	../../../$FOLDER_CC65/bin/ar65 a b65.lib crt0.o

	# Compile sources (asm)
	for Source in ../../../$Target/soft/*.s; do
		echo "       $Source"
		Filename=$(basename $Source .s)
		../../../$FOLDER_CC65/bin/ca65 --cpu 65sc02 $Source -o $Filename.o
		LinkFiles="$LinkFiles $Filename.o"
	done

	# Compile sources (c)
	for Source in ../../../$Target/soft/*.c; do
		echo "       $Source"
		Filename=$(basename $Source .c)
		../../../$FOLDER_CC65/bin/cc65 -t none -O --cpu 65sc02 $Source -o $Filename.s
		../../../$FOLDER_CC65/bin/ca65 --cpu 65sc02 $Filename.s
		LinkFiles="$LinkFiles $Filename.o"
	done

	# Link and generate rom file
	echo "INFO  : generating .rom file"
	../../../$FOLDER_CC65/bin/ld65 -C ../../../$Target/soft/b65.cfg -m main.map $LinkFiles b65.lib -o b65.rom

	# convet rom to coe
	echo "INFO  : generating .coe file"
	../../rom2coe/rom2coe b65.rom

	cd ../../..
}

b65Run()
{
	local Target=$1
	local Wave=$2
	cd "$FOLDER_OUTPUT/$Target/vhdl"

	echo "INFO  : Running b65 board"

	if [ ! -e "../soft/b65.rom" ]; then
		echo "ERROR : cannot find rom file [$FOLDER_OUTPUT/$Target/soft/b65.rom], something went wrong building software"
		exit 1	
	fi

	# copy software rom file to board.exe folder
	cp ../soft/b65.rom .

	# Note: --ieee-asserts=disable-at-0 disables some warnings from r65c02_tc at 0ms
	if [ "$Wave" == "wave" ]; then
		./board --ieee-asserts=disable-at-0 --wave=cpu.ghw --stop-time=$SIMRUNTIME
	else
		./board --ieee-asserts=disable-at-0 --stop-time=$SIMRUNTIME
	fi

	cd ../../..
}

b65Wave()
{
	# open waveform viewer
	if [ -e "cpu.ghw" ]; then
		if [ ! -e "../../../$Target/wave.gtkw" ]; then
			gtkwave -f cpu.ghw --save ../../../$Target/wave.gtkw
		else
			gtkwave -f cpu.ghw
		fi
	fi
}

b65main()
{
	local Target=$1
	local Wave=$2

	if [ "$Target" == '--help' ] || [ "$Target" == '-?' ]; then 
		b65Help
		exit 0
	fi

	if [ -z "$Target" ]; then
		echo "ERROR : target not specified, please specify a valid target folder"
		exit 1
	fi
	
	if [ ! -d "$Target" ]; then
		echo "ERROR : unable to build [$Target], please specify a valid target folder"
		exit 1
	fi

	# Check for prerequisites and prepare environment (first run only)
	b65Prerequisites
	b65Extract
	b65Compilecc65

	if [ ! -d "$FOLDER_OUTPUT" ];              then mkdir "$FOLDER_OUTPUT";              fi
	if [ ! -d "$FOLDER_OUTPUT/$Target" ];      then mkdir "$FOLDER_OUTPUT/$Target";      fi
	if [ ! -d "$FOLDER_OUTPUT/$Target/vhdl" ]; then mkdir "$FOLDER_OUTPUT/$Target/vhdl"; fi
	if [ ! -d "$FOLDER_OUTPUT/$Target/soft" ]; then mkdir "$FOLDER_OUTPUT/$Target/soft"; fi

	# Build rom to coe utility
	b65CompileRomToCoe

	# Software build 
	b65BuildSoftware $Target

	# if GHDL was found
	if [ "$FOUND_GHDL" == "yes" ]; then

		# VHDL build
		b65Compile6502CPU $Target
		b65CompileBoard   $Target
		b65LinkBoard      $Target

		# Run VHDL (simulation executing software)
		b65Run $Target $Wave
	fi
	
	# Open GTKwave
	if [ "$FOUND_GTKWAVE" == "yes" ] && [ "$Wave" == "wave" ]; then
		b65Wave
	fi

	echo "INFO  : All done"
}

b65main $@