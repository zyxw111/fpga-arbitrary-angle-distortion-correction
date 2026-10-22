`timescale 1ns/1ps
module tb_hdmi_stream;
reg pclk=0,clk=0,rst_n=0,enable=0,vs=0,de=0,ready=1;reg [23:0] rgb=0;
always #7 pclk=~pclk;always #5 clk=~clk;
wire v0,v1,b0,b1,s0,s1,e0,e1;wire [127:0] d0,d1;integer count=0;
hdmi_stream #(.WIDTH(16),.HEIGHT(8),.FIFO_BITS(2),.VS_ACTIVE_HIGH(1)) pos(
 .pclk(pclk),.clk(clk),.rst_n(rst_n),.enable(enable),.vsync(vs),.de(de),.rgb(rgb),
 .valid(v0),.ready(ready),.data(d0),.sof(s0),.eof(e0),.bad(b0));
hdmi_stream #(.WIDTH(16),.HEIGHT(8),.FIFO_BITS(2),.VS_ACTIVE_HIGH(0)) neg(
 .pclk(pclk),.clk(clk),.rst_n(rst_n),.enable(enable),.vsync(!vs),.de(de),.rgb(rgb),
 .valid(v1),.ready(ready),.data(d1),.sof(s1),.eof(e1),.bad(b1));
always @(posedge clk)if(rst_n && ready && v0)begin
 if(!v1 || d0!==d1 || s0!==s1 || e0!==e1)$fatal(1,"polarity mismatch");
 if(d0!=={8{16'hf800}} || s0!==(count==0) || e0!==(count==15))$fatal(1,"packing/frame markers %0d",count);
 count=count+1;
end
task tick;begin @(negedge pclk);end endtask
task frame(input integer width,input integer height);
 integer x,y;
 begin
  tick();vs=1;repeat(3)tick();vs=0;repeat(4)tick();
  for(y=0;y<height;y=y+1)begin
   for(x=0;x<width;x=x+1)begin de=1;rgb=24'hff0000;tick();end
   de=0;repeat(4)tick();
  end
  repeat(8)tick();vs=1;repeat(8)tick();vs=0;repeat(8)tick();
 end
endtask
task reset;
 begin rst_n=0;enable=0;vs=0;de=0;count=0;repeat(8)tick();rst_n=1;enable=1;repeat(8)tick();end
endtask
initial begin
 reset();frame(16,8);repeat(20)tick();if(b0 || b1 || count!=16)$fatal(1,"good frame %0d bad=%b",count,b0);
 reset();frame(15,8);if(!b0 || !b1)$fatal(1,"short line accepted");
 reset();ready=0;frame(16,8);if(!b0 || !b1)$fatal(1,"overflow not reported");
 $display("PASS HDMI RGB888 packing, both VS polarities, final-frame validation, short lines, FIFO overflow");$finish;
end
initial begin #1000000;$fatal(1,"stream timeout");end
endmodule
