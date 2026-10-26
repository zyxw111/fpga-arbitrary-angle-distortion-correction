# SRAM only. Use program.ps1 to select and check this project's bitstream.
if {![info exists env(AADCS_BITSTREAM)]} {error "Use HDMI_Warp/program.ps1"}
cfg_connect -ip 127.0.0.1 -port 65420
cfg_set_cable_property -index 0 -freq 500KHz
cfg_scan_chain
cfg_assign_file -file $env(AADCS_BITSTREAM) -device_index 0
cfg_set_device_property -device_index 0 -program 1
set program_result [catch {cfg_program -device_index 0} message]
puts "PROGRAM_RESULT=$program_result $message"
cfg_read_device_property -mode 3 -device_index 0
cfg_disconnect
cfg_close
