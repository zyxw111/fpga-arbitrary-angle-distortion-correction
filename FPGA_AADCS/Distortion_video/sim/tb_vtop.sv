`timescale 1ns/1ps

module tb_vtop;
    reg pix_clk = 0, tx_clk = 0;
    always #5 pix_clk = ~pix_clk;
    always #4 tx_clk = ~tx_clk;
    reg rst_n = 0;
    wire [31:0] beat_count, frame_count, hash;
    wire overflow;

    vtop #(.WIDTH(8), .HEIGHT(2), .H_TOTAL(10),
           .V_TOTAL(3), .FIFO_ADDR_BITS(3)) dut (
        .pix_clk(pix_clk), .tx_clk(tx_clk),
        .rst_n(rst_n), .enable(1'b1),
        .beat_count(beat_count), .frame_count(frame_count),
        .hash(hash), .overflow(overflow)
    );

    initial begin
        #31; rst_n = 1;
        wait (frame_count == 3);
        #1;
        if (beat_count !== 6 || hash === 32'd0 || overflow)
            $fatal(1, "vtop beats=%0d frames=%0d hash=%h overflow=%b",
                   beat_count, frame_count, hash, overflow);
        $display("PASS tb_vtop: 3 diagnostic frames, 6 beats, hash=%h", hash);
        $finish;
    end
    initial begin
        #4000;
        $fatal(1, "vtop timeout");
    end
endmodule
