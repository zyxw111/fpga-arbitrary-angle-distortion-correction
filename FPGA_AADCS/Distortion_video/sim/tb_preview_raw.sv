module tb_preview_raw;
tb_demo_base #(.GROUP(1),.VIEW(0),.WIDTH(640),.HEIGHT(400),.TEST_RESETS(0),
 .GOLDEN("sim/demo_vectors/raw_640x400.hex"),.DUMP("build/sim/preview_raw_actual.hex")) test(); endmodule
