# Run with cdt_cfg_shell.exe -file <absolute path to this script>.
# Only configures FPGA SRAM. Does not program Flash or eFuse.
set repo [file normalize [file join [file dirname [info script]] ..]]
set bitstream [file join $repo firmware fpga pcie-test aadcs_pcie_top.sbit]
if {[info exists env(AADCS_BITSTREAM)]} { set bitstream $env(AADCS_BITSTREAM) }
if {![file exists $bitstream]} { error "Bitstream not found: $bitstream" }
cfg_connect -ip 127.0.0.1 -port 65420
cfg_set_cable_property -index 0 -freq 1MHz
cfg_scan_chain
cfg_assign_file -file $bitstream -device_index 0
# Explicitly enable WakeDownReconfigure. Verified on this board/remote USB.
# The default property failed with DONE low; ISC-only mode did not complete.
cfg_set_device_property -device_index 0 -program 1
cfg_program -device_index 0
cfg_read_device_property -mode 3 -device_index 0
cfg_disconnect
cfg_close
