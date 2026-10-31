`timescale 1ns/1ps
// Rejected start commands must never issue DDR reads or expose frame data,
// even though the queued reader now loads its private counters unconditionally.
module tb_fetch_reject;
 reg clk=0,rst_n=0,start=0;always #4 clk=~clk;
 reg [27:0] base=0;reg [31:0] beats=0;
 wire ready,av,ov,done,error;wire [27:0] addr;
 fetch #(.OUTSTANDING(8)) dut(.clk(clk),.rst_n(rst_n),.start(start),.start_ready(ready),
  .base_addr(base),.beats(beats),.arvalid(av),.arready(1'b1),.araddr(addr),.arlen(),
  .rvalid(1'b0),.rlast(1'b0),.rdata(128'd0),.out_valid(ov),.out_ready(1'b1),
  .out_data(),.out_last(),.done(done),.error(error));
 always @(posedge clk)if(rst_n && error && (av || ov || done || ready))
  $fatal(1,"rejected command escaped the error gate");
 task reset;
 begin
  @(negedge clk);rst_n=0;start=0;repeat(3)@(negedge clk);rst_n=1;
  @(negedge clk);if(!ready || error)$fatal(1,"reset did not recover");
 end endtask
 task reject(input [27:0] address,input [31:0] count);
 begin
  reset();base=address;beats=count;start=1;@(negedge clk);start=0;
  if(!error || av || ov || done || ready)$fatal(1,"illegal command accepted %h/%h",address,count);
  repeat(10)@(negedge clk);
  base=0;beats=1;start=1;@(negedge clk);start=0;
  repeat(10)@(negedge clk);if(!error)$fatal(1,"error was not sticky");
 end endtask
 initial begin
  reject(28'd1,32'd1);reject(28'd0,32'd0);
  reject(28'hffffff0,32'd2);reject(28'd0,32'h10000001);
  // A final 16-byte word ending exactly at 256MiB remains legal.
  reset();base=28'hffffff0;beats=1;start=1;@(negedge clk);start=0;
  if(error || !av || addr!==28'hffffff0)$fatal(1,"legal end boundary rejected");
  $display("PASS queued fetch rejection: alignment, zero length, two overflow cases, sticky error, exact end boundary");
  $finish;
 end
 initial begin #100000;$fatal(1,"reject test timeout");end
endmodule
