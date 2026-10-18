`timescale 1ns/1ps

module tb_bilin;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg in_valid = 0;
    reg [15:0] p00 = 0, p01 = 0, p10 = 0, p11 = 0;
    reg [11:0] dx = 0, dy = 0;
    wire out_valid;
    wire [15:0] pixel;
    reg [15:0] expected [0:127];
    reg expected_valid [0:127];
    integer n = 0;
    integer i;
    integer r, g, b;
    reg [63:0] w00, w01, w10, w11;

    bilin dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .p00(p00), .p01(p01), .p10(p10), .p11(p11),
        .dx(dx), .dy(dy), .out_valid(out_valid), .pixel(pixel)
    );

    always @(posedge clk) if (rst_n) begin
        w00 = (4096-dx) * (4096-dy);
        w01 = dx * (4096-dy);
        w10 = (4096-dx) * dy;
        w11 = dx * dy;
        r = (p00[15:11]*w00 + p01[15:11]*w01 +
             p10[15:11]*w10 + p11[15:11]*w11 + 8388608) >> 24;
        g = (p00[10:5]*w00 + p01[10:5]*w01 +
             p10[10:5]*w10 + p11[10:5]*w11 + 8388608) >> 24;
        b = (p00[4:0]*w00 + p01[4:0]*w01 +
             p10[4:0]*w10 + p11[4:0]*w11 + 8388608) >> 24;
        expected[n] = {r[4:0], g[5:0], b[4:0]};
        expected_valid[n] = in_valid;
        #1;
        if (n >= 2) begin
            if (out_valid !== expected_valid[n-2])
                $fatal(1, "bilin valid misalignment at %0d", n);
            if (out_valid && pixel !== expected[n-2])
                $fatal(1, "bilin data at %0d: got %h want %h",
                       n, pixel, expected[n-2]);
        end
        n = n + 1;
    end

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (i = 0; i < 60; i = i + 1) begin
            @(negedge clk);
            in_valid = (i % 7 != 0);
            p00 = $random; p01 = $random;
            p10 = $random; p11 = $random;
            dx = $random; dy = $random;
        end
        @(negedge clk); in_valid = 0;
        repeat (4) @(negedge clk);
        $display("PASS tb_bilin: 60 mixed RGB565 pixels and valid bubbles");
        $finish;
    end
endmodule
