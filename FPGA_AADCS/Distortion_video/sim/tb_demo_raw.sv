module tb_demo_raw;
tb_demo_base #(.GROUP(1),.VIEW(0),.GOLDEN("sim/demo_vectors/raw_128x80.hex"),
 .DUMP("build/sim/demo_raw_actual.hex")) test(); endmodule
