`timescale 1ns/1ps
module tb_frame;
reg clk=0; always #5 clk=~clk;
reg rst_n=0,wr_start=0,wr_finish=0,wr_good=0,rd_start=0,rd_finish=0;
reg [31:0] wr_id=0;
wire wr_ready,wr_slot,rd_valid,rd_slot,error;
wire [31:0] rd_id;
frame dut(.*);
task tick; begin @(posedge clk); #1; @(negedge clk); end endtask
task check(input bit ok,input string msg); begin
if(!ok) $fatal(1,"%s",msg); end endtask
task publish(input bit slot,input integer id,input bit good); begin
check(wr_ready && wr_slot==slot,"write allocation");
wr_start=1; tick; wr_start=0;
check(!wr_ready,"writing slot must stay owned");
wr_id=id; wr_good=good; wr_finish=1; tick; wr_finish=0;
end endtask
task take(input bit slot,input integer id); begin
check(rd_valid && rd_slot==slot && rd_id==id,"published frame order/id");
rd_start=1; tick; rd_start=0;
check(!rd_valid,"read slot must stay owned");
end endtask
integer i;
initial begin
tick; rst_n=1; tick;
check(wr_ready && !rd_valid,"reset state");
publish(0,10,0); check(!rd_valid,"discard must not publish");
publish(0,11,1); take(0,11);
publish(1,12,1);
repeat(8) begin tick; check(!wr_ready && !rd_valid,"full buffers/read stall"); end
rd_finish=1; tick; rd_finish=0;
take(1,12);
// Producer commit and consumer release in the same cycle, different slots.
wr_start=1; tick; wr_start=0;
wr_id=13; wr_good=1; wr_finish=1; rd_finish=1;
tick; wr_finish=0; rd_finish=0;
take(0,13); rd_finish=1; tick; rd_finish=0;
for(i=0;i<40;i=i+1) begin
publish((i+1)%2,100+i,1); take((i+1)%2,100+i);
rd_finish=1; tick; rd_finish=0;
end
check(!error,"unexpected protocol error");
rd_finish=1; tick; rd_finish=0; check(error,"illegal release detection");
rst_n=0; tick; rst_n=1; tick; check(!error && wr_ready && !rd_valid,"reset flush");
publish(0,200,1); publish(1,201,1);
check(!wr_ready && rd_valid && rd_id==200,"two queued frames");
take(0,200); rd_finish=1; tick; rd_finish=0;
publish(0,202,0); publish(0,203,1);
take(1,201); rd_finish=1; tick; rd_finish=0;
take(0,203); rd_finish=1; tick; rd_finish=0;
check(!error && wr_ready && !rd_valid,"queue drained after discard");
$display("PASS frame: ownership, discard, backpressure, simultaneous commit/release, wrap, errors/reset");
$finish;
end
initial begin #100000; $fatal(1,"timeout"); end
endmodule
