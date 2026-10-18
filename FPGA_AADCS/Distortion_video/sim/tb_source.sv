`timescale 1ns/1ps
module tb_source;
    tb_pipeline #(.ASYNC_DMA(1),.SOURCE(1)) test();
endmodule
