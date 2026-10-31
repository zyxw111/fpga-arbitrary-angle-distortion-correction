module tb_warp_tiles_three_banks;
 tb_warp_tiles #(.OUTPUT_BANKS(3),.WRITE_STALL(1500)) test();
endmodule
