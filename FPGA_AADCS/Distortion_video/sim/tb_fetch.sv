`timescale 1ns/1ps
module tb_fetch;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0,out_ready=0;
reg [27:0] base_addr=0;reg [31:0] beats=0;
wire start_ready,arvalid,arready,rvalid,rlast,out_valid,out_last,done,error;
wire [27:0] araddr;wire [3:0] arlen;wire [127:0] rdata,out_data;
wire unused0,unused1,unused2;
fetch dut(.*);
ddrmodel #(.WORDS(65536),.FORMULA(1)) mem(
 .clk(clk),.rst_n(rst_n),.awvalid(1'b0),.awready(unused0),.awaddr(28'd0),.awlen(4'd0),
 .wdata(128'd0),.wstrb(16'd0),.wready(unused1),.wlast(unused2),
 .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
 .rvalid(rvalid),.rlast(rlast),.rdata(rdata));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
function [127:0] pattern(input integer n);
pattern={32'h12340000 ^ n,32'h56780000 ^ n,32'habcd0000 ^ n,32'hfedc0000 ^ n};endfunction
integer received=0,cy=0,expected=0,k,n;
reg held=0,ah=0;reg [127:0] prev;reg prevlast;reg [27:0] prevaddr;reg [3:0] prevlen;
always @(posedge clk)if(rst_n)begin
 if(held)check(out_valid && out_data===prev && out_last===prevlast,"output stall stability");
 held=out_valid && !out_ready;prev=out_data;prevlast=out_last;
 if(ah)check(arvalid && araddr==prevaddr && arlen==prevlen,"AR stall stability");
 ah=arvalid && !arready;prevaddr=araddr;prevlen=arlen;
 if(out_valid && out_ready)begin
  check(out_data===pattern(expected+received),"DDR read payload order");
  check(out_last==(received==n-1),"frame last");received=received+1;
 end
end
initial begin
tick;rst_n=1;tick;
for(k=0;k<5;k=k+1)begin
 n=k==0?1:(k==1?17:(k==2?255:(k==3?256:513)));
 base_addr=k==0?28'hff0:28'hf90;beats=n;expected=base_addr/16;received=0;
 start=1;tick;start=0;
 while(!done)begin out_ready=cy%11<6;tick;cy=cy+1;end
 check(received==n && !error,"fetch done count");out_ready=0;tick;
end
base_addr=1;beats=16;start=1;tick;start=0;check(error && !arvalid,"bad address");
rst_n=0;held=0;ah=0;tick;rst_n=1;tick;
base_addr=28'hffffff0;beats=2;start=1;tick;start=0;check(error,"address range overflow");
$display("PASS fetch: 1/17/255/256/513 beats, page splits, zero-latency R, stalls, bounds");$finish;
end
initial begin #500000;$fatal(1,"fetch timeout");end
endmodule
