`timescale 1ns/1ps
module tb_profile_reset_ab;
 reg clk=0,rst_n=0,key_n=1,busy=0;
 always #4 clk=~clk;
 wire [2:0] a,b;wire ra,rb,pa,pb;
 profile_control #(.DEBOUNCE_CYCLES(3),.RESET_CYCLES(7),.REGISTER_CFG_RESET(0)) original(clk,rst_n,key_n,busy,a,ra,pa);
 profile_control #(.DEBOUNCE_CYCLES(3),.RESET_CYCLES(7),.REGISTER_CFG_RESET(1)) registered(clk,rst_n,key_n,busy,b,rb,pb);
 always @(negedge clk)if({a,ra,pa}!=={b,rb,pb})$fatal(1,"configuration reset changed cycle/profile");
 integer i;
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(i=0;i<15;i=i+1)begin
   repeat(15)@(negedge clk);busy=1;key_n=0;
   repeat(18)@(negedge clk);busy=0;
   repeat(20)@(negedge clk);key_n=1;
   repeat(12)@(negedge clk);
  end
  rst_n=0;repeat(3)@(negedge clk);rst_n=1;repeat(20)@(negedge clk);
  $display("PASS registered/legacy configuration reset: identical release cycles, busy delay, held key, wrap and reset");$finish;
 end
endmodule
