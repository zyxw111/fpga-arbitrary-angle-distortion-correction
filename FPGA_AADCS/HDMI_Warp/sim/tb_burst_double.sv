`timescale 1ns/1ps
module tb_burst_double #(parameter BANKS=2);
 reg clk=0,rst_n=0,start=0,sending=0,reject_mode=0;always #4 clk=~clk;
 reg [27:0] base=0;reg [31:0] beats=0;integer provided=0,committed=0,cycle=0,peak=0,overlap=0,immediate=0,seed=0;
 wire ready,ir,av,ar,wr,wl,done,error;wire [27:0] addr;wire [3:0] len;wire [127:0] wd;wire [15:0] strb;
 wire iv=sending && provided<beats && cycle%11!=0;
 function [127:0] pattern(input integer n,input integer s);
  pattern={32'h12345678^(n+s),32'h87654321^(n+32'd2*s),32'h00ff00ff^(n+32'd3*s),32'hff00ff00^(n+32'd4*s)};
 endfunction
 burst #(.BUFFER_BANKS(BANKS)) dut(.clk(clk),.rst_n(rst_n),.start(start),.start_ready(ready),
  .base_addr(base),.beats(beats),.in_valid(iv),.in_ready(ir),.in_data(pattern(provided,seed)),
  .awvalid(av),.awready(ar),.awaddr(addr),.awlen(len),.wdata(wd),.wstrb(strb),.wready(wr),.wlast(wl),.done(done),.error(error));
 ddrmodel #(.WORDS(8192),.WRITE_STALL_CYCLES(300),.WRITE_RUN_CYCLES(96)) mem(
  .clk(clk),.rst_n(rst_n),.awvalid(av),.awready(ar),.awaddr(addr),.awlen(len),
  .wdata(wd),.wstrb(strb),.wready(wr),.wlast(wl),
  .arvalid(1'b0),.araddr(28'd0),.arlen(4'd0),.arready(),.rvalid(),.rlast(),.rdata());
 always @(posedge clk)if(rst_n)begin
  cycle<=cycle+1;
  if(cycle>30000)$fatal(1,"burst timeout");
  if(error && !reject_mode)$fatal(1,"unexpected writer error");
  if(iv && ir)provided<=provided+1;
  if(wr)begin
   committed<=committed+1;
   if(wd!==pattern(committed,seed) || strb!==16'hffff)$fatal(1,"native data/strb mismatch");
   if(iv && ir)overlap<=overlap+1;
  end
  if(av && ar && wr)immediate<=immediate+1;
  if(provided-committed>peak)peak<=provided-committed;
  if(provided-committed>BANKS*16)$fatal(1,"buffer ownership overflow");
  if(done && (provided!=beats || committed!=beats))$fatal(1,"early publication");
 end
 task job(input [27:0] address,input integer count);
 integer i;begin
  wait(ready);@(negedge clk);base=address;beats=count;provided=0;committed=0;seed=seed+17;start=1;sending=1;
  @(negedge clk);start=0;wait(done);@(negedge clk);sending=0;
  for(i=0;i<count;i=i+1)if(mem.memory[address/16+i]!==pattern(i,seed))$fatal(1,"stored word mismatch");
 end endtask
 task reject(input [27:0] address,input [31:0] count);
 begin
  @(negedge clk);rst_n=0;start=0;sending=0;repeat(3)@(negedge clk);rst_n=1;
  @(negedge clk);base=address;beats=count;start=1;@(negedge clk);start=0;
  repeat(10)begin if(!error || ready || av || ir || done)$fatal(1,"invalid command escaped");@(negedge clk);end
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  job(28'hff00,256);job(28'd0,16);job(28'h100,80);
  if(immediate==0)$fatal(1,"first-W-with-AW not exercised");
  if(BANKS==2 && (peak<32 || overlap==0))$fatal(1,"double buffering not exercised");
  reject_mode=1;reject(28'd16,16);reject(28'd0,0);reject(28'd0,17);reject(28'hfffff00,32);
  $display("PASS capture writer banks=%0d: exact data, first-W-with-AW=%0d, fill/write overlap=%0d, peak=%0d, backpressure, boundaries, reject",BANKS,immediate,overlap,peak);
  $finish;
 end
endmodule
