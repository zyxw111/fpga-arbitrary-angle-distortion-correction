`timescale 1ns/1ps
module tb_video_ddr_weight;
 parameter WEIGHT=2,IMMEDIATE=0;
 reg clk=0,rst_n=0;always #4 clk=~clk;
 reg [1:0] rav=0;wire [1:0] rar,rv,rl;
 wire av,ar,mv,ml;wire [27:0] aa;wire [3:0] al;wire [127:0] md,rd;
 integer issued[0:1],got=0,cycle=0,head=0,tail=0,index=0,pending=0,peak=0;
 integer owners[0:4095],bases[0:4095],lens[0:4095],j,owner;
 wire [27:0] a0=28'h1000+issued[0]*128,a1=28'h30000+issued[1]*256;
 video_ddr_arb #(.WRITERS(1),.READERS(2),.READ0_WEIGHT(WEIGHT)) dut(
  .clk(clk),.rst_n(rst_n),.wav(1'b0),.waa(28'd0),.wal(4'd0),.wd(128'd0),.ws(16'd0),
  .awready(1'b0),.wready(1'b0),.wlast(1'b0),
  .rav(rav),.rar(rar),.raa({a1,a0}),.ral({4'd15,4'd3}),.rv(rv),.rl(rl),.rd(rd),
  .arvalid(av),.arready(ar),.araddr(aa),.arlen(al),.rdata(md),.rvalid(mv),.rlast(ml));
 ddrmodel #(.WORDS(32768),.FORMULA(1),.READ_QUEUE(IMMEDIATE?1:16),.READ_DELAY(IMMEDIATE?0:60)) mem(
  .clk(clk),.rst_n(rst_n),.awvalid(1'b0),.awaddr(28'd0),.awlen(4'd0),.wdata(128'd0),.wstrb(16'd0),
  .arvalid(av),.arready(ar),.araddr(aa),.arlen(al),.rdata(md),.rvalid(mv),.rlast(ml));
 function [127:0] pattern(input integer n);
  pattern={32'h12340000 ^ n,32'h56780000 ^ n,32'habcd0000 ^ n,32'hfedc0000 ^ n};
 endfunction
 reg [27:0] held_addr;reg [3:0] held_len;reg held=0;
 always @(negedge clk)if(rst_n)begin
  // Both permanently pending for the first 120 commands; then each reader
  // periodically disappears. Bound/fairness is checked in the stable phase.
  rav=tail<120?2'b11:tail<800?{cycle%43<31,cycle%29<19}:2'b00;
 end
 always @(posedge clk)if(rst_n)begin
  cycle=cycle+1;if(cycle>40000)$fatal(1,"weighted arb timeout");
  if(held && (!av || aa!==held_addr || al!==held_len))$fatal(1,"AR changed under backpressure");
  held=av && !ar;held_addr=aa;held_len=al;
  if(av && ar)begin
   owner=rar[1]?1:0;
   if(rar!==(owner?2'b10:2'b01))$fatal(1,"AR ownership");
   if(tail<120 && owner!==(tail%(WEIGHT+1)==WEIGHT?1:0))$fatal(1,"weight/fairness at %0d",tail);
   owners[tail]=owner;bases[tail]=aa/16;lens[tail]=al+1;tail=tail+1;
   issued[owner]=issued[owner]+1;pending=pending+1;if(pending>peak)peak=pending;
  end
  if(mv)begin
   if(pending==0 || rv!==(owners[head]?2'b10:2'b01) || rl!==(ml?(owners[head]?2'b10:2'b01):2'b00))$fatal(1,"return tag routing");
   if(rd!==pattern(bases[head]+index) || ml!==(index==lens[head]-1))$fatal(1,"return data/order/last");
   index=index+1;got=got+1;
   if(ml)begin index=0;head=head+1;pending=pending-1;end
  end
  if(tail>=800 && pending==0)begin
   if(issued[0]<200 || issued[1]<100 || (!IMMEDIATE && peak<8))$fatal(1,"coverage");
   $display("PASS weighted DDR reads weight=%0d immediate=%0d commands=%0d/%0d peak=%0d: bounded fairness, absent readers, AR stall, ordered returns",WEIGHT,IMMEDIATE,issued[0],issued[1],peak);$finish;
  end
 end
 initial begin issued[0]=0;issued[1]=0;repeat(5)@(negedge clk);rst_n=1;end
endmodule
