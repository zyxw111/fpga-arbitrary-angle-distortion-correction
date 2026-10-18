`timescale 1ns/1ps
// Replay the REAL ARM src/fpga_capture.c row/page splitting algorithm at 1080p.
module tb_replay;
reg clk=0;always #4 clk=~clk;
wire dma_clk=clk;
reg rst_n=0,in_valid=0,in_sof=0,in_eof=0,abort=0;
reg [127:0] in_data=0;reg [31:0] in_id=42;
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
video dut(.*);
ddrmodel #(.WORDS(524288)) mem(.clk(clk),.rst_n(rst_n),
 .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
 .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
 .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
 .rvalid(rvalid),.rlast(rlast),.rdata(rdata));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
function [127:0] pattern(input integer n);
pattern={32'h0000002a,32'h9e370000 ^ n,32'hdada0000 ^ n,32'hface0000 ^ n};endfunction
integer sent,got=0,descriptors=0,addr,left,chunk,i,y,commands=0;
reg [27:0] next_write=0;
always @(posedge clk) if(rst_n && awvalid && awready)begin
 check(awaddr==next_write && awlen==15,"full frame write address");
 next_write=next_write+256;commands=commands+1;
end
initial begin
tick;rst_n=1;tick;
for(sent=0;sent<259200;sent=sent+1)begin
 in_valid=1;in_sof=sent==0;in_eof=sent==259199;in_data=pattern(sent);
 while(!in_ready)tick;tick;
end
in_valid=0;in_sof=0;in_eof=0;
while(!frame_valid)tick;
check(frame_id==42 && good_frames==1 && commands==16200,"published full 1080p frame");
frame_begin=1;tick;frame_begin=0;
for(y=0;y<1080;y=y+1)begin
 addr=32'h10000000+y*3840;left=3840;
 while(left!=0)begin
  chunk=4096-(addr%4096);if(chunk>left)chunk=left;
  while(!segment_ready)tick;
  segment_bytes=chunk;segment_start=1;tick;segment_start=0;
  while(!dma_prepared)tick;
  dma_launch=1;tick;dma_launch=0;
  for(i=0;i<chunk/16;i=i+1)begin
   // Pause the source consumer within and between real ARM descriptors.
   if((i+descriptors)%29==0)begin dma_read=0;tick;end
   dma_read=1;tick;
   check(dma_valid && dma_data===pattern(got),"1080p payload/coverage/order");
   check(dma_done==(i==chunk/16-1),"segment source response count");got=got+1;
  end
  dma_read=0;while(!segment_done)tick;tick;
  addr=addr+chunk;left=left-chunk;descriptors=descriptors+1;
 end
end
check(got==259200 && descriptors==2025 && frame_done && !error && dropped_frames==0,
      "1080p final counters and ownership release");
tick;check(!frame_valid && !dma_prepared,"no stale frame/descriptor");
$display("PASS replay: 1920x1080 RGB565, 4147200 bytes, 16200 DDR writes, 2025 real-ARM descriptors, 259200 ordered DMA beats");$finish;
end
initial begin #30000000;$fatal(1,"replay timeout sent=%0d got=%0d",sent,got);end
endmodule
