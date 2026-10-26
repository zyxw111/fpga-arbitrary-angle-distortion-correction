`timescale 1ns/1ps
module tb_hdmi_monitor;
 reg sys_clk=0,pclk=0,rst_n=0,run_pixel=1;
 always #5 sys_clk=~sys_clk;
 always #7 if(run_pixel)pclk=~pclk;
 integer x=0,y=0;
 always @(negedge pclk)if(!rst_n)begin x=0;y=0;end else begin
  if(x==79)begin x=0;if(y==47)y=0;else y=y+1;end else x=x+1;
 end
 wire vs=y<2,de=x>=8 && x<72 && y>=4 && y<44,hs=x<4;
 wire [31:0] hz,frames,dimensions,negative_frames,negative_dimensions;
 hdmi_input_monitor #(.SYS_HZ(10000),.VS_ACTIVE_HIGH(1)) positive(
  .sys_clk(sys_clk),.pclk(pclk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h123456),
  .pixel_hz(hz),.frames(frames),.dimensions(dimensions));
 hdmi_input_monitor #(.SYS_HZ(10000),.VS_ACTIVE_HIGH(0)) negative(
  .sys_clk(sys_clk),.pclk(pclk),.rst_n(rst_n),.vs(!vs),.hs(hs),.de(de),.rgb(24'h654321),
  .frames(negative_frames),.dimensions(negative_dimensions));
 initial begin
  #100;rst_n=1;#250000;
  if(dimensions!=={16'd40,16'd64} || dimensions!==negative_dimensions || frames<3 || frames!=negative_frames)
   $fatal(1,"pixel-domain geometry failed dimensions=%h frames=%0d",dimensions,frames);
  if(hz<7000 || hz>7300)$fatal(1,"Gray frequency CDC failed %0d",hz);
  @(negedge pclk);run_pixel=0;#30000;
  if(hz!=0)$fatal(1,"stopped pixel clock not detected %0d",hz);
  rst_n=0;#100;run_pixel=1;rst_n=1;#150000;
  if(dimensions!=={16'd40,16'd64})$fatal(1,"monitor reset recovery failed");
  $display("PASS HDMI monitor: pixel-domain width/height, both VS polarities, asynchronous clock frequency, missing clock, reset recovery");$finish;
 end
endmodule
