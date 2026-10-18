module tb_demo_bars;
tb_demo_base #(.GROUP(0),.VIEW(0),.GOLDEN("sim/demo_vectors/bars_128x80.hex"),
 .DUMP("checks/regression/demo_bars_actual.hex")) test(); endmodule
