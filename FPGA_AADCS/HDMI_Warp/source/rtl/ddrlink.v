// x16 HMIC address is a 16-bit memory location, not a byte address.
// UG042003 pp35-36 + vendor test_wr_ctrl: 16 beats advance 128 locations.
// Public interface remains BYTE addressed, with 16-byte alignment.
module ddrlink(
input ref_clk,input rst_n,output clk,output pll_lock,output init_done,
 input [27:0] axi_awaddr,input [3:0] axi_awlen,input axi_awvalid,output axi_awready,
 input [127:0] axi_wdata,input [15:0] axi_wstrb,output axi_wready,output axi_wusero_last,
 input [27:0] axi_araddr,input [3:0] axi_arlen,input axi_arvalid,output axi_arready,
 output [127:0] axi_rdata,output axi_rvalid,output axi_rlast,
 output mem_cs_n,output mem_rst_n,output mem_ck,output mem_ck_n,output mem_cke,
 output mem_ras_n,output mem_cas_n,output mem_we_n,output mem_odt,
 output [14:0] mem_a,output [2:0] mem_ba,inout [1:0] mem_dqs,inout [1:0] mem_dqs_n,
 inout [15:0] mem_dq,output [1:0] mem_dm);
wire [27:0] native_awaddr={1'b0,axi_awaddr[27:1]};
wire [27:0] native_araddr={1'b0,axi_araddr[27:1]};
ddr3 u_ddr(
    .ref_clk                    (ref_clk),
    .resetn                     (rst_n),
    .core_clk                   (clk),
    .pll_lock                   (pll_lock),
    .phy_pll_lock               (),
    .gpll_lock                  (),
    .rst_gpll_lock              (),
    .ddrphy_cpd_lock            (),
    .ddr_init_done              (init_done),

    .axi_awaddr                 (native_awaddr),
    .axi_awuser_ap              (1'b0),
    .axi_awuser_id              (4'd0),
    .axi_awlen                  (axi_awlen                    ),
    .axi_awready                (axi_awready                  ),
    .axi_awvalid                (axi_awvalid                  ),

    .axi_wdata                  (axi_wdata                    ),
    .axi_wstrb                  (axi_wstrb                    ),
    .axi_wready                 (axi_wready                   ),
    .axi_wusero_id              (),
    .axi_wusero_last            (axi_wusero_last              ),

    .axi_araddr                 (native_araddr),
    .axi_aruser_ap              (1'b0),
    .axi_aruser_id              (4'd0),
    .axi_arlen                  (axi_arlen                    ),
    .axi_arready                (axi_arready                  ),
    .axi_arvalid                (axi_arvalid                  ),

    .axi_rdata                  (axi_rdata                    ),
    .axi_rid                    (),
    .axi_rlast                  (axi_rlast                    ),
    .axi_rvalid                 (axi_rvalid                   ),

    .apb_clk                    (1'b0                         ),
    .apb_rst_n                  (1'b0                         ),
    .apb_sel                    (1'b0                         ),
    .apb_enable                 (1'b0                         ),
    .apb_addr                   (8'd0                         ),
    .apb_write                  (1'b0                         ),
    .apb_ready                  (                             ),
    .apb_wdata                  (16'd0                        ),
    .apb_rdata                  (                             ),


    .mem_cs_n                   (mem_cs_n                     ),

    .mem_rst_n                  (mem_rst_n                    ),
    .mem_ck                     (mem_ck                       ),
    .mem_ck_n                   (mem_ck_n                     ),
    .mem_cke                    (mem_cke                      ),
    .mem_ras_n                  (mem_ras_n                    ),
    .mem_cas_n                  (mem_cas_n                    ),
    .mem_we_n                   (mem_we_n                     ),
    .mem_odt                    (mem_odt                      ),
    .mem_a                      (mem_a                        ),
    .mem_ba                     (mem_ba                       ),
    .mem_dqs                    (mem_dqs                      ),
    .mem_dqs_n                  (mem_dqs_n                    ),
    .mem_dq                     (mem_dq                       ),
    .mem_dm                     (mem_dm                       ),

    //debug
    .dbg_gate_start             (1'b0                         ),
    .dbg_cpd_start              (1'b0                         ),
    .dbg_ddrphy_rst_n           (1'b1                         ),
    .dbg_gpll_scan_rst          (1'b0                         ),

    .samp_position_dyn_adj      (1'b0                         ),
    .init_samp_position_even    (16'd0                        ),
    .init_samp_position_odd     (16'd0                        ),

    .wrcal_position_dyn_adj     (1'b0                         ),
    .init_wrcal_position        (16'd0                        ),

    .force_read_clk_ctrl        (1'b0                         ),
    .init_slip_step             (8'd0                         ),
    .init_read_clk_ctrl         (6'd0                         ),

    .debug_calib_ctrl           (                             ),
    .dbg_dll_upd_state          (                             ),
    .dbg_slice_status           (                             ),
    .dbg_slice_state            (                             ),
    .debug_data                 (                             ),
    .debug_gpll_dps_phase       (                             ),

    .dbg_rst_dps_state          (                             ),
    .dbg_tran_err_rst_cnt       (                             ),
    .dbg_ddrphy_init_fail       (                             ),

    .debug_cpd_offset_adj       (1'b0                         ),
    .debug_cpd_offset_dir       (1'b0                         ),
    .debug_cpd_offset           (10'd0                        ),
    .debug_dps_cnt_dir0         (                             ),
    .debug_dps_cnt_dir1         (                             ),

    .ck_dly_en                  (1'b0                         ),
    .init_ck_dly_step           (8'd0                         ),
    .ck_dly_set_bin             (                             ),

    .align_error                (                             ),
    .debug_rst_state            (                             ),
    .debug_cpd_state            (                             )

  );

endmodule
