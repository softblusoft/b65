set_property PACKAGE_PIN W5 [get_ports clock]
set_property IOSTANDARD LVCMOS33 [get_ports clock]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clock]


set_property PACKAGE_PIN U18 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]


set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]

set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[2]}]

set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[3]}]

set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[4]}]

set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[5]}]

set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[6]}]

set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[7]}]

set_property PACKAGE_PIN V13 [get_ports {led[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[8]}]

set_property PACKAGE_PIN V3 [get_ports {led[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[9]}]

set_property PACKAGE_PIN W3 [get_ports {led[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[10]}]

set_property PACKAGE_PIN U3 [get_ports {led[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[11]}]

set_property PACKAGE_PIN P3 [get_ports {led[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[12]}]

set_property PACKAGE_PIN N3 [get_ports {led[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[13]}]

set_property PACKAGE_PIN P1 [get_ports {led[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[14]}]

set_property PACKAGE_PIN L1 [get_ports {led[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[15]}]


set_property PACKAGE_PIN V17 [get_ports {slide[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[0]}]

set_property PACKAGE_PIN V16 [get_ports {slide[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[1]}]

set_property PACKAGE_PIN W16 [get_ports {slide[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[2]}]

set_property PACKAGE_PIN W17 [get_ports {slide[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[3]}]

set_property PACKAGE_PIN W15 [get_ports {slide[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[4]}]

set_property PACKAGE_PIN V15 [get_ports {slide[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[5]}]

set_property PACKAGE_PIN W14 [get_ports {slide[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[6]}]

set_property PACKAGE_PIN W13 [get_ports {slide[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[7]}]

set_property PACKAGE_PIN V2 [get_ports {slide[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[8]}]

set_property PACKAGE_PIN T3 [get_ports {slide[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[9]}]

set_property PACKAGE_PIN T2 [get_ports {slide[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[10]}]

set_property PACKAGE_PIN R3 [get_ports {slide[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[11]}]

set_property PACKAGE_PIN W2 [get_ports {slide[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[12]}]

set_property PACKAGE_PIN U1 [get_ports {slide[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[13]}]

set_property PACKAGE_PIN T1 [get_ports {slide[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[14]}]

set_property PACKAGE_PIN R2 [get_ports {slide[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {slide[15]}]


set_property PACKAGE_PIN W19 [get_ports {push[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push[0]}]

set_property PACKAGE_PIN T17 [get_ports {push[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push[1]}]

set_property PACKAGE_PIN T18 [get_ports {push[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push[2]}]

set_property PACKAGE_PIN U17 [get_ports {push[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {push[3]}]


set_property PACKAGE_PIN U2 [get_ports {anode[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {anode[0]}]

set_property PACKAGE_PIN U4 [get_ports {anode[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {anode[1]}]

set_property PACKAGE_PIN V4 [get_ports {anode[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {anode[2]}]

set_property PACKAGE_PIN W4 [get_ports {anode[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {anode[3]}]

set_property PACKAGE_PIN W7 [get_ports {cathode[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[0]}]

set_property PACKAGE_PIN W6 [get_ports {cathode[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[1]}]

set_property PACKAGE_PIN U8 [get_ports {cathode[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[2]}]

set_property PACKAGE_PIN V8 [get_ports {cathode[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[3]}]

set_property PACKAGE_PIN U5 [get_ports {cathode[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[4]}]

set_property PACKAGE_PIN V5 [get_ports {cathode[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[5]}]

set_property PACKAGE_PIN U7 [get_ports {cathode[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[6]}]

set_property PACKAGE_PIN V7 [get_ports {cathode[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {cathode[7]}]


set_property PACKAGE_PIN B18 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

set_property PACKAGE_PIN A18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
