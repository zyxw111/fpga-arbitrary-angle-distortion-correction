module tb_warp_fast_mirror;
 tb_warp_fast #(.BORDER_MIRROR(1),.SAMPLE_PIPELINE(1)) test();
 initial begin
  #1;
  if(test.dut.mirror_q12(-32'sd1024,16'd40)!==32'sd1024)$fatal(1,"fractional top");
  if(test.dut.mirror_q12(32'sd160768,16'd40)!==32'sd158720)$fatal(1,"fractional bottom");
  if(test.dut.mirror_q12(-32'sd2147483648,16'd40)!==32'sd159744)$fatal(1,"negative overflow");
  if(test.dut.mirror_q12(32'sd2147483647,16'd40)!==32'sd0)$fatal(1,"positive overflow");
  if(test.dut.mirror_q12(-32'sd1,16'd1)!==32'sd0)$fatal(1,"single row");
 end
endmodule
