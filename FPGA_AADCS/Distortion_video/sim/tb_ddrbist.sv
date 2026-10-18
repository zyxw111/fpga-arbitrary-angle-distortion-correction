`timescale 1ns/1ps
module tb_ddrbist;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,init_done=0,corrupt=0,stall=0;
 wire awvalid,awready,wready,wlast,arvalid,arready,rvalid,rlast;
 wire [27:0] awaddr,araddr,fail_addr;
 wire [3:0] awlen,arlen;
 wire [127:0] wdata,rdata,expected,observed;
 wire [15:0] wstrb;
 wire passed,failed;wire [2:0] fail_code;wire [31:0] checked;
 ddrbist #(.BASE(28'hf00),.BEATS(64),.WAIT_CYCLES(8),.TIMEOUT(3000)) dut(
  .clk(clk),.rst_n(rst_n),.init_done(init_done),
  .awvalid(awvalid),.awready(awready&&!stall),.awaddr(awaddr),.awlen(awlen),
  .wdata(wdata),.wstrb(wstrb),.wready(wready&&!stall),.wlast(wlast),
  .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
  .rvalid(rvalid),.rlast(rlast),.rdata(rdata^{127'd0,corrupt}),
  .passed(passed),.failed(failed),.fail_code(fail_code),.checked(checked),
  .fail_addr(fail_addr),.expected(expected),.observed(observed));
 ddrmodel #(.WORDS(512)) mem(.clk(clk),.rst_n(rst_n),
  .awvalid(awvalid&&!stall),.awready(awready),.awaddr(awaddr),.awlen(awlen),
  .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
  .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
  .rvalid(rvalid),.rlast(rlast),.rdata(rdata));
 task reset;
  begin @(negedge clk);rst_n=0;init_done=0;corrupt=0;stall=0;
   repeat(4) @(negedge clk);rst_n=1;
   repeat(20) begin @(negedge clk);if(awvalid||arvalid) $fatal(1,"traffic before init");end
   init_done=1;
  end
 endtask
 initial begin
  reset();wait(passed||failed);@(negedge clk);
  if(failed||checked!=128) $fatal(1,"normal bist failed code=%d checked=%d",fail_code,checked);
  reset();corrupt=1;wait(failed);@(negedge clk);
  if(passed||fail_code!=1||fail_addr!=28'hf00||expected==observed) $fatal(1,"mismatch diagnosis");
  reset();stall=1;wait(failed);@(negedge clk);
  if(fail_code!=3||awvalid||arvalid) $fatal(1,"timeout diagnosis/quiescence");
  reset();wait(awvalid);@(negedge clk);init_done=0;wait(failed);@(negedge clk);
  if(fail_code!=4) $fatal(1,"init loss diagnosis");
  reset();wait(passed||failed);if(failed) $fatal(1,"reset recovery");
  $display("PASS DDR BIST two patterns, page boundary, init gating, corruption, timeout, init loss, reset recovery");$finish;
 end
 initial begin #300000;$fatal(1,"bench timeout");end
endmodule
