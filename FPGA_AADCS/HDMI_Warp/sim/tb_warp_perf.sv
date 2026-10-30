`timescale 1ns/1ps
module tb_warp_perf;
 reg clk=0,hclk=0,rst_n=0,host_run=1;always #5 clk=~clk;always #7 if(host_run)hclk=~hclk;
 reg [3:0] active=0,frames=0;reg [1:0] queue_wait=0,av=0,ar=0,rv=0,rl=0;
 reg [27:0] addr=0;reg [7:0] len=0,err=0;reg [2:0] wb=0;
 wire [1023:0] counts;
 warp_perf dut(.clk(clk),.rst_n(rst_n),.active(active),.queue_wait(queue_wait),.frames(frames),
  .error_flags(err),.arvalid(av),.arready(ar),.rvalid(rv),.rlast(rl),.warp_addr(addr),
  .arlen(len),.write_beat(wb),.counters(counts));
 reg [11:0] status_addr=0;wire [127:0] status;
 reg dma_busy=0;reg [31:0] pages=7;
 warp_perf_regs #(.SNAPSHOT_BITS(6)) regs(.dclk(clk),.hclk(hclk),.rst_n(rst_n),.counters(counts),
  .capture_counters({32'd11,32'd10,32'd9,32'd8,32'd7,32'd6,32'd5,32'd4,32'd3,32'd2,32'd1,32'h52584431}),
  .tile_counters({32'd6,32'd5,32'd4,32'd3,32'd2,32'd1,32'h201,32'h54494c31}),
  .dma_busy(dma_busy),.frame_ready(1'b1),.source_read(1'b0),.txvalid(1'b0),.txready(1'b1),
  .page_completed(pages),.status_addr(status_addr),.status_data(status));
 task tick(input [1:0] xpush,xvalid,xlast,input [27:0] address,input [7:0] length);
 begin @(negedge clk);av=xpush;ar=xpush;rv=xvalid;rl=xlast;addr=address;len=length;
  @(posedge clk);#1;end endtask
 task check(input integer word,input [31:0] expected);
 begin if(counts[word*32+:32]!==expected)$fatal(1,"counter %0d got %0d expected %0d",word,counts[word*32+:32],expected);end endtask
 integer i,j;reg [31:0] seq;reg [1695:0] held_snapshot;
 initial begin
  #21;rst_n=1;
  for(i=0;i<16;i=i+1)tick(1,0,0,i<8?28'h2000000:28'h1000,8'h03);
  repeat(5)tick(0,0,0,0,0);
  for(i=0;i<16;i=i+1)for(j=0;j<4;j=j+1)tick(0,1,j==3?1:0,0,0);
  tick(2,0,0,0,8'h10);tick(0,2,0,0,0);tick(0,2,2,0,0);
  // A complete one-beat response in the AR acceptance cycle.
  tick(2,2,2,0,0);
  tick(0,0,0,0,0);tick(0,0,0,0,0);
  check(6,32);check(7,32);check(8,3);
  check(12,8);check(13,8);check(14,2);
  check(15,32);check(16,32);check(17,3);
  check(22,16);check(23,1);check(24,16);check(31,0);
  @(negedge clk);active=4'b0100;wb=7;
  repeat(3)@(negedge clk);
  frames=7;
  @(negedge clk);active=0;frames=0;wb=0;
  repeat(3)@(negedge clk);
  check(9,4);check(10,4);check(11,4);check(25,1);check(26,1);check(27,1);check(28,4);
  @(negedge hclk);dma_busy=1;
  repeat(8)@(negedge hclk);
  dma_busy=0;
  // Freeze event inputs; a held cross-domain snapshot must contain the same bundle.
  repeat(150)@(posedge hclk);
  status_addr=32;#1;
  if(status[31:0]!==32'h50524630 || status[63:32]!==1 || status[95:64]==0 || status[127:96]!==131250000)
   $fatal(1,"snapshot header %h",status);
  seq=status[95:64];status_addr=34;#1;
  if(status[95:64]!==32 || status[127:96]!==32)$fatal(1,"CDC map/source counts %h",status);
  status_addr=42;#1;if(status[95:64]!==7)$fatal(1,"host snapshot page counter %h",status);
  status_addr=41;#1;
  if(status[63:32]!==8 || status[95:64]!==1 || status[127:96]!==8)
   $fatal(1,"DMA busy, completion, duration counters %h",status);
  status_addr=43;#1;
  if(status!=={32'd2,32'd1,32'h201,32'h54494c31})$fatal(1,"tile snapshot bank0 %h",status);
  status_addr=44;#1;
  if(status!=={32'd6,32'd5,32'd4,32'd3})$fatal(1,"tile snapshot bank1 %h",status);
  status_addr=45;#1;if(status!=={32'd3,32'd2,32'd1,32'h52584431})$fatal(1,"capture diagnostics bank0 %h",status);
  status_addr=47;#1;if(status!=={32'd11,32'd10,32'd9,32'd8})$fatal(1,"capture diagnostics bank2 %h",status);
  status_addr=0;#1;if(status!==0)$fatal(1,"legacy bank changed");
  // A paused host must not allow the source to overwrite an unacknowledged
  // bundle, even though the periodic snapshot timer keeps expiring.
  @(negedge hclk);host_run=0;
  wait(regs.request!=regs.ack_sync[1]);#1;held_snapshot=regs.held;
  repeat(200)@(posedge clk);#1;
  if(regs.held!==held_snapshot)$fatal(1,"CDC source overwritten while host paused");
  host_run=1;repeat(150)@(posedge hclk);
  status_addr=32;#1;
  if(status[31:0]!==32'h50524630 || status[95:64]<=seq)$fatal(1,"CDC did not recover after host pause");
  tick(0,1,1,0,0);tick(0,0,0,0,0);tick(0,0,0,0,0);
  if(!counts[31*32+8])$fatal(1,"unexpected response not reported");
  @(negedge clk);rst_n=0;#1;check(0,0);check(31,0);
  $display("PASS passive warp counters: 16 in flight, ordered map/source returns, immediate RLAST, frame cycles, coherent CDC, legacy banks, reset");$finish;
 end
 initial begin #50000;$fatal(1,"timeout");end
endmodule
