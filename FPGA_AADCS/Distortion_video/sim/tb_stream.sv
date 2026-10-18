`timescale 1ns/1ps

module tb_stream;
    reg pix_clk = 0, tx_clk = 0;
    always #5 pix_clk = ~pix_clk;
    always #4 tx_clk = ~tx_clk;
    reg rst_n = 0;
    reg tx_ready = 0;
    wire tx_valid, tx_sof, tx_eof, overflow;
    wire [127:0] tx_data;
    wire [31:0] tx_frame_id;
    reg [127:0] expected;
    integer cycles = 0, beats = 0;

    stream #(.WIDTH(8), .HEIGHT(2), .H_TOTAL(10),
             .V_TOTAL(3), .FIFO_ADDR_BITS(3)) dut (
        .pix_clk(pix_clk), .tx_clk(tx_clk), .rst_n(rst_n),
        .enable(1'b1), .tx_valid(tx_valid), .tx_ready(tx_ready),
        .tx_data(tx_data), .tx_sof(tx_sof), .tx_eof(tx_eof),
        .tx_frame_id(tx_frame_id), .overflow(overflow)
    );

    always @(negedge tx_clk) begin
        cycles = cycles + 1;
        tx_ready = rst_n && cycles > 28 && (cycles % 5 != 0);
    end
    always @(posedge tx_clk) if (rst_n && tx_valid && tx_ready) begin
        if (tx_data !== expected || tx_sof !== (beats % 2 == 0) ||
            tx_eof !== (beats % 2 == 1) ||
            tx_frame_id !== (beats / 2))
            $fatal(1, "stream beat #%0d data=%h sof=%b eof=%b fid=%0d",
                   beats, tx_data, tx_sof, tx_eof, tx_frame_id);
        beats = beats + 1;
        if (beats == 6) begin
            if (overflow) $fatal(1, "unexpected source overflow");
            $display("PASS tb_stream: 3 frames across unequal clocks and stalls");
            $finish;
        end
    end

    initial begin
        expected = {16'h0000, 16'h001f, 16'hf800, 16'hf81f,
                    16'h07e0, 16'h07ff, 16'hffe0, 16'hffff};
        #31; rst_n = 1;
    end
    initial begin
        #5000;
        $fatal(1, "stream timeout beats=%0d overflow=%b", beats, overflow);
    end
endmodule
