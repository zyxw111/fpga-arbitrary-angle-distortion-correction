`timescale 1ns/1ps
module tb_warp_dual_cache;
 reg clk=0,we=0,re=0;always #4 clk=~clk;
 reg [10:0] wa=0,a=0,b=0;reg [127:0] wd=0;wire [127:0] qa,qb;
 warp_dual_cache dut(.clk(clk),.we(we),.re(re),.wa(wa),.ra0(a),.ra1(b),.wd(wd),.rd0(qa),.rd1(qb));
 wire [127:0] refa,refb;
 warp_dual_cache #(.NATIVE_TDP(0)) reference(.clk(clk),.we(we),.re(re),.wa(wa),.ra0(a),.ra1(b),.wd(wd),.rd0(refa),.rd1(refb));
 function [127:0] pattern(input integer n,input integer frame);
  pattern={32'h12345678^n,32'h9abcdef0^frame,32'hcdef9012^(n*32'd31+frame),32'h76543210^(n*32'd17-frame)};
 endfunction
 integer frame,i,checks=0;
 initial begin
  for(frame=0;frame<3;frame=frame+1)begin
   re=0;
   for(i=0;i<2048;i=i+1)begin @(negedge clk);we=1;wa=i;wd=pattern(i,frame);end
   @(negedge clk);we=0;re=1;
   for(i=0;i<2048;i=i+1)begin
    a=(i*17)%2048;b=(2047-i*31)%2048;
    @(posedge clk);#1;
    if(qa!==pattern(a,frame) || qb!==pattern(b,frame) || qa!==refa || qb!==refb)$fatal(1,"cache dual read frame=%0d addresses=%0d/%0d got=%h/%h expected=%h/%h",frame,a,b,qa,qb,pattern(a,frame),pattern(b,frame));
    checks=checks+2;@(negedge clk);
   end
  end
  $display("PASS dual cache %0d full-depth reads: independent ports, all 2048 addresses, three changed frames",checks);$finish;
 end
endmodule
