module tb_preview_corrected;
tb_demo_base #(.GROUP(1),.VIEW(1),.WIDTH(640),.HEIGHT(400),.TEST_RESETS(0),
 .GOLDEN("sim/demo_vectors/corrected_640x400.hex"),.DUMP("checks/regression/preview_corrected_actual.hex")) test(); endmodule
