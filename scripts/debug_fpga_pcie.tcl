# Run in Fabric Debugger's Tcl console: source <absolute path to this script>.
# Download the matching DebugCore bitstream first. SRAM programming resets PCIe.
set repo [file normalize [file join [file dirname [info script]] ..]]
set fic [file join $repo firmware fpga pcie-test aadcs_pcie_top_debug.fic]
if {[info exists env(AADCS_DEBUG_FIC)]} { set fic $env(AADCS_DEBUG_FIC) }
set output [file join $repo FPGA_AADCS sim results]
file mkdir $output
dbg_connect -ip 127.0.0.1 -port 65420
dbg_scan_chain
dbg_import_fic -file $fic
dbg_list
dbg_set_cur_core -device 0 -core 1
# Debugger lists bus channels from least to most significant bit.
dbg_add_bus -name status -channel 0-5
dbg_add_bus -name heartbeat -channel 6-37
dbg_add_all_to_waveform
dbg_add_all_to_listing
dbg_trig_immd
dbg_set_cur_core -device 0 -core 0
dbg_add_bus -name flags -channel 0-15
dbg_add_bus -name source_data -channel 16-143
dbg_add_bus -name read_count -channel 144-175
dbg_add_all_to_waveform
dbg_add_all_to_listing
dbg_trig_immd
dbg_save_project -file [file join $output pcie-idle.dprj]
# TU0 bit 8 is source_read. Capture the following payload and pre-trigger state.
set read_match "[string repeat X 167]1[string repeat X 8]"
dbg_set_unit -unit 0 -func "==" -value $read_match -radix 0
dbg_set_condition -select 0 -set "TU0"
dbg_set_capture -type 0 -windows 1 -position 128
dbg_run
# Once ARM sends descriptors and capture completes, run:
# dbg_save_project -file <absolute path>/pcie-dma.dprj
# Saves both .dprj and .wdf. Leave JTAG connected to inspect or rearm the trigger.
