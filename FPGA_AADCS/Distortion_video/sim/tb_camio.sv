`timescale 1ns/1ps
// Digital open-drain/connector behavior only, not voltage/analog simulation.
module tb_camio;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,cmd_rst=0,cmd_pwdn=1,scl_low=0,sda_low=0;
 reg slave_scl=0,slave_sda=0;
 tri1 scl,sda;
 assign scl=slave_scl?1'b0:1'bz;
 assign sda=slave_sda?1'b0:1'bz;
 wire scl_in,sda_in,cam_rst,cam_pwdn,xclk,led;
 cam #(.WIDTH(4),.HEIGHT(2),.DRIVE_XCLK(1)) dut(
 .cam_scl(scl),.cam_sda(sda),.cam_vsync(1'b0),.cam_d(8'd0),
 .cam_rst_n(cam_rst),.cam_pwdn(cam_pwdn),.cam_led(led),
 .cam_href(1'b0),.cam_pclk(clk),.cam_xclk(xclk),
 .rst_n(rst_n),.xclk_in(clk),.rst_cmd_n(cmd_rst),.pwdn_cmd(cmd_pwdn),
 .led_cmd(1'b0),.scl_pull_low(scl_low),.sda_pull_low(sda_low),
 .scl_in(scl_in),.sda_in(sda_in));
 integer a,b,c,d;
 initial begin
  #1;if(cam_rst!==0||cam_pwdn!==1) $fatal(1,"reset/powerdown polarity");
  rst_n=1;
  for(a=0;a<2;a=a+1)for(b=0;b<2;b=b+1)
  for(c=0;c<2;c=c+1)for(d=0;d<2;d=d+1) begin
   scl_low=a;sda_low=b;slave_scl=c;slave_sda=d;#1;
   if(scl!==!(a||c)||sda!==!(b||d)) $fatal(1,"open drain contention/release");
   if(scl_in!==scl||sda_in!==sda) $fatal(1,"bus input feedback");
  end
  scl_low=0;sda_low=0;slave_scl=0;slave_sda=0;
  cmd_rst=1;cmd_pwdn=0;#1;
  if(cam_rst!==1||cam_pwdn!==0||led!==0) $fatal(1,"control polarity");
  repeat(8) begin @(negedge clk);#1;if(xclk!==clk) $fatal(1,"XCLK");
   @(posedge clk);#1;if(xclk!==clk) $fatal(1,"XCLK");end
  $display("PASS camio: all 16 wired-AND combinations, external sink, pull-up release, input feedback, reset/PWDN polarity, XCLK");$finish;
 end
endmodule
