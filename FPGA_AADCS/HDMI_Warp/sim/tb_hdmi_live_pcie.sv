`timescale 1ns/1ps
// Real vendor RX/controller/TX, with only hard PCIe PHY and block RAM replaced.
`ifndef TB_NAME
`define TB_NAME tb_hdmi_pcie
`endif
module tb_hdmi_live_pcie #(parameter PERF_ENABLE=1,OVERLAP_WRITE=1);
reg pix_clk=0,clk=0,dma_clk=0,rst_n=0;
reg [15:0] sensor_w=64,sensor_h=40;reg [31:0] sensor_hz=120000;
reg pv=0,ps=0,ended=0,good=1;reg [23:0] prgb=0;reg [15:0] px=0,py=0;
reg [31:0] sensor_sequence=0;integer sx=0,sy=0;
always @(negedge pix_clk)if(rst_n)begin
 if(sx==sensor_w+15)begin sx=0;if(sy==sensor_h+3)begin sy=0;sensor_sequence=sensor_sequence+1;end else sy=sy+1;end else sx=sx+1;
 pv=sx<sensor_w && sy<sensor_h;ps=pv && sx==0 && sy==0;
 px=sx;py=sy;ended=sx==0 && sy==sensor_h;
 prgb={8'((sx%32)*8),8'((sy%64)*4),8'(((sx+sy)%32)*8)};
end
wire [31:0] good_frames,dropped_frames;always #20 pix_clk=~pix_clk;always #4 clk=~clk;always #5 dma_clk=~dma_clk;
wire av,ar,wr,wl,rv,rr,rl,rvalid;wire [27:0] aa,ra;wire [3:0] al,rlen;
wire [127:0] wd,rd,data,status,host_status;wire [15:0] ws;
wire prepared,launch,req_toggle,ready,busy,frame_ready,dvalid,ddone,read_req,request,tx_busy;
wire [7:0] ec,hc;wire [12:0] bytes;wire [31:0] hash;wire [27:0] cursor;
wire [9:0] length;wire [63:0] address;wire [11:0] status_addr;
reg rxv=0,rxlast=0;reg [127:0] rxdata=0;reg [3:0] rxkeep=0;reg [7:0] rxuser=0;
wire txv,txlast;wire [127:0] txdata;reg txready=0;
wire cv,cl;wire [127:0] cd;
wire control_we,frame_safe,pending;wire [11:0] control_addr;wire [15:0] control_be;
wire [31:0] control_data,generation,published;wire [543:0] defaults,active_config;wire [127:0] warp_status;
hdmi_defaults defaults_inst(defaults);
warp_control control(.host_clk(dma_clk),.frame_clk(clk),.rst_n(rst_n),.wr_en(control_we),
 .wr_addr(control_addr),.wr_data(control_data),.wr_be(control_be),.defaults(defaults),
 .frame_safe(frame_safe),.status_addr(status_addr),.status_data(warp_status),
 .active_config(active_config),.active_generation(generation),.pending(pending));
wire [319:0] header;
hdmi_live #(.WARP_OVERLAP_WRITE(OVERLAP_WRITE),.PERF_ENABLE(PERF_ENABLE),.SLOT_SHIFT(14),.OUTPUT_BASE(28'h10000),.LUT_BASE(28'h20000)) image(
 .pixel_valid(pv),.pixel_sof(ps),.pixel_rgb(prgb),.pixel_x(px),.pixel_y(py),.frame_end(ended),.frame_good(good),
 .runtime_config(active_config),.active_generation(generation),.frame_safe(frame_safe),
 .input_width(sensor_w),.input_height(sensor_h),.input_sequence(sensor_sequence),.input_period(32'd4000),.input_pixel_hz(sensor_hz),
 .pclk(pix_clk),.clk(clk),.dma_clk(dma_clk),.rst_n(rst_n),.init_done(rst_n),.camera_ready(rst_n),
 .good_frames(good_frames),.dropped_frames(dropped_frames),
 .request_toggle(req_toggle),.request_bytes(bytes),.frame_ready(frame_ready),.error_code(ec),.header(header),
 .cursor(cursor),.prepared(prepared),.launch(launch),.rd_req(read_req),
 .rd_data(data),.rd_valid(dvalid),.rd_done(ddone),
 .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
 .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
wire [31:0] completed_pages;wire stream_busy,stream_wr;wire [11:0] stream_addr;wire [31:0] stream_data;
wire [127:0] stream_status;
frame_dma stream(.clk(dma_clk),.rst_n(rst_n),.control_wr(control_we),.control_addr(control_addr),.control_data(control_data),.control_be(control_be),
 .frame_ready(frame_ready),.frame_bytes(header[255:224]+16),.frame_id(header[95:64]),.page_completed(completed_pages),
 .inject(stream_wr),.page_busy(busy),.inject_addr(stream_addr),.inject_data(stream_data),.busy(stream_busy),
 .status_addr(status_addr),.status_data(stream_status));
assign hash=header[63:32];
hostlink #(.WIDTH(64),.HEIGHT(40),.GROUP(0),.VIEW(1),.DYNAMIC_GEOMETRY(1)) host(
 .runtime_width(header[15:0]),.runtime_height(header[31:16]),.runtime_bytes(header[255:224]),.complete_count(completed_pages),
 .clk(dma_clk),.rst_n(rst_n),.frame_ready(frame_ready),.engine_error(ec),.checksum(hash),
 .cursor(cursor),.request(request),.length(length),.address(address),.tx_busy(tx_busy),.prepared(prepared),.rd_done(ddone),
 .ready(ready),.launch(launch),.request_toggle(req_toggle),.bytes(bytes),.busy(busy),
 .status_addr(),.bar_addr(status_addr),.status_data(host_status),.error_code(hc));
// Same CAM2 status layout as hdmi_warp_top; receiver setup is tested separately.
assign status=(status_addr==0)?{host_status[127:96],host_status[95:64]|32'h48,32'h20000,32'h43414d32}:
 (status_addr==2)?{hash,{4'd0,cursor},dropped_frames,good_frames}:
 (status_addr==3)?{{24'd0,ec},32'd0,{24'd0,hc},32'h7200}:
 (status_addr==8 || (status_addr>=16 && status_addr<=20))?warp_status:host_status;
ddrmodel #(.WORDS(16384),.READ_QUEUE(16),.READ_DELAY(40)) mem(.clk(clk),.rst_n(rst_n),
 .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
 .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
ips2l_pcie_dma #(.DEVICE_TYPE(0),.AXIS_SLAVE_NUM(3),.FRAME_STREAM(1)) dma(
 .i_stream_busy(stream_busy),.i_stream_wr_en(stream_wr),.i_stream_wr_addr(stream_addr),.i_stream_wr_data(stream_data),
 .clk(dma_clk),.rst_n(rst_n),.i_cfg_pbus_num(8'd33),.i_cfg_pbus_dev_num(5'd0),
 .i_cfg_max_rd_req_size(3'd0),.i_cfg_max_payload_size(3'd0),
 .i_axis_master_tvld(rxv),.o_axis_master_trdy(),.i_axis_master_tdata(rxdata),
 .i_axis_master_tkeep(rxkeep),.i_axis_master_tlast(rxlast),.i_axis_master_tuser(rxuser),
 .i_axis_slave0_trdy(1'b1),.o_axis_slave0_tvld(cv),.o_axis_slave0_tdata(cd),.o_axis_slave0_tlast(cl),
 .i_axis_slave1_trdy(1'b1),.i_axis_slave2_trdy(txready),.o_axis_slave2_tvld(txv),
 .o_axis_slave2_tdata(txdata),.o_axis_slave2_tlast(txlast),
 .i_cfg_ido_req_en(1'b0),.i_cfg_ido_cpl_en(1'b0),
 .i_xadm_ph_cdts(8'd0),.i_xadm_pd_cdts(12'd0),.i_xadm_nph_cdts(8'd0),.i_xadm_npd_cdts(12'd0),
 .i_xadm_cplh_cdts(8'd0),.i_xadm_cpld_cdts(12'd0),
 .i_apb_psel(1'b0),.i_apb_paddr(9'd0),.i_apb_pwdata(32'd0),.i_apb_pstrb(4'd0),
 .i_apb_pwrite(1'b0),.i_apb_penable(1'b0),
 .o_dma_write_data_req(read_req),.i_dma_write_data(data),
 .i_video_ready(ready),.i_video_busy(busy),.o_video_request(request),
 .o_video_length(length),.o_video_address(address),.o_video_tx_busy(tx_busy),
 .o_video_status_addr(status_addr),.i_video_status_data(status),
 .o_control_wr_en(control_we),.o_control_wr_addr(control_addr),.o_control_wr_data(control_data),.o_control_wr_be(control_be));
function [31:0] swap32(input [31:0] a);swap32={a[7:0],a[15:8],a[23:16],a[31:24]};endfunction
task write32(input [31:0] addr,input [31:0] value);
begin
 @(negedge dma_clk);rxv=1;rxdata={32'd0,addr,32'h0000000f,32'h40000001};rxkeep=15;rxlast=0;rxuser=8'h10;
 @(negedge dma_clk);rxdata={96'd0,swap32(value)};rxkeep=1;rxlast=1;
 @(negedge dma_clk);rxv=0;rxlast=0;repeat(10)@(negedge dma_clk);
end endtask
reg [15:0] golden[0:2559],golden_large[0:4223],golden_changed[0:4223];
integer pixels=0,packets=0,n=0,j,pos=0,phase=0,w,h,total,frames=0;
reg payload=0;reg [31:0] value,frame_id,hash_value,expected_generation;reg changed=0;reg [127:0] held;reg holding=0;
function [15:0] expected(input integer index);
 begin expected=w==64?golden[index]:expected_generation==0?golden_large[index]:golden_changed[index];end
endfunction
always @(negedge dma_clk)begin n=n+1;txready=(n%7!=0 && n%7!=1 && n%29<23);end
always @(posedge dma_clk)if(rst_n)begin
 if(ec || hc)$fatal(1,"live error ec=%h hc=%h C=%d P=%d H=%d",ec,hc,image.cs,image.ps,image.hs);
 if(holding && (!txv || txdata!==held))$fatal(1,"TX changed while stalled");
 holding=txv && !txready;held=txdata;
 if(txv && txready)begin
  if(!payload)begin
   if(txlast || txdata[31:24]!=8'h40 || txdata[9:0]>32)$fatal(1,"MWr header %h",txdata);
   payload=1;packets=packets+1;
  end else begin
   for(j=0;j<4;j=j+1)begin
    value=swap32(txdata[j*32+:32]);
    if(pos<total)begin
     if(value[15:0]!==expected(pos/2) || value[31:16]!==expected(pos/2+1))
      $fatal(1,"live pixel %d got=%h expected=%h/%h",pos/2,value,expected(pos/2),expected(pos/2+1));
     pixels=pixels+2;
    end else case(pos-total)
     0:if(value!==32'h46524d33)$fatal(1,"footer magic %h",value);
     4:if(value!==frame_id)$fatal(1,"footer frame ID");
     8:if(value!==hash_value)$fatal(1,"footer hash");
     12:if(value!==expected_generation)$fatal(1,"footer generation");
     default:$fatal(1,"too much payload");
    endcase
    pos=pos+4;
   end
   if(txlast)payload=0;
  end
 end
end
integer token=0;
initial begin
 $readmemh("build/sim/native_golden.hex",golden);
 $readmemh("build/sim/live_large_golden.hex",golden_large);
 $readmemh("build/sim/live_large_changed.hex",golden_changed);
 #100;rst_n=1;
 // Hold the first frame while the two other output slots fill.
 wait(frame_ready);frame_id=header[95:64];hash_value=hash;
 repeat(25000)@(negedge dma_clk);
 if(header[95:64]!==frame_id || hash!==hash_value)$fatal(1,"queue head changed while ARM idle");
 while(frames<20)begin
  wait(frame_ready && (frames==0 || header[95:64]!=frame_id));
  repeat(20)@(negedge dma_clk);
  w=header[15:0];h=header[31:16];total=w*h*2;frame_id=header[95:64];hash_value=hash;expected_generation=header[127:96];pos=0;
  if(header[319:288] !== (w==64?32'd120000:32'd100000))$fatal(1,"queued frame frequency changed with source %0d",w);
  token=token+1;
  write32('h280,32'h100ff0);write32('h284,32'd20000);write32('h288,token);
  wait(stream.completed==token);repeat(30)@(negedge dma_clk);
  if(pos!=total+16 || cursor!=0 || stream.error)$fatal(1,"whole-frame completion mismatch %0d/%0d cursor%h",pos,total,cursor);
  frames=frames+1;$display("PASS live frame %0d geometry %0dx%0d",frames,w,h);$fflush();
  if(w==96 && expected_generation==1)begin
   if(mem.queued.max_pending<4)$fatal(1,"no queued read stress");
   $display("PASS HDMI live three-frame ownership, whole-frame DMA, unaligned destination page split, footer, random PCIe/DDR stalls, automatic 64x40 -> 96x44 partial-tile mode switch, atomic parameter commit/LUT rebuild, %0d exact pixels",pixels);$finish;
  end
  if(w==96 && !changed)begin
   write32('h208,defaults[95:64]+32'd196608);write32('h250,1);changed=1;
  end
  if(frames==1)begin
   wait(sx==sensor_w+15 && sy==sensor_h+3);@(posedge pix_clk);sensor_w=96;sensor_h=44;sensor_hz=100000;
  end
 end
 $fatal(1,"new mode never reached output");
end
initial begin #100000000;$fatal(1,"timeout C=%d P=%d H=%d D=%d raw=%d out=%d req=%b/%b",image.cs,image.ps,image.hs,stream.state,image.raw_count,image.out_count,req_toggle,image.seen);end
endmodule


