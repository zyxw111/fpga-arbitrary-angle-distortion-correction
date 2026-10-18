module tb_preview_bars;
tb_demo_base #(.GROUP(0),.VIEW(0),.WIDTH(640),.HEIGHT(400),.TEST_RESETS(0),
 .GOLDEN("sim/demo_vectors/bars_640x400.hex"),.DUMP("checks/regression/preview_bars_actual.hex")) test(); endmodule
