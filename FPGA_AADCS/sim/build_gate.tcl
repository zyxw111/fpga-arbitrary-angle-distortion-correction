set fpga_root [file normalize [file join [file dirname [info script]] ..]]
set target $env(AADCS_GATE_TOP)
set output [file join $fpga_root build gate $target]
file mkdir $output
cd $output
add_design [file join $fpga_root rtl pcie_test_source.v]
add_design [file join $fpga_root rtl pcie_reset_control.v]
add_design [file join $fpga_root sim pcie_gate_fixture.v]
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484
compile -top_module $target
synthesize -ads -selected_syn_tool_opt 2
