`timescale 1ns/1ps
module tb_clock_meter;
 reg sys=0,pix=0,rst_n=0,enable_pix=1;
 integer half_period=5;
 always #5 sys=~sys;
 always begin #(half_period);if(enable_pix)pix=~pix;else pix=0;end
 wire [31:0] hz;wire changed;integer changes=0;
 clock_meter #(.SYS_HZ(10000)) dut(sys,pix,rst_n,hz,changed);
 always @(negedge sys)if(changed)changes=changes+1;
 initial begin
  #40;rst_n=1;#35000;
  if(hz<9990 || hz>10010)$fatal(1,"clock meter %0d",hz);
  half_period=10;#35000;
  if(hz<4990 || hz>5010)$fatal(1,"clock switch %0d",hz);
  if(changes==0)$fatal(1,"clock-only refresh change did not request reacquisition");
  enable_pix=0;#35000;if(hz!=0)$fatal(1,"stopped clock stale");
  half_period=4;enable_pix=1;#35000;
  if(hz<12490 || hz>12510)$fatal(1,"clock recovery %0d",hz);
  rst_n=0;#20;if(hz!=0)$fatal(1,"reset stale Hz");
  $display("PASS pixel frequency changes, stopped clock, recovery, reset");$finish;
 end
endmodule
