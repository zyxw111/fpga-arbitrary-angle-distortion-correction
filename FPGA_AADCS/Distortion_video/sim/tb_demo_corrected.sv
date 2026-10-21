module tb_demo_corrected;
tb_demo_base #(.GROUP(1),.VIEW(1),.GOLDEN("sim/demo_vectors/corrected_128x80.hex"),
 .DUMP("build/sim/demo_corrected_actual.hex")) test(); endmodule
