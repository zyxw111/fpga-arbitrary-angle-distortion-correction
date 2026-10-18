`timescale 1ns/1ps

// RGB565 four-neighbour bilinear interpolation, Q0.12 weights.
// Missing neighbours must be passed as zero. No backpressure interface.
// Three registered arithmetic stages; output follows input by three clocks.
module bilin (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        in_valid,
    input  wire [15:0] p00,
    input  wire [15:0] p01,
    input  wire [15:0] p10,
    input  wire [15:0] p11,
    input  wire [11:0] dx,
    input  wire [11:0] dy,
    output reg         out_valid,
    output reg  [15:0] pixel
);
    wire [12:0] wx0 = 13'd4096 - {1'b0, dx};
    wire [12:0] wx1 = {1'b0, dx};
    reg [12:0] wy0_s1, wy1_s1;
    reg [17:0] r0_s1, r1_s1, g0_s1, g1_s1, b0_s1, b1_s1;
    reg valid_s1, valid_s2;
    reg [29:0] r_s2, g_s2, b_s2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_s1 <= 1'b0;
            valid_s2 <= 1'b0;
            out_valid <= 1'b0;
            wy0_s1 <= 13'd0; wy1_s1 <= 13'd0;
            r0_s1 <= 18'd0; r1_s1 <= 18'd0;
            g0_s1 <= 18'd0; g1_s1 <= 18'd0;
            b0_s1 <= 18'd0; b1_s1 <= 18'd0;
            r_s2 <= 30'd0; g_s2 <= 30'd0; b_s2 <= 30'd0;
            pixel <= 16'd0;
        end else begin
            valid_s1 <= in_valid;
            valid_s2 <= valid_s1;
            wy0_s1 <= 13'd4096 - {1'b0, dy};
            wy1_s1 <= {1'b0, dy};
            r0_s1 <= p00[15:11] * wx0 + p01[15:11] * wx1;
            r1_s1 <= p10[15:11] * wx0 + p11[15:11] * wx1;
            g0_s1 <= p00[10:5] * wx0 + p01[10:5] * wx1;
            g1_s1 <= p10[10:5] * wx0 + p11[10:5] * wx1;
            b0_s1 <= p00[4:0] * wx0 + p01[4:0] * wx1;
            b1_s1 <= p10[4:0] * wx0 + p11[4:0] * wx1;

            r_s2 <= r0_s1 * wy0_s1 + r1_s1 * wy1_s1 + 30'd8388608;
            g_s2 <= g0_s1 * wy0_s1 + g1_s1 * wy1_s1 + 30'd8388608;
            b_s2 <= b0_s1 * wy0_s1 + b1_s1 * wy1_s1 + 30'd8388608;
            pixel <= {r_s2[28:24], g_s2[29:24], b_s2[28:24]};
            out_valid <= valid_s2;
        end
    end
endmodule
