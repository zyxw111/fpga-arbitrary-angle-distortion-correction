`timescale 1ns/1ps

module tb_overflow;
    reg pix_clk = 0, tx_clk = 0;
    always #5 pix_clk = ~pix_clk;
    always #7 tx_clk = ~tx_clk;
    reg rst_n = 0;
    wire tx_valid, tx_sof, tx_eof, overflow;
    wire [127:0] tx_data;
    wire [31:0] tx_frame_id;

    stream #(.WIDTH(8), .HEIGHT(2), .H_TOTAL(10),
             .V_TOTAL(3), .FIFO_ADDR_BITS(2)) dut (
        .pix_clk(pix_clk), .tx_clk(tx_clk), .rst_n(rst_n),
        .enable(1'b1), .tx_valid(tx_valid), .tx_ready(1'b0),
        .tx_data(tx_data), .tx_sof(tx_sof), .tx_eof(tx_eof),
        .tx_frame_id(tx_frame_id), .overflow(overflow)
    );

    initial begin
        #31; rst_n = 1;
        wait (overflow);
        repeat (10) @(posedge pix_clk);
        if (!overflow) $fatal(1, "overflow did not latch");
        rst_n = 0;
        repeat (3) @(posedge pix_clk);
        if (overflow) $fatal(1, "overflow did not clear on reset");
        $display("PASS tb_overflow: sustained stall reports sticky overflow");
        $finish;
    end
    initial begin
        #4000;
        $fatal(1, "overflow timeout");
    end
endmodule
