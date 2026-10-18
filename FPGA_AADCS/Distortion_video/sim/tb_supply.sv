`timescale 1ns/1ps
module tb_supply;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0,in_valid=0,launch=0,rd_req=0;
reg [12:0] bytes=0;reg [127:0] in_data=0;
wire start_ready,in_ready,prepared,rd_valid,done,error;wire [127:0] rd_data;
supply dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
task reset;begin rst_n=0;start=0;in_valid=0;rd_req=0;launch=0;tick;rst_n=1;tick;end endtask
integer n,i,k;
initial begin
reset;
for(k=0;k<3;k=k+1) begin
 n=k==0?1:(k==1?7:256);bytes=n*16;start=1;tick;start=0;
 for(i=0;i<n;i=i+1) begin
  check(in_ready && !prepared,"not launchable before full descriptor");
  in_valid=1;in_data=128'hcafe0000+i;tick;in_valid=0;tick;
 end
 check(prepared && !in_ready,"prepared after whole descriptor");
 repeat(4)begin tick;check(prepared,"prepared must hold");end
 // First synchronous read is allowed on the launch edge.
 launch=1;rd_req=1;tick;launch=0;
 check(rd_valid && rd_data===128'hcafe0000 && done==(n==1),"first response/launch");
 rd_req=0;tick;check(!rd_valid,"response pulse");
 for(i=1;i<n;i=i+1)begin
  rd_req=1;tick;
  check(rd_valid && rd_data===128'hcafe0000+i && done==(i==n-1),"sync payload/last");
  rd_req=0;repeat(i%3+1)tick;
 end
 check(start_ready && !error,"descriptor released");
end
rd_req=1;tick;rd_req=0;check(error && !rd_valid && !start_ready,"reject overread");
reset;bytes=0;start=1;tick;start=0;check(error,"zero descriptor");
reset;bytes=17;start=1;tick;start=0;check(error,"unaligned descriptor");
reset;bytes=4112;start=1;tick;start=0;check(error,"oversize descriptor");
reset;bytes=32;start=1;tick;start=0;
rd_req=1;tick;rd_req=0;check(error && !rd_valid,"no reads during prefill");
reset;bytes=32;start=1;tick;start=0;in_valid=1;in_data=1;tick;
reset;check(start_ready && !prepared && !rd_valid && !error,"reset flushes partial fill");
$display("PASS supply: 16/112/4096 bytes, launch/read overlap, gaps, under/overread, bounds, reset");$finish;
end
initial begin #200000;$fatal(1,"supply timeout");end
endmodule
