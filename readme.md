B65 - Board 65 retro computer
=============================
![B65 logo](/b65.svg)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/softblusoft/b65)

Fast start
-----------

Create 'download' folder and download:
 - https://github.com/cc65/cc65                        `c65-2.19.tar.gz`
 - https://opencores.org/projects/cpu65c02_true_cycle  `cpu65c02_true_cycle_latest.tar.gz`

Windows:
 - Open MSYS
    - `./b65.sh {nnn-target-name}`

 - Open cmd.exe (or double click on file)
    - `b65-win-vhdl-{nnn-target-name}.bat`

Windows FPGA implementation
 - `cd {nnn-target-name}`
 - `C:\Xilinx\Vivado\2018.3\bin\vivado.bat -m64 -mode batch -notrace -source vivado.tcl`

Linux:
 - `./b65.sh {nnn-target-name}`

Linux FPGA implementation:
 - `cd {nnn-target-name}/basys3`
 - `/tools/Xilinx/Vivado/2018.3/bin/vivado -m64 -mode batch -notrace -source vivado.tcl` :warning: **See Known issues**

Introduction
------------

This is a VHDL project to use a [6502 CPU](https://opencores.org/projects/cpu65c02_true_cycle) with a [C compiler](https://github.com/cc65/cc65) on a FPGA.
Design is divided into 'targets' with increasing features.
Some files are duplicated across targets, it's wanted to clearly separate each development step.
Build scripts are minimal and the whole project is intentionally written as simple as possible.

:heavy_check_mark: All used software is free of charge, in most cases open source

The following packages are used (not modified, not patched)

| pack   | version     | license         | description            | link
|--------|-------------|-----------------|------------------------|-----------------------------------------------
|cc65    | 2.19        | Zlib license    | The 6502 c compiler    | https://github.com/cc65/cc65 (cc65-2.19.tar.gz)
|cpu6502 | 2021 feb 19 | GPL             | VHDL 6502 source       | https://opencores.org/projects/cpu65c02_true_cycle

The following tools are used (not modified, not patched)

| pack   | version     | license         | description            | link
|--------|-------------|-----------------|------------------------|-----------------------------------------------
|GHDL    | 2.0.0       | GPL-2.0 license | VHDL compiler          | https://github.com/ghdl/ghdl
|gtkwave | 3.3.99      | GPLv2           | VHDL simulation viewer | https://gtkwave.sourceforge.net
|MSYS    |             |                 | Windows tools          | https://www.msys2.org
|Vivado  | 2018.3      | Xilinx EULA     | Xilinx FPGA build tool | https://www.xilinx.com
|RealTerm| 2.0.0.70    | BSD             | Serial Terminal        | https://sourceforge.net/projects/realterm/
|PuTTY   | 0.78        | MIT             | Serial Terminal        | https://www.putty.org/
|KiTTY   | 0.76.0.6p   | (see website)   | Serial Terminal        | https://github.com/cyd01/KiTTY
|Minicom | 2.8         | GPLv2           | Serial Terminal        | https://salsa.debian.org/minicom-team/minicom

:pushpin:
I use Vivado 2018.3, newer releases can be used, I prefer not to upgrade because recent releases
require too many hardware resources (RAM, disk) respect to my actual notebook capabilities.

Useful links
  - CPU 6502 resources          : http://www.6502.org
  - CPU 6502 datasheet          : http://archive.6502.org/datasheets/mos_6501-6505_mpu_preliminary_aug_1975.pdf
  - CPU 6502 assembly simulator : https://skilldrick.github.io/easy6502/

Common targets memory map

| component |  Size   |   description    | Address range
|-----------|---------|------------------|-----------------
| CPU       |         | 6502 CPU         |
| RAM       |  ~56k   | RAM              | `0x0000 - 0xDBFF`
| REG       |  16     | Registers bank   | `0xDC00 - 0xDFFF`
| ROM       |  8k     | Program ROM      | `0xE000 - 0xFFFF`

Common features
- CPU  clock is  1MHz or 5MHz (depending on target)
- FPGA clock is 50MHz
- Software is compiled with cc65 generating a .rom file to be saved into the ROM
- A rom to coe utility is provided: Xilinx rom needs a .coe initialization file

Download packs
--------------

cc65 and cpu6502 must be manually downloaded and placed to the 'download' folder:

 - mkdir download && cd download
 - https://github.com/cc65/cc65                        `c65-2.19.tar.gz`
 - https://opencores.org/projects/cpu65c02_true_cycle  `cpu65c02_true_cycle_latest.tar.gz`

Targets
-------

- `001-target-simple`
  - Simple board with one ram and one rom
  - There are no 'top' and 'testbench', everything is in b65.vhd
  - It's useful to verify the CPU is booting and executing a simple program written in C and compiled with cc65
  - Memory accesses and interrupts (IRQ and NMI) are tested
  - No registers are implemented
  - RAM and ROM and synchronous (50MHz clock)

- `002-target-io`
  - IO extension: 16 leds, 24 inputs, four 7-segments LCD digits, one UART (9600 8N2 : 8 data bit, no parity, 2 stop bits)
  - Leds and digits have 3 luminosity levels (OFF, 33% PWM, 66% PWM, full ON)
  - Inputs generate IRQ (both on push down and up), NMI is unused
  - IO extension is controlled with 16 registers starting from 0xDC00
  - This target is simulated and implemented in FPGA
  - In basys3 folder there is top.bit, a ready to use bitstream
  - There is no slides and buttons debounce
  - It's difficult to modify the software: new FPGA builds takes long time

 :pushpin:
 the implementation in 002-target-io requires a guard time after each byte; when transmitting
 separate chars, like from a keyboard console, 8N1 settings are fine; in a continuous data
 stream the setup must be 8N2 (2 stop bits)

- `003-target-soft-dl`
  - Changed 'rom' to 'ram_code': at power-on wait for software from UART before releasing the CPU reset
  - Baud rate is modified from 9600 to 921600 to speedup download (6826ms@9600 to download 8k bytes of rom it's too slow;
    the whole rom file must be downloaded because at the end there are reset vectors)
  - Ram and ram_code are essentially the same VHDL code (they could be reduced to a single file)
  - Software implementing a console over the UART
 
  :pushpin: Download the .rom file, not the .coe which is useful only to initialize the FPGA memory from Vivado

  :pushpin: After software download, to update the software again, the FPGA must be re-programmed
  
Software download
-----------------

From target 003 the software must be downloaded at power-on over the UART;
the FPGA keeps the CPU in reset until software download is completed.
There is no download protocol, each byte is written to the ROM section until
completion; the end is detected by the number of downladed bytes.

  Windows (assuming the serial port is COM8):
  - Open cmd.exe (or double click)
    - `cd out\003-target-soft-dl\soft`
    - `MODE COM8 BAUD=921600 PARITY=n DATA=8 STOP=1`
    - `copy /b b65.rom COM8` (this command doesn't work from powershell)

  Alternatively:
    - using RealTerm use "Dump File to Port" in "Send" tab to download the b65.rom file
    - using `plink.exe` or `klink.exe` `-serial -sercfg 921600,8,n,1,N COM8 < b65.rom` (press CTRL+C when done to return to prompt)

    plink.exe is in PuttY package; klink is in KiTTY package

  Linux (assuming the serial port is /dev/ttyUSB1):
  - Open a terminal as root
    - `cd out\003-target-soft-dl\soft`
    - `stty -F /dev/ttyUSB1 raw 921600 cs8`
    - `cat b65.rom > /dev/ttyUSB1`

Software download and console
-----------------------------

From target 003 there is a console over the UART.
Type ? and press enter to list available commands

  Windows RealTerm
    - Set "Ansi" display mode, Baud 921600, Parity "None", Data bits "8", Stop bits "1", Hardware flow control "None"
    - Recognized the following control keys : the four arrows, esc and backspace

  Windows PuttY or KiTTY
    - `putty.exe` or `kitty.exe` `-serial -sercfg 921600,8,n,1,N COM8`
    - Putty,Kitty recognizes the following control keys : the four arrows, esc, ins, canc, home, end and backspace
	- KiTTY moreover recognizes the cursor shapes sequences (insert and overwrite modes)

  Linux Minicom
    - sudo minicom -D /dev/ttyUSB1 -b 921600 -8 
	- Press CTRL+A Z, press O then select "Serial port setup", press F to disable "Hadware flow control", press enter and select "Exit"
	- Press CTRL+A Z, press S send a file, use "ascii" mode and then select the "b65.rom" file, press enter to send
	- Press CTRL+A Z, press Q to quit

rom2coe
-------

A `.rom` to `.coe` file convert utility is provided to convert .rom file generated by the cc65 compiler
to .coe file needed to initialize the Xilinx ROM (only in case of Xilinx FPGA implementation)

FPGA implementation
------------

Some targets are implemented in FPGA using a
[Digilent Basys-3 board](https://digilent.com/shop/basys-3-artix-7-fpga-trainer-board-recommended-for-introductory-users) (Xilinx Artix(R)-7 XC7A35T).

A `basys3/vivado.tcl` script is proided to create the Vivado project

FPGA implementation was tested with Vivado 2018.3

:warning:
Before running the Tcl script ensure software is built and
initialization file `out/{target}/soft/b65.coe` is generated.
To compile a target read "how to use" section later in this file

To run the Tcl script open a command prompt (cmd.exe) and move to the `{target}/basys3` folder then run:
	`{vivado folder}\{xxxx.y}\bin\vivado.bat -m64 -mode batch -notrace -source vivado.tcl`
where:
 - `{vivado folder}` is the installation folder, e.g. `C:\Xilinx\Vivado`
 - `{xxxx.y}`        is the vivado version,      e.g. `2018.3`

When Vivado is opened the project is ready to be 'compiled' (synthesis, implementation, bitstream generation)
The project is saved to `out/{target}/vivado` folder

Next times double click on .xpr file in `out/{target}/vivado` folder, don't run the Tcl script again

:warning:
the .coe file is **copied** from soft folder to the rom IP folder by the tcl script.
In case software is modified the .coe file must be manually updated.

Tip : the file to download to the FPGA (the bitstream), is placed in `out/{target}/vivado/b65.runs/impl_1/top.bit`.
      To download this file use Vivado (or Vivado Lab) Hardware manager

Build script
------------

A build script is provided (b65.sh)

For Windows only, batch files to compile and run VHDL are provided; they are useful in case
ghdl (gcc backend) and gtkwave don't run inside MSYS. In case ghdl and/or gtkwave is present
in MSYS, b65.sh script automatically detects the executables.

**Important note** : in Windows, always build software first, then run the VHDL build batch file

Every target has at least two subfolders:
  - 'soft' for asm/c sources : b65.cfg crt0.s isr.s vectors.s *.c
  - 'vhdl' for VHDL sources  : pack.vhd *.vhd b65.vhd

Optionally there are other folders for implementation files (e.g. basys3)

Software sources are : `b65.cfg` `crt0.s` `isr.s` `vectors.s`
All .c files are compiled and linked to b65.rom file

VHDL sources are : `pack.vhd` `b65.vhd`
 - `pack.vhd` is compiled first
 - remaining `.vhd` files are compiled
 - if there is top.vhd it's compiled last-but-one (not part of b65 library)
 - `b65.vhd` is compiled last (not part of b65 library)
 - ghdl output is `board` (.exe in Windows) executable file

To customize the behaviour:
- `SIMRUNTIME=5ms` is the simulation runtime
- run `b65.sh {target} **wave**` to save simulation waveforms and open gtkwave

Clean
-----

To clean built targets, including rom2coe utility, remove the out folder

To clean the cc65 compiler remove the cc65-2.19 folder

To clean the CPU 6502 VHDL sources remove the cpu65c02_true_cycle folder

How to use (Ubuntu 22.10)
-------------------------

- Prerequisites:
  -   Install the following packages:
      -   `sudo apt-get install build-essential`
      -   `sudo apt-get install debian-keyring g++-multilib g++-12-multilib gcc-multilib autoconf automake libtool flex bison gcc-12-multilib`
      -   `sudo apt-get install gcc-12-locales git bzr autoconf-archive gnu-standards gettext lib32stdc++6-12-dbg`
      -   `sudo apt-get install libx32stdc++6-12-dbg python3-kerberos python3-paramiko python-configobj-doc python3-openssl python3-socks`
      -   `sudo apt-get install python-requests-doc python3-brotli`

  -   **Tip** : before installing Vivado in Ubuntu be sure to have libtinfo5
      - `sudo apt-get install libtinfo5`

  -   Install GHDL gcc backend (v1.0.0 Compiled with GNAT Version: 10.4.0)
      -   `sudo apt-get install ghdl-gcc`

  -   Install Gtkwave (v3.3.104)
      -   `sudo apt-get install libcanberra-gtk-module`
      -   `sudo apt-get install gtkwave`

- Run b65 board:
    - Run `b65.sh` script with a target name, e.g.
        `./b65.sh 001-target-simple`

How to use (Windows 10)
-----------------------

- Prerequisites:
    cc65 is built with msys/gcc and can be used only from MSYS2 shell.
    GHDL and Gtkwave are Win32 native and don't run inside MSYS2 environment (at least in my machine).
    Make sure ghdl (gcc backend) and gtkwave are in the system PATH
    
    **Powershell only** : the first run of `b65-win-vhdl.bat` after opening a
    powershell instance reports neglectable warnings in vhdl compile

- Run b65 board:
    - Build software running `b65.sh` script with a target name, e.g.
        `./b65.sh 001-target-simple`

    - Build and run VHDL
        Run the batch file `b65-win-vhdl.bat {target}`, e.g.
        `b65-win-vhdl.bat 001-target-simple`

Known issues
----------

**Linux** (and only Linux) Vivado 2018.3 tcl script successfully creates the project
but synthesis fails (after IP synthesized) with the following error:

`
WARNING: [Vivado 12-818] No files matched 'b65/out/002-target-io/vivado/ip/ram/ram_ooc.xdc'
ERROR: [Common 17-55] 'set_property' expects at least one object.
Resolution: If [get_<value>] was used to populate the object, check to make sure this command returns at least one valid object.
INFO: [Common 17-206] Exiting Vivado at Thu Jan 26 15:38:08 2023...
`

ram_ooc.xdc exist, have both read and write permissions and appears to be the
same both in Linux and in Windows; even after changing newlines to unix style
(LF) this issue remains. I also tried to reinstall ubuntu without success.

ram_ooc.xdc:<br/>
`create_clock -name "TS_CLKA" -period 20.0 [ get_ports clka ]`<br/>
`set_property HD.CLK_SRC BUFGCTRL_X0Y0 [ get_ports clka ]`

License
-------

Copyright 2023 Luca Bertossi

This file is part of B65.

B65 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

B65 is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with B65.  If not, see <http://www.gnu.org/licenses/>.

Changes
-------

- 2023 jan 15 : 001-target-simple  working (simulation)
- 2023 jan 28 : 002-target-io      working (FPGA proven)
- 2023 feb 12 : 003-target-soft-dl working (FPGA proven)
