`timescale 1ns/1ps
module tb_pipeline #(parameter ASYNC_DMA=0,parameter SOURCE=0,parameter DEMO_GROUP=0,parameter DEMO_VIEW=1);
reg clk=0;always #5 clk=~clk;
reg raw_dma_clk=0;always #7 raw_dma_clk=~raw_dma_clk;
wire dma_clk=ASYNC_DMA ? raw_dma_clk : clk;
reg pix_clk=0;always #6 pix_clk=~pix_clk;
reg source_enable=1;
wire source_valid,source_sof,source_eof,source_overflow;
wire [127:0] source_data;wire [31:0] source_id;
reg rst_n=0,in_valid=0,in_sof=0,in_eof=0,abort=0;
reg [127:0] in_data=0;reg [31:0] in_id=0;
reg frame_begin=0,segment_start=0,dma_launch=0,dma_read=0;
reg [12:0] segment_bytes=0;
wire in_ready,awvalid,awready,wready,wlast,fence_req,fence_ack,arvalid,arready,rvalid,rlast;
wire frame_valid,segment_ready,dma_prepared,dma_valid,dma_done,segment_done,frame_done,error;
wire [27:0] awaddr,araddr;wire [3:0] awlen,arlen;
wire [127:0] wdata,rdata,dma_data;wire [15:0] wstrb;
wire [31:0] frame_id,good_frames,dropped_frames;
reg [3:0] fence_count=0;
assign fence_ack=fence_req && fence_count==5;
always @(posedge clk)if(!rst_n || !fence_req)fence_count<=0;
 else if(fence_count<5)fence_count<=fence_count+1'b1;
generate if(SOURCE)begin:source_test
 stream #(.DEMO_GROUP(DEMO_GROUP),.DEMO_VIEW(DEMO_VIEW),.WIDTH(64),.HEIGHT(4),.H_TOTAL(80),.V_TOTAL(8),.FIFO_ADDR_BITS(5)) input_stream(
 .pix_clk(pix_clk),.tx_clk(clk),.rst_n(rst_n),.enable(source_enable),
 .tx_valid(source_valid),.tx_ready(in_ready),.tx_data(source_data),
 .tx_sof(source_sof),.tx_eof(source_eof),.tx_frame_id(source_id),.overflow(source_overflow));
end else begin
 assign source_valid=0;assign source_data=0;assign source_sof=0;assign source_eof=0;
 assign source_id=0;assign source_overflow=0;
end endgenerate
// Test-only stopping control; no control signal is crossed directly in RTL.
always @(posedge clk)if(SOURCE && source_valid && in_ready && source_eof && source_id==2)
 source_enable<=0;
video #(.FRAME_BEATS(32),.BASE1(28'h1000)) dut(
 .in_valid(SOURCE?source_valid:in_valid),.in_data(SOURCE?source_data:in_data),
 .in_sof(SOURCE?source_sof:in_sof),.in_eof(SOURCE?source_eof:in_eof),
 .in_id(SOURCE?source_id:in_id),.*);
ddrmodel mem(.clk(clk),.rst_n(rst_n),.awvalid(awvalid),.awready(awready),
 .awaddr(awaddr),.awlen(awlen),.wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
 .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
 .rvalid(rvalid),.rlast(rlast),.rdata(rdata));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task dtick;begin @(posedge dma_clk);#1;@(negedge dma_clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
reg [15:0] demo_golden[0:255];
generate if(DEMO_GROUP)begin
 if(DEMO_VIEW==0)initial $readmemh("sim/demo_vectors/raw_64x4.hex",demo_golden);
 else initial $readmemh("sim/demo_vectors/corrected_64x4.hex",demo_golden);
end endgenerate
function [127:0] pattern(input integer id,input integer n);
integer lane;
begin
 if(SOURCE && DEMO_GROUP)begin
  for(lane=0;lane<8;lane=lane+1)pattern[lane*16+:16]=demo_golden[n*8+lane];
 end else if(SOURCE)case(n%8)
 0:pattern={8{16'hffff}};1:pattern={8{16'hffe0}};2:pattern={8{16'h07ff}};3:pattern={8{16'h07e0}};
 4:pattern={8{16'hf81f}};5:pattern={8{16'hf800}};6:pattern={8{16'h001f}};7:pattern={8{16'h0000}};
 endcase
 else pattern={32'h01000000 ^ id,32'h02000000 ^ n,32'h03000000 ^ id,32'h04000000 ^ n};
end endfunction
task produce(input integer id);integer i;begin
 for(i=0;i<32;i=i+1)begin
  in_valid=1;in_sof=i==0;in_eof=i==31;in_id=id;in_data=pattern(id,i);
  while(!in_ready)tick;tick;
 end
 in_valid=0;in_sof=0;in_eof=0;
end endtask
integer received=0;
task descriptor(input integer id,input integer bytes);integer i;begin
 while(!segment_ready)tick;
 segment_bytes=bytes;segment_start=1;tick;segment_start=0;
 while(!dma_prepared)begin check(!dma_valid,"no data before prefetch");tick;end
 repeat(5)begin tick;check(dma_prepared,"prepared waits for DMA launch");end
 @(negedge dma_clk);dma_launch=1;dma_read=1;dtick;dma_launch=0;
 check(dma_valid && dma_data===pattern(id,received),"first descriptor payload");received=received+1;
 for(i=1;i<bytes/16;i=i+1)begin
  dma_read=0;repeat(i%3+1)dtick;
  dma_read=1;dtick;
  check(dma_valid && dma_data===pattern(id,received),"continuous source across descriptors");
  check(dma_done==(i==bytes/16-1),"descriptor completion");received=received+1;
 end
 check(dma_done,"last source response");dma_read=0;
 while(!segment_done)tick;tick;
end endtask
task consume(input integer id);begin
 while(!frame_valid)tick;check(frame_id==id,"FIFO frame id");
 frame_begin=1;tick;frame_begin=0;received=0;
 descriptor(id,16);descriptor(id,240);descriptor(id,256);
 check(frame_done && received==32,"whole source frame completion");tick;
end endtask
initial begin
tick;rst_n=1;tick;
if(SOURCE)begin
 consume(0);consume(1);consume(2);
 check(good_frames==3 && dropped_frames==0 && !source_overflow && !error,"internal source end-to-end");
 $display("PASS source: pat -> pack -> async FIFO -> owned DDR -> prefetch -> async descriptor -> DMA; three clocks, 3 checked frames");
 $finish;
end
produce(1);while(good_frames<1)tick;
produce(2);while(good_frames<2)tick;
// Send/receive on different slots at the same time after freeing the first.
consume(1);
fork produce(3);consume(2);join
while(good_frames<3)tick;consume(3);
check(!error && dropped_frames==0,"pipeline state");
produce(4);while(!frame_valid)tick;frame_begin=1;tick;frame_begin=0;
segment_bytes=528;segment_start=1;tick;segment_start=0;
check(error && !arvalid,"descriptor must not read beyond frame");
rst_n=0;tick;rst_n=1;tick;
check(!error && !frame_valid && !dma_valid,"coordinated reset");
$display("PASS pipeline async=%0d: framed writes -> fenced DDR -> prefetch -> synchronous DMA; 3 frames, concurrent slots, segmentation, bounds/reset",ASYNC_DMA);$finish;
end
initial begin #1000000;$fatal(1,"pipeline timeout");end
endmodule
