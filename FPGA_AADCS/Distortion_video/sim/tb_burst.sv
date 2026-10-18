`timescale 1ns/1ps
module tb_burst;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,start=0,in_valid=0,awready=0,wready=0,wlast=0;
reg [27:0] base_addr=28'hf00;
reg [31:0] beats=48;
reg [127:0] in_data=0;
wire start_ready,in_ready,awvalid,done,error;
wire [27:0] awaddr; wire [3:0] awlen;
wire [127:0] wdata; wire [15:0] wstrb;
burst dut(.*);
integer sent=0,received=0,commands=0,cycle=0,beat=0;
reg active=0,held=0; reg [27:0] held_addr;
function [127:0] pattern(input integer n);
pattern={32'hfeed0000 ^ n,32'h12340000 ^ n,32'h56780000 ^ n,32'h9abc0000 ^ n};
endfunction
task tick; begin @(posedge clk); #1; @(negedge clk); end endtask
task check(input bit ok,input string msg); begin if(!ok) $fatal(1,"%s",msg); end endtask
always @(posedge clk) if(rst_n) begin
 if(in_valid && in_ready) sent=sent+1;
 if(held) check(awvalid && awaddr==held_addr,"AW must stay stable under stall");
 held=awvalid && !awready; held_addr=awaddr;
 if(awvalid && awready) begin
  check(!active && sent >= (commands+1)*16,"command requires full burst");
  check(awaddr==28'hf00+commands*256 && awlen==15,"address/length/page split");
  commands=commands+1; active=1; beat=0;
 end
 if(wready && active) begin
  check(wstrb==16'hffff && wdata===pattern(received),"payload order/strobes");
  received=received+1; beat=beat+1;
  if(beat==16) active=0;
 end
end
initial begin
tick; rst_n=1; tick; start=1; tick; start=0;
while(!done) begin
 in_valid=(sent<48) && cycle%3!=0; in_data=pattern(sent);
 awready=cycle%5==0;
 wready=(active && cycle%4!=0) || (awvalid && awready);
 wlast=active && beat==15;
 tick; cycle=cycle+1;
end
in_valid=0; wready=0; awready=0; wlast=0;
check(sent==48 && received==48 && commands==3 && !error,"transfer complete");
tick; check(!done && start_ready,"done pulse/restart");
// Invalid configuration must not issue a command.
base_addr=1; start=1; tick; start=0;
check(error && !awvalid && !in_ready,"reject unaligned request");
rst_n=0; tick; rst_n=1; tick;
// Early last must halt and must not signal successful completion.
sent=0; received=0; commands=0; active=0; held=0;
base_addr=28'hf00; beats=16; start=1; tick; start=0;
while(sent<16) begin in_valid=1; in_data=pattern(sent); tick; end
in_valid=0; awready=1; tick; awready=0;
wready=1; wlast=1; tick; wready=0;
check(error && !done && !awvalid && !in_ready,"early last halts");
$display("PASS burst: prebuffering, AW stalls, data stalls, page transition, payload, invalid request, early last");
$finish;
end
initial begin #100000; $fatal(1,"timeout"); end
endmodule
