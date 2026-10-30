module tb_warp_fast_sample_stall;
 tb_warp_fast #(.SAMPLE_PIPELINE(1),.WRITE_STALL(1500)) test();
endmodule
