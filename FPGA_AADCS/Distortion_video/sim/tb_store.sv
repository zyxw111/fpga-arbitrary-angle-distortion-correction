`timescale 1ns/1ps
module tb_store;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,in_valid=0,in_sof=0,in_eof=0,abort=0,fence_ack=0,rd_start=0,rd_finish=0;
reg [127:0] in_data=0;reg [31:0] in_id=0;
wire in_ready,awvalid,awready,wready,wlast,fence_req,rd_valid,rd_slot,error;
wire [27:0] awaddr;wire [3:0] awlen;wire [127:0] wdata;
wire [15:0] wstrb;wire [31:0] rd_id,good_frames,dropped_frames;
wire unused0,unused1,unused2;wire [127:0] unused3;
store #(.FRAME_BEATS(32),.BASE1(28'h1000)) dut(.*);
ddrmodel mem(.clk(clk),.rst_n(rst_n),
 .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
 .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
 .arvalid(1'b0),.arready(unused0),.araddr(28'd0),.arlen(4'd0),
 .rvalid(unused1),.rlast(unused2),.rdata(unused3));
task tick;begin @(posedge clk);#1;@(negedge clk);end endtask
task check(input bit cond,input string msg);begin if(!cond)$fatal(1,"%s",msg);end endtask
function [127:0] pattern(input integer id,input integer n);
pattern={32'hc0000000 ^ id,32'ha0000000 ^ n,32'hb0000000 ^ id,32'hd0000000 ^ n};endfunction
task send(input integer id,input integer n,input bit eof,input bit change_id,input bit extra_sof);
integer i;begin
 for(i=0;i<n;i=i+1)begin
  in_valid=1;in_id=change_id && i==3 ? id+1 : id;in_data=pattern(id,i);
  in_sof=i==0 || (extra_sof && i==4);in_eof=eof && i==n-1;
  while(!in_ready)tick;
  tick;
 end
 in_valid=0;in_sof=0;in_eof=0;
end endtask
task fence;integer g;begin
 while(!fence_req)tick;
 g=good_frames;
 repeat(7)begin tick;check(good_frames==g,"no publication before write fence");end
 fence_ack=1;tick;fence_ack=0;tick;
end endtask
task take(input bit slot,input integer id);begin
 check(rd_valid && rd_slot==slot && rd_id==id,"read order/id");
 rd_start=1;tick;rd_start=0;check(!rd_valid,"reader holds frame");
end endtask
task release_frame;begin rd_finish=1;tick;rd_finish=0;end endtask
integer i;
initial begin
tick;rst_n=1;tick;
send(101,32,1,0,0);fence;check(good_frames==1 && !error,"first publish");
for(i=0;i<32;i=i+1)check(mem.memory[i]===pattern(101,i),"slot0 payload");
take(0,101);
send(102,32,1,0,0);fence;check(good_frames==2,"second publish");
send(199,32,1,0,0);tick;check(dropped_frames==1 && good_frames==2,"no free slot drops whole frame");
for(i=0;i<32;i=i+1)begin
 check(mem.memory[i]===pattern(101,i),"read-owned slot not overwritten");
 check(mem.memory[256+i]===pattern(102,i),"queued slot not overwritten");
end
release_frame;take(1,102);
send(103,3,1,0,0);fence;check(dropped_frames==2,"early EOF discarded");
for(i=0;i<32;i=i+1)check(mem.memory[i]===(i<3?pattern(103,i):128'd0),"early EOF zero padding");
send(104,32,0,0,0);fence;check(dropped_frames==3,"missing EOF discarded");
send(105,32,1,1,0);fence;check(dropped_frames==4,"changed frame id discarded");
send(106,32,1,0,1);fence;check(dropped_frames==5,"unexpected SOF discarded");
send(107,5,0,0,0);abort=1;tick;abort=0;fence;
check(dropped_frames==6 && good_frames==2,"abort pads and discards");
send(108,32,1,0,0);fence;
check(good_frames==3 && !error,"recover at next frame");
release_frame;take(0,108);release_frame;
// Coordinated reset cancels both the memory model and partial frame.
send(109,5,0,0,0);rst_n=0;tick;rst_n=1;tick;
check(!rd_valid && good_frames==0 && dropped_frames==0 && !error,"reset partial frame");
send(110,32,1,0,0);fence;take(0,110);release_frame;
$display("PASS store: fence, two owned slots, drop, early/missing EOF, ID/SOF errors, abort/pad, recovery/reset");$finish;
end
initial begin #500000;$fatal(1,"store timeout state=%0d count=%0d",dut.state,dut.count);end
endmodule
