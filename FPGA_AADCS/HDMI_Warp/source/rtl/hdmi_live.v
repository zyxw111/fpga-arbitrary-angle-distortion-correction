// Three raw and three corrected DDR frame slots. Capture, tile processing and
// host page reads own independent slots and share only complete DDR bursts.
module hdmi_live #(parameter FIFO_BITS=11,SLOT_SHIFT=22,PERF_ENABLE=1,WARP_OVERLAP_WRITE=1,WARP_OUTPUT_BANKS=2,
 parameter [27:0] OUTPUT_BASE=28'h1000000,LUT_BASE=28'h2000000)(
 input pclk,clk,dma_clk,rst_n,init_done,camera_ready,
 input [15:0] input_width,input_height,input [31:0] input_sequence,input_period,input_pixel_hz,
 input pixel_valid,pixel_sof,input [23:0] pixel_rgb,input [15:0] pixel_x,pixel_y,input frame_end,frame_good,
 input [543:0] runtime_config,input [31:0] active_generation,output frame_safe,
 input request_toggle,input [12:0] request_bytes,
 output frame_ready,output [319:0] header,output [7:0] error_code,
 output reg [27:0] cursor,output [31:0] good_frames,dropped_frames,
 output prepared,input launch,rd_req,output [127:0] rd_data,output rd_valid,rd_done,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,wlast,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,rlast,output [1023:0] perf_counters,output [255:0] tile_perf);
 function [1:0] advance;input [1:0] p;begin advance=p==2?0:p+1'b1;end endfunction
 function [27:0] slot_offset;input [1:0] p;begin slot_offset={26'd0,p}<<SLOT_SHIFT;end endfunction
 reg [2:0] raw_free,out_free;
 reg [1:0] raw_queue[0:2],out_queue[0:2];
 reg [1:0] raw_head,raw_tail,raw_count,out_head,out_tail,out_count;
 reg [15:0] raw_width[0:2],raw_height[0:2],out_width[0:2],out_height[0:2];
 reg [31:0] raw_seq[0:2],raw_period[0:2],raw_hz[0:2],out_seq[0:2],out_period[0:2],out_hz[0:2],out_gen[0:2],out_hash[0:2],out_id[0:2],out_bytes[0:2];
 reg [31:0] capture_count,drop_count,publish_count;
 assign good_frames=capture_count;assign dropped_frames=drop_count;
 reg [7:0] capture_error,host_error;
 wire [7:0] process_error;
 assign error_code=capture_error|host_error|process_error;
 integer n;reg raw_space,out_space;reg [1:0] raw_slot,out_slot;
 always @*begin
  raw_space=0;out_space=0;raw_slot=0;out_slot=0;
  for(n=2;n>=0;n=n-1)begin
   if(raw_free[n])begin raw_space=1;raw_slot=n;end
   if(out_free[n])begin out_space=1;out_slot=n;end
  end
 end
 wire [2:0] wav,war,wr,wl;wire [83:0] waa;wire [11:0] wal;
 wire [383:0] wd;wire [47:0] ws;
 wire [1:0] rav,rar,rv,rl;wire [55:0] raa;wire [7:0] ral;wire [127:0] rd;
 video_ddr_arb arb(.clk(clk),.rst_n(rst_n),.wav(wav),.war(war),.waa(waa),.wal(wal),
  .wd(wd),.ws(ws),.wr(wr),.wl(wl),.awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
  .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),.rav(rav),.rar(rar),.raa(raa),.ral(ral),
  .rv(rv),.rl(rl),.rd(rd),.arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
  .rdata(rdata),.rvalid(rvalid),.rlast(rlast));

 localparam C_RESET=0,C_BOOT=1,C_PREPARE=2,C_WRITE=3;
 reg [2:0] cs;reg [5:0] reset_wait;reg source_run,source_enable,pad;
 reg [1:0] capture_slot;reg [15:0] cw,ch;reg [31:0] capture_beats,write_count,watchdog;
 reg [1:0] bad_sync;reg camera_ready_meta,camera_ready_sync;
 wire sv,sr,sof,eof,bad,writer_ready,writer_done,writer_error;wire [127:0] sd;
 wire [31:0] input_pixels=input_width*input_height;
 wire supported=input_width>=32 && input_width<=1920 && input_width[4:0]==0 &&
                input_height>=8 && input_height<=1080 && input_pixels[6:0]==0;
 hdmi_rx_stream #(.FIFO_BITS(FIFO_BITS)) source(.pclk(pclk),.clk(clk),.rst_n(rst_n && source_run),
  .enable(source_enable),.width(cw),.height(ch),.pixel_valid(pixel_valid),.sof(pixel_sof),
  .pixel_rgb(pixel_rgb),.pixel_x(pixel_x),.pixel_y(pixel_y),.frame_end(frame_end),.frame_good(frame_good),
  .valid(sv),.ready(sr && cs==C_WRITE && !pad),.data(sd),.out_sof(sof),.out_eof(eof),.bad(bad));
 burst capture_writer(.clk(clk),.rst_n(rst_n),.start(cs==C_PREPARE),.start_ready(writer_ready),
  .base_addr(slot_offset(capture_slot)),.beats(capture_beats),
  .in_valid(cs==C_WRITE && (pad || sv)),.in_ready(sr),.in_data(pad?128'd0:sd),
  .awvalid(wav[0]),.awready(war[0]),.awaddr(waa[0+:28]),.awlen(wal[0+:4]),
  .wdata(wd[0+:128]),.wstrb(ws[0+:16]),.wready(wr[0]),.wlast(wl[0]),.done(writer_done),.error(writer_error));
 wire capture_allocate=cs==C_BOOT && init_done && camera_ready_sync && supported && raw_space && writer_ready;
 wire capture_finish=cs==C_WRITE && writer_done;
 wire raw_push=capture_finish && !pad && !bad_sync[1];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  cs<=C_RESET;reset_wait<=0;source_run<=0;source_enable<=0;pad<=0;capture_slot<=0;cw<=0;ch<=0;
  capture_beats<=0;write_count<=0;watchdog<=0;bad_sync<=0;camera_ready_meta<=0;camera_ready_sync<=0;capture_error<=0;
 end else begin
  bad_sync<={bad_sync[0],bad};camera_ready_meta<=camera_ready;camera_ready_sync<=camera_ready_meta;
  if(writer_error)capture_error<=8'h01;
  case(cs)
   C_RESET:begin
    source_run<=0;source_enable<=0;reset_wait<=reset_wait+1'b1;
    if(reset_wait==31)begin source_run<=1;cs<=C_BOOT;end
   end
   C_BOOT:if(capture_allocate)begin
    capture_slot<=raw_slot;cw<=input_width;ch<=input_height;capture_beats<=input_pixels>>3;
    write_count<=0;pad<=0;watchdog<=0;cs<=C_PREPARE;
   end
   C_PREPARE:begin source_enable<=1;cs<=C_WRITE;end
   C_WRITE:begin
    watchdog<=watchdog+1'b1;
    if(bad_sync[1] || watchdog==131250000)begin pad<=1;source_enable<=0;end
    if(sr && (pad || sv))begin
     write_count<=write_count+1'b1;
     if(!pad && (sof!=(write_count==0) || eof!=(write_count==capture_beats-1)))pad<=1;
     if(!pad && eof)source_enable<=0;
    end
    if(writer_done)begin cs<=C_RESET;reset_wait<=0;end
   end
  endcase
 end

 localparam P_IDLE=0,P_CONFIG=1,P_BUILD_START=2,P_BUILD=3,P_START=4,P_RUN=5;
 reg [2:0] ps;reg [2:0] config_wait;
 reg [15:0] pw,ph,lut_width,lut_height;
 reg [31:0] lut_generation,processing_generation;
 reg lut_valid;reg [1:0] processing_raw,processing_out;
 wire build_ready,build_done,build_error,process_ready,process_done;
 wire [31:0] process_hash;
 assign frame_safe=ps==P_IDLE;
 wire raw_pop=ps==P_START && process_ready;
 wire out_push=ps==P_RUN && process_done;
 warp_lut #(.BASE(LUT_BASE)) builder(.clk(clk),.rst_n(rst_n),.start(ps==P_BUILD_START),.width(pw),.height(ph),
  .config_bank(runtime_config),.ready(build_ready),.done(build_done),.error(build_error),
  .awvalid(wav[1]),.awready(war[1]),.awaddr(waa[28+:28]),.awlen(wal[4+:4]),
  .wdata(wd[128+:128]),.wstrb(ws[16+:16]),.wready(wr[1]),.wlast(wl[1]));
 warp_tiles #(.LUT_BASE(LUT_BASE),.WARP_OVERLAP_WRITE(WARP_OVERLAP_WRITE),.WARP_OUTPUT_BANKS(WARP_OUTPUT_BANKS)) processor(.clk(clk),.rst_n(rst_n),.start(ps==P_START),.width(pw),.height(ph),
  .source_base(slot_offset(processing_raw)),.output_base(OUTPUT_BASE+slot_offset(processing_out)),
  .ready(process_ready),.done(process_done),.error(process_error),.checksum(process_hash),
  .awvalid(wav[2]),.awready(war[2]),.awaddr(waa[56+:28]),.awlen(wal[8+:4]),
  .wdata(wd[256+:128]),.wstrb(ws[32+:16]),.wready(wr[2]),.wlast(wl[2]),
  .arvalid(rav[0]),.arready(rar[0]),.araddr(raa[0+:28]),.arlen(ral[0+:4]),.rdata(rd),.rvalid(rv[0]),.rlast(rl[0]),.tile_perf(tile_perf));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  ps<=P_IDLE;config_wait<=0;pw<=0;ph<=0;lut_width<=0;lut_height<=0;lut_generation<=0;
  processing_generation<=0;lut_valid<=0;processing_raw<=0;processing_out<=0;
 end else if(error_code==0 && !build_error)case(ps)
  P_IDLE:if(raw_count!=0 && out_space)begin
   pw<=raw_width[raw_queue[raw_head]];ph<=raw_height[raw_queue[raw_head]];
   processing_raw<=raw_queue[raw_head];processing_out<=out_slot;config_wait<=0;ps<=P_CONFIG;
  end
  P_CONFIG:begin
   config_wait<=config_wait+1'b1;
   if(config_wait==3)begin
    processing_generation<=active_generation;
    if(!lut_valid || pw!=lut_width || ph!=lut_height || active_generation!=lut_generation)ps<=P_BUILD_START;
    else ps<=P_START;
   end
  end
  P_BUILD_START:if(build_ready)ps<=P_BUILD;
  P_BUILD:if(build_done)begin lut_width<=pw;lut_height<=ph;lut_generation<=processing_generation;lut_valid<=1;ps<=P_START;end
  P_START:if(process_ready)ps<=P_RUN;
  P_RUN:if(process_done)ps<=P_IDLE;
 endcase

 localparam H_IDLE=0,H_START=1,H_READ=2,H_WAIT=3,H_TRAILER=4,H_CHECK=5,H_PLAN=6;
 reg [2:0] hs;reg [1:0] req_sync;reg seen;
 reg [12:0] bytes;wire fetch_ready,fetch_done,fetch_error,fetch_valid,bridge_ready,bridge_start_ready,bridge_done,bridge_error;
 wire [127:0] page_data;
 wire [1:0] head_slot=out_queue[out_head];
 wire [31:0] frame_bytes=out_bytes[head_slot];
 reg append_trailer;reg [12:0] payload_bytes;reg [31:0] end_position;
 wire out_pop=hs==H_WAIT && bridge_done && cursor+bytes==frame_bytes+16;
 wire [127:0] trailer={out_gen[head_slot],out_hash[head_slot],out_id[head_slot],32'h46524d33};
 fetch host_reader(.clk(clk),.rst_n(rst_n),.start(hs==H_START && bridge_start_ready && payload_bytes!=0),.start_ready(fetch_ready),
  .base_addr(OUTPUT_BASE+slot_offset(head_slot)+cursor),.beats({23'd0,payload_bytes[12:4]}),
  .arvalid(rav[1]),.arready(rar[1]),.araddr(raa[28+:28]),.arlen(ral[4+:4]),
  .rdata(rd),.rvalid(rv[1]),.rlast(rl[1]),.out_valid(fetch_valid),.out_ready(bridge_ready && hs==H_READ),
  .out_data(page_data),.out_last(),.done(fetch_done),.error(fetch_error));
 bridge page(.wr_clk(clk),.rd_clk(dma_clk),.rst_n(rst_n),
  .start(hs==H_START && fetch_ready),.start_ready(bridge_start_ready),.bytes(bytes),
  .in_valid((fetch_valid && hs==H_READ) || hs==H_TRAILER),.in_ready(bridge_ready),.in_data(hs==H_TRAILER?trailer:page_data),
  .prepared(prepared),.launch(launch),.rd_req(rd_req),.rd_data(rd_data),.rd_valid(rd_valid),.rd_done(rd_done),
  .wr_done(bridge_done),.error(bridge_error));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin hs<=H_IDLE;req_sync<=0;seen<=0;bytes<=0;cursor<=0;host_error<=0;append_trailer<=0;payload_bytes<=0;end_position<=0;end
 else begin
  req_sync<={req_sync[0],request_toggle};
  if(fetch_error || bridge_error || build_error)host_error<=8'h02;
  case(hs)
   H_IDLE:if(req_sync[1]!=seen && out_count!=0)begin
    seen<=req_sync[1];bytes<=request_bytes;
    if(request_bytes==0 || request_bytes>4096 || request_bytes[3:0]!=0)host_error<=8'h06;
    else hs<=H_CHECK;
   end
   H_CHECK:begin end_position<=cursor+bytes;hs<=H_PLAN;end
   H_PLAN:begin
    append_trailer<=end_position==frame_bytes+16;
    payload_bytes<=end_position==frame_bytes+16?bytes-13'd16:bytes;
    if(end_position>frame_bytes+16)host_error<=8'h06;else hs<=H_START;
   end
   H_START:if(fetch_ready && bridge_start_ready)hs<=payload_bytes==0?H_TRAILER:H_READ;
   H_READ:if(fetch_done)hs<=append_trailer?H_TRAILER:H_WAIT;
   H_TRAILER:if(bridge_ready)hs<=H_WAIT;
   H_WAIT:if(bridge_done)begin cursor<=out_pop?28'd0:cursor+bytes;hs<=H_IDLE;end
  endcase
 end
 wire [319:0] head_record={out_hz[head_slot],drop_count,out_bytes[head_slot],
  23'd0,error_code,(out_count!=0),out_period[head_slot],out_seq[head_slot],out_gen[head_slot],
  out_id[head_slot],out_hash[head_slot],out_height[head_slot],out_width[head_slot]};
 wire header_valid;
 frame_mailbox header_cdc(.src_clk(clk),.dst_clk(dma_clk),.rst_n(rst_n),.src_send(1'b1),
  .src_data(head_record),.dst_valid(header_valid),.dst_data(header));
 assign frame_ready=header[192];
 // Observation only: the monitor has no connection back into any controller.
 generate if(PERF_ENABLE)begin:perf_enabled
  warp_perf #(.LUT_BASE(LUT_BASE)) monitor(.clk(clk),.rst_n(rst_n),
   .active({hs!=H_IDLE,ps==P_RUN,ps==P_BUILD,cs==C_WRITE}),
   .queue_wait({ps==P_IDLE && raw_count==0,ps==P_IDLE && raw_count!=0 && !out_space}),
   .frames({capture_finish && !raw_push,out_pop,out_push,raw_push}),.error_flags(error_code),
   .arvalid(rav),.arready(rar),.rvalid(rv),.rlast(rl),.warp_addr(raa[0+:28]),
   .arlen(ral),.write_beat(wr),.counters(perf_counters));
 end else begin:perf_disabled
  assign perf_counters=1024'd0;
 end endgenerate
 integer k;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  raw_free<=3'b111;out_free<=3'b111;raw_head<=0;raw_tail<=0;raw_count<=0;out_head<=0;out_tail<=0;out_count<=0;
  capture_count<=0;drop_count<=0;publish_count<=0;
  for(k=0;k<3;k=k+1)begin raw_queue[k]<=0;out_queue[k]<=0;raw_width[k]<=0;raw_height[k]<=0;
   out_width[k]<=0;out_height[k]<=0;raw_seq[k]<=0;raw_period[k]<=0;raw_hz[k]<=0;out_seq[k]<=0;out_period[k]<=0;out_hz[k]<=0;
   out_gen[k]<=0;out_hash[k]<=0;out_id[k]<=0;out_bytes[k]<=0;end
 end else begin
  if(capture_allocate)raw_free[raw_slot]<=0;
  if(capture_finish && !raw_push)begin raw_free[capture_slot]<=1;drop_count<=drop_count+1'b1;end
  if(raw_push)begin
   raw_queue[raw_tail]<=capture_slot;raw_tail<=advance(raw_tail);
   raw_width[capture_slot]<=cw;raw_height[capture_slot]<=ch;raw_seq[capture_slot]<=input_sequence;
   raw_period[capture_slot]<=input_period;raw_hz[capture_slot]<=input_pixel_hz;capture_count<=capture_count+1'b1;
  end
  if(raw_pop)begin raw_head<=advance(raw_head);out_free[processing_out]<=0;end
  case({raw_push,raw_pop})2'b10:raw_count<=raw_count+1'b1;2'b01:raw_count<=raw_count-1'b1;endcase
  if(out_push)begin
   raw_free[processing_raw]<=1;out_queue[out_tail]<=processing_out;out_tail<=advance(out_tail);
   out_width[processing_out]<=pw;out_height[processing_out]<=ph;out_bytes[processing_out]<=pw*ph*2;
   out_seq[processing_out]<=raw_seq[processing_raw];out_period[processing_out]<=raw_period[processing_raw];out_hz[processing_out]<=raw_hz[processing_raw];
   out_gen[processing_out]<=processing_generation;out_hash[processing_out]<=process_hash;
   out_id[processing_out]<=publish_count+1'b1;publish_count<=publish_count+1'b1;
  end
  if(out_pop)begin out_free[head_slot]<=1;out_head<=advance(out_head);end
  case({out_push,out_pop})2'b10:out_count<=out_count+1'b1;2'b01:out_count<=out_count-1'b1;endcase
 end
endmodule
