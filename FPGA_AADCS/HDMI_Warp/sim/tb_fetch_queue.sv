`timescale 1ns/1ps
module tb_fetch_queue;
 parameter IMMEDIATE=0;
 reg clk=0,rst_n=0,start=0,consumer=0;always #4 clk=~clk;
 reg [27:0] base=0;reg [31:0] beats=0;
 wire ready,av,ar,rv,rl,ov,ol,done,error;wire [27:0] aa;wire [3:0] al;
 wire [127:0] rd,od;
 fetch #(.OUTSTANDING(8)) dut(.clk(clk),.rst_n(rst_n),.start(start),.start_ready(ready),
  .base_addr(base),.beats(beats),.arvalid(av),.arready(ar),.araddr(aa),.arlen(al),
  .rvalid(rv),.rlast(rl),.rdata(rd),.out_valid(ov),.out_ready(consumer),.out_data(od),.out_last(ol),.done(done),.error(error));
 ddrmodel #(.WORDS(8192),.FORMULA(1),.READ_QUEUE(IMMEDIATE?1:16),.READ_DELAY(IMMEDIATE?0:80)) mem(
  .clk(clk),.rst_n(rst_n),.awvalid(1'b0),.awaddr(28'd0),.awlen(4'd0),.wdata(128'd0),.wstrb(16'd0),
  .arvalid(av),.arready(ar),.araddr(aa),.arlen(al),.rvalid(rv),.rlast(rl),.rdata(rd));
 integer cycle=0,received=0,expected=0,peak=0,j;reg [31:0] random_state=32'h1234abcd;
 function [127:0] pattern(input integer n);
  pattern={32'h12340000 ^ n,32'h56780000 ^ n,32'habcd0000 ^ n,32'hfedc0000 ^ n};
 endfunction
 always @(negedge clk)begin
  random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
  // Force an entire return reservation to fill before draining, then repeat
  // long stalls while pointers and the burst-tag FIFO wrap several times.
  consumer=cycle>500 && cycle%271>115 && random_state[0];
 end
 always @(posedge clk)if(rst_n)begin
  cycle<=cycle+1;
  if(cycle>40000)$fatal(1,"queued fetch timeout");
  if(error)$fatal(1,"fetch error");
  if(dut.queued.reader.pending>peak)peak<=dut.queued.reader.pending;
  if(dut.queued.reader.reserved>128 || dut.queued.reader.filled>dut.queued.reader.reserved)$fatal(1,"return reservation overflow");
  if(ov && consumer)begin
   if(od!==pattern(base/16+received))$fatal(1,"pixel word %0d got=%h",received,od);
   if(ol!==(received==expected-1))$fatal(1,"out_last mismatch");
   received<=received+1;
  end
  if(done && received!=expected)$fatal(1,"early done %0d/%0d",received,expected);
 end
 task job(input integer address,input integer n);
 begin
  wait(ready);@(negedge clk);base=address;beats=n;received=0;expected=n;start=1;
  @(negedge clk);start=0;wait(done);@(negedge clk);
  if(received!=n)$fatal(1,"missing data");
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst_n=1;
  job('hff0,513);job('h2010,1);job('h2ff0,17);job(0,256);job(32,15);
  if(!IMMEDIATE && peak<8)$fatal(1,"did not exercise 8 outstanding: %0d",peak);
  $display("PASS queued fetch immediate=%0d peak=%0d: stalled full reservation, 4KiB split, wrap and consecutive jobs",IMMEDIATE,peak);
  $finish;
 end
endmodule
