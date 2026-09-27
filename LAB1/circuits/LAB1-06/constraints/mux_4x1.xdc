## LAB1-06 mux_4x1 - Spartan-7 (xc7s75fgga484-1)
set_property PACKAGE_PIN L4 [get_ports z]
set_property IOSTANDARD LVCMOS33 [get_ports z]

set_property PACKAGE_PIN K4 [get_ports {i[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i[3]}]
set_property PACKAGE_PIN N8 [get_ports {i[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i[2]}]
set_property PACKAGE_PIN N4 [get_ports {i[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i[1]}]
set_property PACKAGE_PIN N1 [get_ports {i[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {i[0]}]

set_property PACKAGE_PIN Y1 [get_ports {s[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {s[1]}]
set_property PACKAGE_PIN W3 [get_ports {s[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {s[0]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
