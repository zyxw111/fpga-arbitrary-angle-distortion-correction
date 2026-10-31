module tb_warp_fast_mirror_stall;
 tb_warp_fast #(.BORDER_MIRROR(1),.SAMPLE_PIPELINE(1),.WRITE_STALL(1500)) test();
endmodule
