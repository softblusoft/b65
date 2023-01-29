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
set Vivado_version   2018
set Vivado_Path      "C:\Xilinx\Vivado\2018.3\bin\vivado.bat"
set fpga_device      "xc7a35tcpg236-1"
set CPU6502_Path     "cpu65c02_true_cycle/trunk/released/rtl/vhdl"
set Target_Path      "002-target-io"

# VHDL sources
set files_cpu [list 												\
	"[file normalize "../../$CPU6502_Path/fsm_execution_unit.vhd"]"	\
	"[file normalize "../../$CPU6502_Path/fsm_intnmi.vhd"]"			\
	"[file normalize "../../$CPU6502_Path/reg_pc.vhd"]"				\
	"[file normalize "../../$CPU6502_Path/reg_sp.vhd"]"				\
	"[file normalize "../../$CPU6502_Path/regbank_axy.vhd"]"		\
	"[file normalize "../../$CPU6502_Path/core.vhd"]"				\
]

set files_vhdl [list 												\
	"[file normalize "../../$Target_Path/vhdl/pack.vhd"]"			\
	"[file normalize "../../$Target_Path/vhdl/uart.vhd"]"			\
	"[file normalize "../../$Target_Path/vhdl/extension.vhd"]"		\
]

set files_top [list 												\
	"[file normalize "../../$Target_Path/vhdl/top.vhd"]"			\
]

# Constraints
set constraints [list 												\
"[file normalize "../../$Target_Path/basys3/constraints.xdc"]"		\
]

# IP cores
set cores [list 													\
"[file normalize "../../$Target_Path/basys3/clock_manager.xci"]"	\
"[file normalize "../../$Target_Path/basys3/ram.xci"]"				\
"[file normalize "../../$Target_Path/basys3/rom.xci"]"				\
]

# Setup output folder
file mkdir ../../out/$Target_Path/vivado
cd ../../out/$Target_Path/vivado

# Copy IP cores files to output folder (one IP core per folder)
file mkdir ip
set cores_copy [list]
foreach item $cores {
	set corefilename [file rootname [file tail $item]]
	file mkdir ip/$corefilename
	file copy -force $item ip/$corefilename
	lappend cores_copy [pwd]/ip/$corefilename/$corefilename.xci
}

# Set default sets
set source_set sources_1
set sim_set    sim_1
set constr_set constrs_1
set synth_set  synth_1
set impl_set   impl_1

# Create project
create_project b65 . -part $fpga_device
set project_folder [get_property directory [current_project]]
set project_object [get_projects [current_project]]
set_property -name "ip_output_repo" -value "ip" -objects $project_object

# Add VHDL sources and IP cores
if {[string equal [get_filesets -quiet $source_set] ""]} { create_fileset $source_set }
add_files -norecurse -fileset $source_set $files_cpu
add_files -norecurse -fileset $source_set $files_vhdl
add_files -norecurse -fileset $source_set $files_top
add_files -norecurse -fileset $source_set $cores_copy
foreach item $files_cpu  { set_property -name "file_type" -value "VHDL" -objects [get_files -of_objects [get_filesets $source_set] [list "*$item"]] }
foreach item $files_vhdl { set_property -name "file_type" -value "VHDL" -objects [get_files -of_objects [get_filesets $source_set] [list "*$item"]] }

# Set libraries names
foreach item $files_cpu  { set_property -name "library" -value "r65c02_tc" -objects [get_files -of_objects [get_filesets $source_set] [list "*$item"]] }
foreach item $files_vhdl { set_property -name "library" -value "b65" -objects [get_files -of_objects [get_filesets $source_set] [list "*$item"]] }

set_property -name "top" -value "top" -objects [get_filesets $source_set]

# Add constraints
if {[string equal [get_filesets -quiet $constr_set] ""]} { create_fileset -constrset $constr_set }
add_files -norecurse -fileset [get_filesets $constr_set] $constraints
foreach item $constraints { set_property -name "file_type" -value "XDC" -objects [get_files -of_objects [get_filesets $constr_set] [list "*$item"]] }
set_property -name "target_constrs_file" -value [lindex $constraints 0] -objects [get_filesets $constr_set]

# Copy and set COE (rom initialization) file in rom IP
file copy -force "../../$Target_Path/soft/b65.coe" ip/rom/b65.coe
set_property CONFIG.Coe_File "b65.coe" [get_ips rom]

# Set Synthesis properties
if {[string equal [get_runs -quiet $synth_set] ""]} {
	create_run -name $synth_set -part $fpga_device -flow {Vivado Synthesis $Vivado_version} -strategy "Vivado Synthesis Defaults" -constrset $constr_set
} else {
	set_property strategy "Vivado Synthesis Defaults"        [get_runs $synth_set]
	set_property flow     "Vivado Synthesis $Vivado_version" [get_runs $synth_set]
}

# Set Implementation properties
if {[string equal [get_runs -quiet $impl_set] ""]} {
	create_run -name $impl_set -part $fpga_device -flow {Vivado Implementation $Vivado_version} -strategy "Vivado Implementation Defaults" -constrset $constr_set -parent_run $synth_set
} else {
	set_property strategy "Vivado Implementation Defaults"        [get_runs $impl_set]
	set_property flow     "Vivado Implementation $Vivado_version" [get_runs $impl_set]
}

# Open Vivado GUI
current_run -synthesis      [get_runs $synth_set]
current_run -implementation [get_runs $impl_set]
start_gui
