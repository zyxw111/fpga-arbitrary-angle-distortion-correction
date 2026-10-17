# Called after synthesis by build.tcl; every probe is named in the RTL.
set fic [open [file join $build_root aadcs_pcie_debug.fic] w]
puts $fic "#Fabric Core Inserter Project File"
puts $fic "Project.device.designInputFile=[file join $build_root synthesize aadcs_pcie_top_syn.adf]"
puts $fic "Project.device.ScanChain=1"
puts $fic "Project.device.UserJtag=0"
puts $fic "Project.device.deviceFamily=Logos2"
puts $fic "Project.device.deviceModel=PG2L100H"
puts $fic "Project.device.devicePackage=FBG484"
puts $fic "Project.device.deviceSpeedGrade=-6"
puts $fic "Project.Architecture=2 1 1 1 1"
puts $fic "Project.unit.dimension=2"
foreach core {0 1} {
    set prefix "Project.unit<$core>"
    # ADS names the net on the internal side of the external input buffer.
    set clock [expr {$core == 0 ? "pclk_div2" : "nt_free_clk"}]
    set reset [expr {$core == 0 ? "dma_reset_n" : "power_up_rst_n"}]
    puts $fic "$prefix.clockChannel=$clock"
    puts $fic "$prefix.resetChannel=$reset"
    puts $fic "$prefix.clockEdge=Rising"
    puts $fic "$prefix.ramType=1"
    puts $fic "$prefix.dataDepth=1024"
    puts $fic "$prefix.dataEqualsTrigger=true"
    puts $fic "$prefix.enablePowerOnInitData=false"
    puts $fic "$prefix.enableStorageQualification=false"
    puts $fic "$prefix.triggerSequencerLevels=1"
    puts $fic "$prefix.enableMultiWindow=false"
    puts $fic "$prefix.triggerPortCount=1"
    set signals {}
    if {$core == 0} {
        foreach {net width} {debug_flags 16 source_data 128 debug_read_count 32} {
            for {set bit 0} {$bit < $width} {incr bit} { lappend signals "$net\[$bit\]" }
        }
    } else {
        foreach {net width} {debug_status_sync 6 debug_heartbeat 32} {
            for {set bit 0} {$bit < $width} {incr bit} { lappend signals "$net\[$bit\]" }
        }
    }
    set channel 0
    foreach net $signals { puts $fic "$prefix.triggerChannel<0><$channel>=$net"; incr channel }
    puts $fic "$prefix.triggerMatchCount<0>=1"
    puts $fic "$prefix.triggerMatchCountWidth<0>=0"
    puts $fic "$prefix.triggerMatchType<0>=1"
    puts $fic "$prefix.triggerPortIsData<0>=true"
    puts $fic "$prefix.triggerPortWidth<0>=$channel"
}
close $fic
