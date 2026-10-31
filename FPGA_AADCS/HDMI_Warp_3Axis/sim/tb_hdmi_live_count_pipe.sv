module tb_hdmi_live_count_pipe;
 tb_hdmi_live_pcie #(.WARP_FAST(1),.WARP_READ_WEIGHT(2),.WARP_SAMPLE_PIPELINE(1),.CAPTURE_COUNT_PIPELINE(1)) test();
endmodule
