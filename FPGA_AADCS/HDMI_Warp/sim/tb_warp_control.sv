`timescale 1ns/1ps
module tb_warp_control;
reg h=0,f=0,rst=0,we=0,safe=0;always #5 h=~h;always #7 f=~f;
reg [11:0] addr=0,sa=8;reg [31:0] data=0;reg [15:0] be=16'hffff;
wire [543:0] active;wire [31:0] generation;wire [127:0] status;wire pending;
warp_control dut(.host_clk(h),.frame_clk(f),.rst_n(rst),.wr_en(we),.wr_addr(addr),
 .wr_data(data),.wr_be(be),.defaults(544'd0),.frame_safe(safe),.status_addr(sa),
 .active_config(active),.active_generation(generation),.status_data(status),.pending(pending));
task write(input [11:0] a,input [31:0] d);begin
 @(negedge h);we=1;addr=a;data=d;@(negedge h);we=0;
end endtask
integer i;
initial begin
 #31;rst=1;
 for(i=0;i<17;i=i+1)write(12'h200+4*i,32'h12340000+i);
 if(active!==0 || pending)$fatal(1,"shadow changed active bank");
 write('h250,1);repeat(9)@(negedge f);
 if(!pending || generation!=0 || active!==0)$fatal(1,"commit applied mid-frame");
 write('h200,'hdeadbeef);write('h250,2);
 if(!status[33])$fatal(1,"pending write was not rejected");
 safe=1;wait(generation==1);repeat(8)@(negedge h);
 if(pending || status[127:96]!=1)$fatal(1,"acknowledgement failed");
 for(i=0;i<17;i=i+1)if(active[i*32+:32]!==32'h12340000+i)$fatal(1,"torn bank word %0d",i);
 be=16'h000f;write('h200,'hffffffff);be='hffff;
 write('h250,2);wait(generation==2);repeat(8)@(negedge h);
 if(active[31:0]!==32'h12340000)$fatal(1,"partial write changed bank");
 safe=0;write('h240,'hfedcba98);write('h250,3);repeat(8)@(negedge f);
 if(active[543:512]!==32'h12340010)$fatal(1,"last word changed before safe point");
 safe=1;wait(generation==3);repeat(8)@(negedge h);
 if(active[543:512]!==32'hfedcba98 || pending)$fatal(1,"last coefficient/second toggle failed");
 $display("PASS warp control: 17 signed words, atomic frame-safe commit, busy rejection, partial write rejection, repeated CDC handshakes");$finish;
end
initial begin #100000;$fatal(1,"control timeout");end
endmodule
