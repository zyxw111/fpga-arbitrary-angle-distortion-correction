`timescale 1ns/1ps
module tb_camclock;
 reg fpga_clk=0;always #5 fpga_clk=~fpga_clk;
 reg adapter_clk=0;always #7 adapter_clk=~adapter_clk;
 wire floating_xclk;
 tri shared_xclk;
 assign shared_xclk=adapter_clk;
 cam #(.WIDTH(4),.HEIGHT(2)) default_cam(
 .cam_xclk(floating_xclk),.rst_n(1'b0),.xclk_in(fpga_clk),
 .rst_cmd_n(1'b0),.pwdn_cmd(1'b1),.led_cmd(1'b0),
 .scl_pull_low(1'b0),.sda_pull_low(1'b0),
 .cam_pclk(fpga_clk),.cam_href(1'b0),.cam_vsync(1'b0),.cam_d(8'd0));
 cam #(.WIDTH(4),.HEIGHT(2)) shared_cam(
 .cam_xclk(shared_xclk),.rst_n(1'b0),.xclk_in(fpga_clk),
 .rst_cmd_n(1'b0),.pwdn_cmd(1'b1),.led_cmd(1'b0),
 .scl_pull_low(1'b0),.sda_pull_low(1'b0),
 .cam_pclk(fpga_clk),.cam_href(1'b0),.cam_vsync(1'b0),.cam_d(8'd0));
 integer n;
 initial begin
  for(n=0;n<200;n=n+1) begin #1;
   if(floating_xclk!==1'bz) $fatal(1,"default XCLK must release");
   if(shared_xclk!==adapter_clk) $fatal(1,"FPGA contests adapter oscillator");
  end
  $display("PASS camclock: default high-Z and no contention with independent adapter oscillator");$finish;
 end
endmodule
