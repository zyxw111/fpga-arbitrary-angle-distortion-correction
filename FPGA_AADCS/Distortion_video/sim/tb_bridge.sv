`timescale 1ns/1ps
module tb_bridge;
reg wr_clk=0,rd_clk=0,rd_enable=1;
always #4 wr_clk=~wr_clk;always #7 if(rd_enable)rd_clk=~rd_clk;
reg rst_n=0,start=0,in_valid=0,launch=0,rd_req=0;
reg [12:0] bytes=0;reg [127:0] in_data=0;
wire start_ready,in_ready,prepared,rd_valid,rd_done,wr_done,error;
wire [127:0] rd_data;
bridge dut(.*);
task wt;begin @(posedge wr_clk);#1;@(negedge wr_clk);end endtask
task rt;begin @(posedge rd_clk);#1;@(negedge rd_clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
integer k,n,i,completed=0;
always @(posedge wr_clk)if(wr_done)completed=completed+1;
initial begin
wt;rst_n=1;while(!start_ready)wt;
for(k=0;k<12;k=k+1)begin
 n=k%3==0?1:(k%3==1?17:256);bytes=n*16;
 start=1;wt;start=0;
 for(i=0;i<n;i=i+1)begin
  check(in_ready && !prepared,"no CDC publication before complete data");
  in_valid=1;in_data=128'hcafe0000+k*256+i;wt;in_valid=0;
  repeat(i%2)wt;
 end
 while(!prepared)rt;
 check(!start_ready,"writer cannot overwrite published RAM");
 repeat(5)begin rt;check(prepared,"ready descriptor holds");end
 launch=1;rd_req=1;rt;launch=0;
 check(rd_valid && rd_data===128'hcafe0000+k*256,"first CDC response");
 for(i=1;i<n;i=i+1)begin
  rd_req=0;repeat(i%3+1)rt;
  rd_req=1;rt;
  check(rd_valid && rd_data===128'hcafe0000+k*256+i,"CDC payload/order");
 end
 check(rd_done,"final response");rd_req=0;
 while(!start_ready)wt;
 check(!error,"CDC unexpected error");
end
wt;check(completed==12,"ack exactly once per descriptor");
// A stopped destination clock cannot free or overwrite a published descriptor.
@(negedge rd_clk);rd_enable=0;
bytes=16;start=1;wt;start=0;in_valid=1;in_data=7;wt;in_valid=0;
repeat(20)begin wt;check(!start_ready,"stopped destination retains ownership");end
rst_n=0;wt;rst_n=1;repeat(5)wt;
check(start_ready && !prepared && !error,"async reset while destination stopped");
rd_enable=1;repeat(5)rt;
rd_req=1;rt;rd_req=0;repeat(4)wt;
check(error && !rd_valid && !start_ready,"CDC invalid read propagates error");
rst_n=0;wt;rt;rst_n=1;repeat(5)wt;
check(start_ready && !prepared && !error,"common reset flushes ownership");
$display("PASS bridge: unequal clocks, 12 ownership toggles, 16/272/4096 bytes, launch+read, pauses, error/reset");$finish;
end
initial begin #500000;$fatal(1,"bridge timeout");end
endmodule
