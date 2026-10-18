`timescale 1ns/1ps
module tb_mode_control;
 reg clk=0,rst_n=0,key1_n=1,image_idle=0,host_busy=0,request=0,tx_busy=0;
 always #4 clk=~clk;
 wire [1:0] mode;wire image_rst_n,switching;wire [31:0] generation;
 video_mode_control #(.DEBOUNCE_CYCLES(5),.RESET_CYCLES(12)) dut(.*);
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 initial begin
  cycles(3);rst_n=1;wait(image_rst_n);cycles(3);
  // Press while DDR is writing: mode and reset must stay unchanged.
  key1_n=0;cycles(20);
  if(!switching || mode!=0 || !image_rst_n)$fatal(1,"switched during DDR write");
  image_idle=1;host_busy=1;cycles(10);
  if(mode!=0 || !image_rst_n)$fatal(1,"switched during DMA descriptor");
  host_busy=0;request=1;cycles(10);
  if(mode!=0 || !image_rst_n)$fatal(1,"switched with pending request");
  request=0;tx_busy=1;cycles(10);
  if(mode!=0 || !image_rst_n)$fatal(1,"switched before posted TX drained");
  tx_busy=0;wait(!image_rst_n);
  if(mode!=1 || generation!=1)$fatal(1,"mode/generation");
  cycles(10);if(image_rst_n)$fatal(1,"reset too short");
  wait(image_rst_n);cycles(30);
  if(mode!=1 || generation!=1)$fatal(1,"held press repeated");
  key1_n=1;cycles(12);key1_n=0;
  wait(generation==2);wait(image_rst_n);
  if(mode!=2)$fatal(1,"corrected mode");
  key1_n=1;cycles(12);key1_n=0;
  wait(generation==3);wait(image_rst_n);
  if(mode!=0)$fatal(1,"bars wrap");
  rst_n=0;cycles(2);rst_n=1;wait(image_rst_n);
  if(mode!=0 || generation!=0)$fatal(1,"global reset default");
  $display("PASS mode control: waits for DDR idle, DMA request and posted TX drain; held key; mode wrap; global reset");
  $finish;
 end
 initial begin #20000;$fatal(1,"mode control timeout");end
endmodule
