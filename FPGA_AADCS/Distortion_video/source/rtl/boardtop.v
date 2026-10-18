// AADCS PCIe bring-up: PG2L100H-6IFBG484, Gen1 x2, no camera/DDR dependency.
// KEY0 resets the endpoint. KEY1 held low selects the counter test.
module boardtop #(
    parameter integer DEMO_GROUP=0, DEMO_VIEW=1
)(
    output mem_cs_n,output mem_rst_n,output mem_ck,output mem_ck_n,output mem_cke,
    output mem_ras_n,output mem_cas_n,output mem_we_n,output mem_odt,
    output [14:0] mem_a,output [2:0] mem_ba,inout [1:0] mem_dqs,inout [1:0] mem_dqs_n,
    inout [15:0] mem_dq,output [1:0] mem_dm,
    input wire board_clk_p,input wire board_clk_n,
    input wire key0_n,
    input wire key1_n,
    input wire ref_clk_p,
    input wire ref_clk_n,
    input wire [1:0] rxp,
    input wire [1:0] rxn,
    output wire [1:0] txp,
    output wire [1:0] txn,
    output wire link_led,
    output wire activity_led
);
    wire  pclk;
    wire  pclk_div2;
    wire  ref_clk;
    wire  core_rst_n;
    wire  axis_master_tvalid;
    wire  axis_master_tready;
    wire [127:0] axis_master_tdata;
    wire [3:0] axis_master_tkeep;
    wire  axis_master_tlast;
    wire [7:0] axis_master_tuser;
    wire  axis_slave0_tready;
    wire  axis_slave0_tvalid;
    wire [127:0] axis_slave0_tdata;
    wire  axis_slave0_tlast;
    wire  axis_slave0_tuser;
    wire  axis_slave1_tready;
    wire  axis_slave1_tvalid;
    wire [127:0] axis_slave1_tdata;
    wire  axis_slave1_tlast;
    wire  axis_slave1_tuser;
    wire  axis_slave2_tready;
    wire  axis_slave2_tvalid;
    wire [127:0] axis_slave2_tdata;
    wire  axis_slave2_tlast;
    wire  axis_slave2_tuser;
    wire [7:0] cfg_pbus_num;
    wire [4:0] cfg_pbus_dev_num;
    wire [2:0] cfg_max_rd_req_size;
    wire [2:0] cfg_max_payload_size;
    wire  smlh_link_up;
    wire  rdlh_link_up;
    wire source_read /* synthesis PAP_MARK_DEBUG="true" */;
    wire [127:0] source_data /* synthesis PAP_MARK_DEBUG="true" */;
    wire dma_reset_n;
    wire power_up_rst_n;
    wire ramp_mode;
    reg [23:0] activity_count;
    wire cross_4kb_boundary;
    // Preserved named probes for the optional Fabric Inserter configuration.
    wire [15:0] debug_flags /* synthesis PAP_MARK_DEBUG="true" */;
    assign debug_flags = {cfg_max_payload_size, core_rst_n, dma_reset_n,
        power_up_rst_n, ramp_mode, source_read, smlh_link_up, rdlh_link_up,
        axis_master_tvalid, axis_master_tready, axis_slave2_tvalid,
        axis_slave2_tready, axis_slave2_tlast, cross_4kb_boundary};
    reg [31:0] debug_read_count /* synthesis PAP_MARK_DEBUG="true" */;
    always @(posedge pclk_div2 or negedge dma_reset_n)
        if (!dma_reset_n) debug_read_count <= 0;
        else if (source_read) debug_read_count <= debug_read_count + 1'b1;
    reg [31:0] debug_heartbeat /* synthesis PAP_MARK_DEBUG="true" */ = 0;
    always @(posedge free_clk_g) debug_heartbeat <= debug_heartbeat + 1'b1;
    reg [5:0] debug_status_meta = 0;
    reg [5:0] debug_status_sync /* synthesis PAP_MARK_DEBUG="true" */ = 0;
    always @(posedge free_clk_g) begin
        debug_status_meta <= {key1_n,key0_n,power_up_rst_n,core_rst_n,
                              smlh_link_up,rdlh_link_up};
        debug_status_sync <= debug_status_meta;
    end

    wire board_ref,board_ref_g,clock25,board_clock_locked,free_clk_g;
    GTP_INBUFDS u_board_input(.I(board_clk_p),.IB(board_clk_n),.O(board_ref));
    GTP_CLKBUFG u_board_ref(.CLKIN(board_ref),.CLKOUT(board_ref_g));
    ips2l_ddrphy_gpll_v1_3 #(.CLKIN_FREQ(125.0),.BANDWIDTH("OPTIMIZED"),
      .IDIV(1),.FDIV(8.0),.DUTYF(4),.ODIV0(40.0),.DUTY0(20),
      .ODIV1(40),.STATIC_PHASE0(0),.INTERNAL_FB("CLKOUTF")) u_board_clock(
      .clk_in0(board_ref_g),.pll_rst(!key0_n),.dps_clk(1'b0),.dps_en(1'b0),.dps_dir(1'b0),
      .clkout0_gate(1'b0),.clkout0(clock25),.clkout0n(),.clkout1(),.clkout1n(),
      .dps_done(),.pll_lock(board_clock_locked));
    GTP_CLKBUFG u_free_clk(.CLKIN(clock25),.CLKOUT(free_clk_g));
    pcie_reset_control u_reset_control(
        .free_clk(free_clk_g), .key0_n(key0_n && board_clock_locked), .key1_n(1'b1),
        .dma_clk(pclk_div2), .core_rst_n(core_rst_n),
        .power_up_rst_n(power_up_rst_n), .dma_reset_n(dma_reset_n),
        .ramp_mode(ramp_mode)
    );
    assign link_led = smlh_link_up && rdlh_link_up;
    always @(posedge pclk_div2 or negedge dma_reset_n) begin
        if (!dma_reset_n) activity_count <= 0;
        else if (source_read) activity_count <= activity_count + 1'b1;
    end
    assign activity_led = (error_code!=0 || host_error!=0) ? debug_heartbeat[22] : image_ready;

    wire dclk,lock,init;
    wire av,ar,wr,wl,rv,rr,rl;wire [27:0] aa,ra;wire [3:0] al,rlen;
    wire [127:0] wd,rd;wire [15:0] ws;
    reg [1:0] dreset,iready;
    wire init_async=power_up_rst_n && lock && init;
    always @(posedge dclk or negedge dma_reset_n)
      if(!dma_reset_n)dreset<=0;else dreset<={dreset[0],1'b1};
    always @(posedge dclk or negedge init_async)
      if(!init_async)iready<=0;else iready<={iready[0],1'b1};
    wire image_ready,prepared,launch,source_done,source_valid;
    wire request,tx_busy,host_ready,host_busy,req_toggle;
    wire [9:0] length;wire [63:0] address;wire [12:0] bytes;
    wire [7:0] error_code,host_error;wire [31:0] checksum;
    wire [27:0] cursor;wire [11:0] status_addr;wire [127:0] status_data;
    still #(.GROUP(DEMO_GROUP),.VIEW(DEMO_VIEW)) u_image(
      .pix_clk(free_clk_g),.clk(dclk),.dma_clk(pclk_div2),.rst_n(dreset[1]),.init_done(iready[1]),
      .request_toggle(req_toggle),.request_bytes(bytes),.frame_ready(image_ready),
      .error_code(error_code),.checksum(checksum),.cursor(cursor),
      .prepared(prepared),.launch(launch),.rd_req(source_read),.rd_data(source_data),
      .rd_valid(source_valid),.rd_done(source_done),
      .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
      .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
    wire rvalid;
    hostlink #(.GROUP(DEMO_GROUP),.VIEW(DEMO_VIEW)) u_host(
      .clk(pclk_div2),.rst_n(dma_reset_n),.frame_ready(image_ready),.engine_error(error_code),
      .checksum(checksum),.cursor(cursor),.request(request),.length(length),.address(address),
      .tx_busy(tx_busy),.prepared(prepared),.rd_done(source_done),
      .ready(host_ready),.launch(launch),.request_toggle(req_toggle),.bytes(bytes),
      .busy(host_busy),.status_addr(),.bar_addr(status_addr),.status_data(status_data),.error_code(host_error));
    ddrlink u_mem(.ref_clk(free_clk_g),.rst_n(power_up_rst_n),.clk(dclk),.pll_lock(lock),.init_done(init),
      .axi_awvalid(av),.axi_awready(ar),.axi_awaddr(aa),.axi_awlen(al),
      .axi_wdata(wd),.axi_wstrb(ws),.axi_wready(wr),.axi_wusero_last(wl),
      .axi_arvalid(rv),.axi_arready(rr),.axi_araddr(ra),.axi_arlen(rlen),
      .axi_rvalid(rvalid),.axi_rlast(rl),.axi_rdata(rd),
      .mem_cs_n(mem_cs_n),.mem_rst_n(mem_rst_n),.mem_ck(mem_ck),.mem_ck_n(mem_ck_n),
      .mem_cke(mem_cke),.mem_ras_n(mem_ras_n),.mem_cas_n(mem_cas_n),.mem_we_n(mem_we_n),
      .mem_odt(mem_odt),.mem_a(mem_a),.mem_ba(mem_ba),.mem_dqs(mem_dqs),.mem_dqs_n(mem_dqs_n),
      .mem_dq(mem_dq),.mem_dm(mem_dm));

    pcie_test u_ips2l_pcie_wrap(
        .pclk(pclk),
        .pclk_div2(pclk_div2),
        .ref_clk(ref_clk),
        .ref_clk_n(ref_clk_n),
        .ref_clk_p(ref_clk_p),
        .button_rst_n(key0_n),
        .power_up_rst_n(power_up_rst_n),
        .perst_n(1'b1),
        .core_rst_n(core_rst_n),
        .p_sel(1'd0),
        .p_strb(4'd0),
        .p_addr(16'd0),
        .p_wdata(32'd0),
        .p_ce(1'd0),
        .p_we(1'd0),
        .p_rdy(),
        .p_rdata(),
        .rxn(rxn),
        .rxp(rxp),
        .txn(txn),
        .txp(txp),
        .pcs_nearend_loop(4'd0),
        .pma_nearend_ploop(4'd0),
        .pma_nearend_sloop(4'd0),
        .axis_master_tvalid(axis_master_tvalid),
        .axis_master_tready(axis_master_tready),
        .axis_master_tdata(axis_master_tdata),
        .axis_master_tkeep(axis_master_tkeep),
        .axis_master_tlast(axis_master_tlast),
        .axis_master_tuser(axis_master_tuser),
        .axis_slave0_tready(axis_slave0_tready),
        .axis_slave0_tvalid(axis_slave0_tvalid),
        .axis_slave0_tdata(axis_slave0_tdata),
        .axis_slave0_tlast(axis_slave0_tlast),
        .axis_slave0_tuser(axis_slave0_tuser),
        .axis_slave1_tready(axis_slave1_tready),
        .axis_slave1_tvalid(axis_slave1_tvalid),
        .axis_slave1_tdata(axis_slave1_tdata),
        .axis_slave1_tlast(axis_slave1_tlast),
        .axis_slave1_tuser(axis_slave1_tuser),
        .axis_slave2_tready(axis_slave2_tready),
        .axis_slave2_tvalid(axis_slave2_tvalid),
        .axis_slave2_tdata(axis_slave2_tdata),
        .axis_slave2_tlast(axis_slave2_tlast),
        .axis_slave2_tuser(axis_slave2_tuser),
        .pm_xtlh_block_tlp(),
        .cfg_send_cor_err_mux(),
        .cfg_send_nf_err_mux(),
        .cfg_send_f_err_mux(),
        .cfg_sys_err_rc(),
        .cfg_aer_rc_err_mux(),
        .radm_cpl_timeout(),
        .cfg_pbus_num(cfg_pbus_num),
        .cfg_pbus_dev_num(cfg_pbus_dev_num),
        .cfg_max_rd_req_size(cfg_max_rd_req_size),
        .cfg_bus_master_en(),
        .cfg_max_payload_size(cfg_max_payload_size),
        .cfg_ext_tag_en(),
        .cfg_rcb(),
        .cfg_mem_space_en(),
        .cfg_pm_no_soft_rst(),
        .cfg_crs_sw_vis_en(),
        .cfg_no_snoop_en(),
        .cfg_relax_order_en(),
        .cfg_tph_req_en(),
        .cfg_pf_tph_st_mode(),
        .rbar_ctrl_update(),
        .cfg_atomic_req_en(),
        .radm_idle(),
        .radm_q_not_empty(),
        .radm_qoverflow(),
        .diag_ctrl_bus(2'd0),
        .cfg_link_auto_bw_mux(),
        .cfg_bw_mgt_mux(),
        .cfg_pme_mux(),
        .app_ras_des_sd_hold_ltssm(1'd0),
        .app_ras_des_tba_ctrl(2'd0),
        .dyn_debug_info_sel(4'd0),
        .debug_info_mux(),
        .smlh_link_up(smlh_link_up),
        .rdlh_link_up(rdlh_link_up),
        .smlh_ltssm_state()
    );

    ips2l_pcie_dma #(.DEVICE_TYPE(3'b000), .AXIS_SLAVE_NUM(3)) u_dma(
        .i_video_ready(host_ready),.i_video_busy(host_busy),
        .o_video_request(request),.o_video_length(length),.o_video_address(address),
        .o_video_tx_busy(tx_busy),.o_video_status_addr(status_addr),.i_video_status_data(status_data),
        .clk(pclk_div2),
        .rst_n(dma_reset_n),
        .i_cfg_pbus_num(cfg_pbus_num),
        .i_cfg_pbus_dev_num(cfg_pbus_dev_num),
        .i_cfg_max_rd_req_size(cfg_max_rd_req_size),
        .i_cfg_max_payload_size(cfg_max_payload_size),
        .i_axis_master_tvld(axis_master_tvalid),
        .o_axis_master_trdy(axis_master_tready),
        .i_axis_master_tdata(axis_master_tdata),
        .i_axis_master_tkeep(axis_master_tkeep),
        .i_axis_master_tlast(axis_master_tlast),
        .i_axis_master_tuser(axis_master_tuser),
        .o_trgt1_radm_pkt_halt(),
        .i_axis_slave0_trdy(axis_slave0_tready),
        .o_axis_slave0_tvld(axis_slave0_tvalid),
        .o_axis_slave0_tdata(axis_slave0_tdata),
        .o_axis_slave0_tlast(axis_slave0_tlast),
        .o_axis_slave0_tuser(axis_slave0_tuser),
        .i_axis_slave1_trdy(axis_slave1_tready),
        .o_axis_slave1_tvld(axis_slave1_tvalid),
        .o_axis_slave1_tdata(axis_slave1_tdata),
        .o_axis_slave1_tlast(axis_slave1_tlast),
        .o_axis_slave1_tuser(axis_slave1_tuser),
        .i_axis_slave2_trdy(axis_slave2_tready),
        .o_axis_slave2_tvld(axis_slave2_tvalid),
        .o_axis_slave2_tdata(axis_slave2_tdata),
        .o_axis_slave2_tlast(axis_slave2_tlast),
        .o_axis_slave2_tuser(axis_slave2_tuser),
        .i_cfg_ido_req_en(1'd0),
        .i_cfg_ido_cpl_en(1'd0),
        .i_xadm_ph_cdts(8'd0),
        .i_xadm_pd_cdts(12'd0),
        .i_xadm_nph_cdts(8'd0),
        .i_xadm_npd_cdts(12'd0),
        .i_xadm_cplh_cdts(8'd0),
        .i_xadm_cpld_cdts(12'd0),
        .i_apb_psel(1'd0),
        .i_apb_paddr(9'd0),
        .i_apb_pwdata(32'd0),
        .i_apb_pstrb(4'd0),
        .i_apb_pwrite(1'd0),
        .i_apb_penable(1'd0),
        .o_apb_prdy(),
        .o_apb_prdata(),
        .o_cross_4kb_boundary(cross_4kb_boundary),
        .o_dma_write_data_req(source_read),
        .i_dma_write_data(source_data)
    );
endmodule
