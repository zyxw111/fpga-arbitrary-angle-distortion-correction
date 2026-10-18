`timescale 1ns/1ps
module tb_faults;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,start=0,arready=0,rvalid=0,rlast=0,out_ready=0;
reg [27:0] base_addr=0;reg [31:0] beats=16;reg [127:0] rdata=0;
wire start_ready,arvalid,out_valid,out_last,done,error;
wire [27:0] araddr;wire [3:0] arlen;wire [127:0] out_data;
fetch dut(.*);
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
task reset;begin rst_n=0;start=0;arready=0;rvalid=0;rlast=0;out_ready=0;
 tick;rst_n=1;tick;end endtask
task begin_read(input integer n);begin beats=n;start=1;tick;start=0;end endtask
initial begin
reset;begin_read(16);arready=1;rvalid=1;rlast=1;tick;
check(error && !out_valid,"early RLAST rejected, never publish partial burst");
reset;begin_read(1);arready=1;rvalid=1;rlast=0;tick;
check(error && !out_valid,"missing RLAST rejected");
reset;rvalid=1;tick;check(error,"unsolicited R response rejected");
reset;begin_read(16);rvalid=1;tick;check(error,"response before AR acceptance rejected");
reset;begin_read(1);arready=1;rvalid=1;rlast=1;tick;
check(out_valid,"single read buffered");arready=0;rlast=0;tick;
check(error && !out_valid,"extra return while output stalled rejected");
reset;begin_read(16);check(arvalid,"pending AR");reset;
check(start_ready && !arvalid && !out_valid && !done && !error,"reset pending command");
begin_read(0);check(error && !arvalid,"zero length rejected");
$display("PASS faults: early/missing/extra DDR returns, unsolicited response, reset pending AR, zero length");$finish;
end
initial begin #20000;$fatal(1,"faults timeout");end
endmodule
