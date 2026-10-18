`timescale 1ns/1ps

// Build x^2, y^2, xy, r^2 and the Brown radial scale factor.
// Latency: 4 clocks. Throughput: 1 coordinate/clock.
module radial #(
    parameter integer NORM_FRAC  = 28,
    parameter integer COEFF_FRAC = 30
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire signed [63:0]       in_x,
    input  wire signed [63:0]       in_y,
    input  wire signed [31:0]       k1_q30,
    input  wire signed [31:0]       k2_q30,
    output wire                     out_valid,
    output reg  signed [63:0]       out_x,
    output reg  signed [63:0]       out_y,
    output reg  signed [63:0]       out_x2,
    output reg  signed [63:0]       out_y2,
    output reg  signed [63:0]       out_xy,
    output reg  signed [63:0]       out_r2,
    output reg  signed [63:0]       out_radial
);

    function signed [63:0] round_shift;
        input signed [63:0] value;
        input integer bits;
        reg signed [63:0] half;
        begin
            half = 64'sd1 <<< (bits - 1);
            if (value >= 0)
                round_shift = (value + half) >>> bits;
            else
                round_shift = -(((-value) + half) >>> bits);
        end
    endfunction

    reg [3:0] valid_pipe;
    reg signed [63:0] a_x, a_y, a_x2, a_y2, a_xy;
    reg signed [63:0] b_x, b_y, b_x2, b_y2, b_xy, b_r2;
    reg signed [63:0] c_x, c_y, c_x2, c_y2, c_xy, c_r2;
    reg signed [63:0] c_r4, c_k1r2;

    assign out_valid = valid_pipe[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 4'd0;
            out_x <= 64'sd0;
            out_y <= 64'sd0;
            out_x2 <= 64'sd0;
            out_y2 <= 64'sd0;
            out_xy <= 64'sd0;
            out_r2 <= 64'sd0;
            out_radial <= 64'sd0;
        end else begin
            valid_pipe <= {valid_pipe[2:0], in_valid};

            a_x <= in_x;
            a_y <= in_y;
            a_x2 <= round_shift(in_x * in_x, NORM_FRAC);
            a_y2 <= round_shift(in_y * in_y, NORM_FRAC);
            a_xy <= round_shift(in_x * in_y, NORM_FRAC);

            b_x <= a_x;
            b_y <= a_y;
            b_x2 <= a_x2;
            b_y2 <= a_y2;
            b_xy <= a_xy;
            b_r2 <= a_x2 + a_y2;

            c_x <= b_x;
            c_y <= b_y;
            c_x2 <= b_x2;
            c_y2 <= b_y2;
            c_xy <= b_xy;
            c_r2 <= b_r2;
            c_r4 <= round_shift(b_r2 * b_r2, NORM_FRAC);
            c_k1r2 <= round_shift(k1_q30 * b_r2, NORM_FRAC);

            out_x <= c_x;
            out_y <= c_y;
            out_x2 <= c_x2;
            out_y2 <= c_y2;
            out_xy <= c_xy;
            out_r2 <= c_r2;
            out_radial <= (64'sd1 <<< COEFF_FRAC)
                        + c_k1r2
                        + round_shift(k2_q30 * c_r4, NORM_FRAC);
        end
    end

endmodule
