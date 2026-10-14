set project_root [file normalize [file join [file dirname [info script]] ..]]
set build_root [file join $project_root build]
file mkdir $build_root
cd $build_root
add_design [file join $project_root {rtl/aadcs_pcie_top.v}]
add_design [file join $project_root {rtl/pcie_dma/fifo/ipm_distributed_sdpram_v1_2_distributed_fifo.v}]
add_design [file join $project_root {rtl/pcie_dma/fifo/pgs_pciex4_fifo_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/fifo/pgs_pciex4_fifo_v1_2.v}]
add_design [file join $project_root {rtl/pcie_dma/ipm_distributed_sdpram_v1_2.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_expd_apb_mux.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_controller.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_cpld_tx_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_mrd_tx_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_mwr_tx_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_ram/ips2l_pcie_dma_ram.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_ram/rtl/ipm2l_sdpram_v1_1_ips2l_pcie_dma_ram.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_rd_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_rx_cpld_wr_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_rx_mwr_wr_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_rx_top.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_tlp_rcv.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_tlp_tx_mux.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_tx_cpld_rd_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_tx_mwr_rd_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_tx_top.v}]
add_design [file join $project_root {rtl/pcie_dma/ips2l_pcie_dma_wr_ctrl.v}]
add_design [file join $project_root {rtl/pcie_dma/pgs_pciex4_prefetch_fifo_v1_2.v}]
add_design [file join $project_root {rtl/pcie_test_source.v}]
add_design [file join $project_root {ip/pcie_test/pcie_test.idf}]
add_constraint [file join $project_root constraints pcie_100h.fdc]
set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484
compile -top_module aadcs_pcie_top
synthesize -ads -selected_syn_tool_opt 2
dev_map
pnr
report_timing
report_power
gen_bit_stream -compress_bitstream true -master_configuration_clock_frequency {40M}
