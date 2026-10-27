// PG2L100H: HDMIK V1.1 / MS7200 -> DDR -> inverse warp -> DDR -> PCIe.
// KEY0 resets. Capture, warp and DMA use independent immutable frame slots.
module hdmi_warp_top #(
    parameter integer WIDTH=1920,HEIGHT=1080,IN_WIDTH=1920,IN_HEIGHT=1080,VS_ACTIVE_HIGH=1,
    parameter integer PERF_ENABLE=1,PERF_SNAPSHOT_BITS=20,WARP_OVERLAP_WRITE=1,WARP_OUTPUT_BANKS=2
)(
    output mem_cs_n,output mem_rst_n,output mem_ck,output mem_ck_n,output mem_cke,
    output mem_ras_n,output mem_cas_n,output mem_we_n,output mem_odt,
    output [14:0] mem_a,output [2:0] mem_ba,inout [1:0] mem_dqs,inout [1:0] mem_dqs_n,
    inout [15:0] mem_dq,output [1:0] mem_dm,
    input wire board_clk_p,input wire board_clk_n,
    input wire key0_n,
    input wire key1_n,
    input wire pixclk_in,input wire vs_in,input wire hs_in,input wire de_in,
    input wire [7:0] r_in,g_in,b_in,
    inout wire hd_scl,inout wire hd_sda,
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
    wire board_pll_reset;
    board_pll_startup u_board_pll_startup(.clk(board_ref_g),.key0_n(key0_n),.pll_reset(board_pll_reset));
    ips2l_ddrphy_gpll_v1_3 #(.CLKIN_FREQ(125.0),.BANDWIDTH("OPTIMIZED"),
      .IDIV(5),.FDIV(40.0),.DUTYF(40),.ODIV0(40.0),.DUTY0(40),
      .ODIV1(40),.STATIC_PHASE0(0),.INTERNAL_FB("CLKOUTF")) u_board_clock(
      .clk_in0(board_ref_g),.pll_rst(board_pll_reset),.dps_clk(1'b0),.dps_en(1'b0),.dps_dir(1'b0),
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
    assign activity_led = (error_code!=0 || host_error!=0 || camera_error!=0) ? debug_heartbeat[22] : image_ready;

    wire dclk,lock,init;
    wire request,tx_busy,host_ready,host_busy,req_toggle;
    wire video_reset_n=dma_reset_n;
    wire camera_ready,camera_pclk_g;
    wire [7:0] camera_error;
    wire [15:0] camera_id=16'h7200;
    wire [15:0] hdmi_register;
    wire [31:0] captured_frames,dropped_frames;
    wire edid_written;wire [6:0] receiver_state;wire [8:0] receiver_index;
    wire [31:0] receiver_frequency,receiver_transactions;wire [7:0] receiver_read;
    wire [255:0] frame_diagnostics;wire [31:0] native_checksum;
    GTP_CLKBUFG u_hdmi_clock(.CLKIN(pixclk_in),.CLKOUT(camera_pclk_g));
    wire cfg_reset_n,receiver_bus_busy,profile_pending;
    wire [2:0] profile;
    profile_control profiles(.clk(board_ref_g),.rst_n(power_up_rst_n),.key_n(key1_n),
      .bus_busy(receiver_bus_busy),.profile(profile),.cfg_rst_n(cfg_reset_n),.pending(profile_pending));
    hdmi_rx_init receiver(.clk(board_ref_g),.rst_n(cfg_reset_n),.profile_select(profile),.bus_busy(receiver_bus_busy),
      .hd_scl(hd_scl),.hd_sda(hd_sda),.ready(camera_ready),
      .error_code(camera_error),.register_addr(hdmi_register),
      .edid_written(edid_written),.controller_state(receiver_state),.controller_index(receiver_index),
      .receiver_frequency(receiver_frequency),.transactions(receiver_transactions),.last_read(receiver_read));
    wire av,ar,wr,wl,rv,rr,rl,rvalid;wire [27:0] aa,ra;wire [3:0] al,rlen;
    wire [127:0] wd,rd;wire [15:0] ws;
    reg [1:0] dreset,iready;
    wire init_async=power_up_rst_n && lock && init;
    always @(posedge dclk or negedge video_reset_n)
      if(!video_reset_n)dreset<=0;else dreset<={dreset[0],1'b1};
    always @(posedge dclk or negedge init_async)
      if(!init_async)iready<=0;else iready<={iready[0],1'b1};
    wire image_ready,prepared,launch,source_done,source_valid;
    wire [9:0] length;wire [63:0] address;wire [12:0] bytes;
    wire [7:0] error_code,host_error;wire [31:0] checksum;
    wire [27:0] cursor;wire [11:0] status_addr;wire [127:0] host_status;reg [127:0] status_data;
    wire [31:0] camera_flags=host_status[95:64] | (camera_ready?32'd8:32'd0) | (camera_error!=0?32'd16:32'd0) | 32'd192;
    always @*begin
      case(status_addr)
       0:status_data={host_status[127:96],camera_flags,32'h00030000,32'h43414d32};
       2:status_data={checksum,{4'd0,cursor},dropped_frames,live_header[95:64]};
       3:status_data={{24'd0,error_code},{16'd0,hdmi_register},{16'd0,camera_error,host_error},{16'd0,camera_id}};
       4:status_data=frame_diagnostics[127:0];5:status_data=frame_diagnostics[255:128];
       6:status_data={96'd0,native_checksum};
       7:status_data={monitor_frames,pixel_hz,monitor_dimensions,receiver_flags};
       9:status_data={64'd0,source_height,source_width,published_generation};
       10,11:status_data=stream_status;
       12:status_data={active_generation,live_header[159:128],live_header[319:288],live_header[191:160]};
       8,16,17,18,19,20:status_data=0;
       32,33,34,35,36,37,38,39,40,41,42,43,44:status_data=perf_status;
       default:status_data=host_status;
      endcase
    end
    wire control_wr;wire [11:0] control_addr;wire [31:0] control_data;wire [15:0] control_be;
    wire [543:0] defaults,runtime_config;wire [31:0] active_generation,published_generation;
    wire [15:0] source_width,source_height;wire frame_safe,params_pending;wire [127:0] warp_status;
    hdmi_defaults default_bank(.defaults(defaults));
    warp_control control(.host_clk(pclk_div2),.frame_clk(dclk),.rst_n(dreset[1]),
      .wr_en(control_wr),.wr_addr(control_addr),.wr_data(control_data),.wr_be(control_be),
      .defaults(defaults),.frame_safe(frame_safe),.status_addr(status_addr),.status_data(warp_status),
      .active_config(runtime_config),.active_generation(active_generation),.pending(params_pending));
    wire [319:0] live_header;
    assign source_width=live_header[15:0];assign source_height=live_header[31:16];
    assign published_generation=live_header[127:96];assign checksum=live_header[63:32];
    assign frame_diagnostics=256'd0;assign native_checksum=32'd0;
    wire [31:0] ddr_pixel_hz;wire frequency_valid;
    frame_mailbox #(.WIDTH(32)) frequency_mailbox(.src_clk(board_ref_g),.dst_clk(dclk),.rst_n(dreset[1]),
      .src_send(1'b1),.src_data(pixel_hz),.dst_valid(frequency_valid),.dst_data(ddr_pixel_hz));
    // Declare parent-domain taps before the generate scope: otherwise PDS
    // creates local implicit one-bit nets instead of binding the later nets.
    wire [31:0] page_completed;wire stream_busy,stream_wr;wire [11:0] stream_addr;
    wire [31:0] stream_data;wire [127:0] stream_status;
    wire [1023:0] perf_counters;wire [127:0] perf_status;wire [255:0] tile_perf;
    generate if(PERF_ENABLE)begin:perf_enabled
      warp_perf_regs #(.SNAPSHOT_BITS(PERF_SNAPSHOT_BITS)) registers(
        .dclk(dclk),.hclk(pclk_div2),.rst_n(dreset[1]),.counters(perf_counters),.tile_counters(tile_perf),
        .dma_busy(stream_busy),.frame_ready(image_ready),.source_read(source_read),
        .txvalid(axis_master_tvalid),.txready(axis_master_tready),.page_completed(page_completed),
        .status_addr(status_addr),.status_data(perf_status));
    end else begin:perf_disabled
      assign perf_status=128'd0;
    end endgenerate
    hdmi_live #(.PERF_ENABLE(PERF_ENABLE),.WARP_OVERLAP_WRITE(WARP_OVERLAP_WRITE),.WARP_OUTPUT_BANKS(WARP_OUTPUT_BANKS)) u_image(
      .runtime_config(runtime_config),.active_generation(active_generation),
      .frame_safe(frame_safe),.header(live_header),
      .input_width(ddr_record[15:0]),.input_height(ddr_record[31:16]),
      .input_sequence(ddr_record[191:160]),.input_period(ddr_record[95:64]),.input_pixel_hz(ddr_pixel_hz),
      .pixel_valid(pixel_valid),.pixel_sof(pixel_sof),.pixel_rgb(pixel_rgb),
      .pixel_x(pixel_x),.pixel_y(pixel_y),.frame_end(frame_end),.frame_good(frame_good),
      .pclk(camera_pclk_g),.clk(dclk),.dma_clk(pclk_div2),.rst_n(dreset[1]),.init_done(iready[1]),
      .camera_ready(camera_ready && video_reset_n_rx && ddr_record[288]),
      .good_frames(captured_frames),.dropped_frames(dropped_frames),
      .request_toggle(req_toggle),.request_bytes(bytes),.frame_ready(image_ready),
      .error_code(error_code),.cursor(cursor),
      .prepared(prepared),.launch(launch),.rd_req(source_read),.rd_data(source_data),
      .rd_valid(source_valid),.rd_done(source_done),
      .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
      .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl),
      .perf_counters(perf_counters),.tile_perf(tile_perf));
    frame_dma stream(.clk(pclk_div2),.rst_n(video_reset_n),.control_wr(control_wr),.control_addr(control_addr),.control_data(control_data),.control_be(control_be),
      .frame_ready(image_ready),.frame_bytes(live_header[255:224]+32'd16),
      .frame_id(live_header[95:64]),.page_completed(page_completed),.page_busy(host_busy),
      .inject(stream_wr),.inject_addr(stream_addr),.inject_data(stream_data),.busy(stream_busy),
      .status_addr(status_addr),.status_data(stream_status));
    hostlink #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DYNAMIC_GEOMETRY(1)) u_host(
      .mode(2'd0),.switching(1'b0),.generation(32'd0),
      .runtime_width(source_width),.runtime_height(source_height),.runtime_bytes(live_header[255:224]),.complete_count(page_completed),
      .clk(pclk_div2),.rst_n(video_reset_n),.frame_ready(image_ready),.engine_error(error_code),
      .checksum(checksum),.cursor(cursor),.request(request),.length(length),.address(address),
      .tx_busy(tx_busy),.prepared(prepared),.rd_done(source_done),
      .ready(host_ready),.launch(launch),.request_toggle(req_toggle),.bytes(bytes),
      .busy(host_busy),.status_addr(),.bar_addr(status_addr),.status_data(host_status),.error_code(host_error));
    ddrlink u_mem(.ref_clk(free_clk_g),.rst_n(power_up_rst_n),.clk(dclk),.pll_lock(lock),.init_done(init),
      .axi_awvalid(av),.axi_awready(ar),.axi_awaddr(aa),.axi_awlen(al),
      .axi_wdata(wd),.axi_wstrb(ws),.axi_wready(wr),.axi_wusero_last(wl),
      .axi_arvalid(rv),.axi_arready(rr),.axi_araddr(ra),.axi_arlen(rlen),
      .axi_rvalid(rvalid),.axi_rlast(rl),.axi_rdata(rd),
      .mem_cs_n(mem_cs_n),.mem_rst_n(mem_rst_n),.mem_ck(mem_ck),.mem_ck_n(mem_ck_n),
      .mem_cke(mem_cke),.mem_ras_n(mem_ras_n),.mem_cas_n(mem_cas_n),.mem_we_n(mem_we_n),
      .mem_odt(mem_odt),.mem_a(mem_a),.mem_ba(mem_ba),.mem_dqs(mem_dqs),.mem_dqs_n(mem_dqs_n),
      .mem_dq(mem_dq),.mem_dm(mem_dm));

    wire [31:0] pixel_hz,monitor_frames,monitor_dimensions;
    wire [31:0] receiver_flags={receiver_index,receiver_state,camera_error,
      (camera_error!=0),hd_scl,hd_sda,monitor_present,(pixel_hz>1000000),camera_ready,edid_written,power_up_rst_n};
    wire monitor_present;
    wire clock_changed,video_reset_n_rx;
    clock_meter frequency_meter(.sys_clk(board_ref_g),.pix_clk(camera_pclk_g),.rst_n(cfg_reset_n),
      .pixel_hz(pixel_hz),.clock_changed(clock_changed));
    assign video_reset_n_rx=cfg_reset_n && camera_ready && pixel_hz>1000000 && !clock_changed;
    wire pixel_valid,pixel_sof,pixel_eol,frame_end,frame_good;wire [23:0] pixel_rgb;
    wire [15:0] pixel_x,pixel_y;wire [319:0] frame_record,sys_record,ddr_record;
    wire sys_record_valid,ddr_record_valid;
    video_rx receiver_pixels(.pix_clk(camera_pclk_g),.rst_n(video_reset_n_rx),.vs(vs_in),.hs(hs_in),
      .de(de_in),.rgb({r_in,g_in,b_in}),.pixel_valid(pixel_valid),.sof(pixel_sof),.eol(pixel_eol),
      .pixel_rgb(pixel_rgb),.pixel_x(pixel_x),.pixel_y(pixel_y),.frame_end(frame_end),
      .frame_good(frame_good),.frame_record(frame_record));
    frame_mailbox monitor_mailbox(.src_clk(camera_pclk_g),.dst_clk(board_ref_g),.rst_n(video_reset_n_rx),
      .src_send(frame_end),.src_data(frame_record),.dst_valid(sys_record_valid),.dst_data(sys_record));
    frame_mailbox geometry_mailbox(.src_clk(camera_pclk_g),.dst_clk(dclk),.rst_n(video_reset_n_rx),
      .src_send(frame_end),.src_data(frame_record),.dst_valid(ddr_record_valid),.dst_data(ddr_record));
    reg [25:0] frame_age;
    always @(posedge board_ref_g or negedge video_reset_n_rx)
      if(!video_reset_n_rx)frame_age<=26'h3ffffff;
      else if(sys_record_valid)frame_age<=0;else if(!(&frame_age))frame_age<=frame_age+1'b1;
    assign monitor_frames=sys_record[191:160];assign monitor_dimensions=sys_record[31:0];
    assign monitor_present=video_reset_n_rx && sys_record[288] && frame_age<37500000;
    assign debug_pixel={frame_record[191:160],pixel_x,pixel_y,pixel_rgb,hs_in,vs_in,de_in,
                        pixel_valid,pixel_sof,pixel_eol,frame_end,frame_good,32'd0};
    wire [255:0] debug_sink /* synthesis PAP_MARK_DEBUG="true" */;
    wire [127:0] debug_pixel /* synthesis PAP_MARK_DEBUG="true" */;
    reg [103:0] debug_ddr_meta /* synthesis syn_preserve=1 */;
    reg [103:0] debug_ddr_sync /* synthesis syn_preserve=1 */;
    always @(posedge board_ref_g or negedge power_up_rst_n)
      if(!power_up_rst_n)begin debug_ddr_meta<=0;debug_ddr_sync<=0;end
      else begin
        debug_ddr_meta<={frame_diagnostics[31:0],dropped_frames,captured_frames,
          image_ready,dma_reset_n,core_rst_n,smlh_link_up,rdlh_link_up,init,lock,board_clock_locked};
        debug_ddr_sync<=debug_ddr_meta;
      end
    assign debug_sink={debug_ddr_sync[103:72],debug_ddr_sync[71:40],debug_ddr_sync[39:8],
      {camera_error,receiver_read,hdmi_register},monitor_frames,monitor_dimensions,pixel_hz,
      receiver_state,key1_n,debug_ddr_sync[7:0],camera_error,receiver_flags[7:0]};

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

    ips2l_pcie_dma #(.DEVICE_TYPE(3'b000), .AXIS_SLAVE_NUM(3),.FRAME_STREAM(1)) u_dma(
        .i_video_ready(host_ready),.i_video_busy(host_busy),
        .i_stream_busy(stream_busy),.i_stream_wr_en(stream_wr),.i_stream_wr_addr(stream_addr),.i_stream_wr_data(stream_data),
        .o_control_wr_en(control_wr),.o_control_wr_addr(control_addr),.o_control_wr_data(control_data),.o_control_wr_be(control_be),
        .o_video_request(request),.o_video_length(length),.o_video_address(address),
        .o_video_tx_busy(tx_busy),.o_video_status_addr(status_addr),.i_video_status_data(status_data | warp_status),
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
