`timescale 1ns/1ps
module tb_profile_control;
 reg clk=0,rst_n=0,key_n=1,busy=0;always #5 clk=~clk;
 wire [2:0] profile;wire cfg_rst_n,pending;
 profile_control #(.DEBOUNCE_CYCLES(4),.RESET_CYCLES(6)) dut(clk,rst_n,key_n,busy,profile,cfg_rst_n,pending);
 task cycles(input integer n);repeat(n)@(negedge clk);endtask
 integer i;
 initial begin
  cycles(3);rst_n=1;cycles(10);
  if(profile!=0 || !cfg_rst_n)$fatal(1,"initial profile/reset");
  key_n=0;cycles(1);key_n=1;cycles(8);if(profile!=0)$fatal(1,"bounce switched profile");
  busy=1;key_n=0;cycles(12);
  if(!pending || profile!=0 || !cfg_rst_n)$fatal(1,"did not wait for idle");
  busy=0;cycles(2);if(profile!=1 || cfg_rst_n)$fatal(1,"profile switch/reset missing");
  cycles(20);if(profile!=1 || !cfg_rst_n)$fatal(1,"held key repeats");
  for(i=2;i<=7;i=i+1)begin key_n=1;cycles(10);key_n=0;cycles(20);if(profile!=(i%7))$fatal(1,"wrap/profile %0d",i);end
  rst_n=0;cycles(2);if(profile!=0)$fatal(1,"KEY0 did not restore multi");
  $display("PASS profile debounce, held key, I2C idle switch, reset pulse, seven-profile wrap");$finish;
 end
endmodule
