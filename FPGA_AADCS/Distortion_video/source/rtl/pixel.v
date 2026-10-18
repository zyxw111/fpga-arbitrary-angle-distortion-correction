`timescale 1ns/1ps

// Project distorted normalized coordinates to Q12.12 source pixels.
// Latency: 1 clock. Throughput: 1 coordinate/clock.
module pixel #(
    parameter integer NORM_FRAC = 28
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire signed [63:0]       in_x,
    input  wire signed [63:0]       in_y,
    input  wire signed [31:0]       fx_q12,
    input  wire signed [31:0]       fy_q12,
    input  wire signed [31:0]       cx_q12,
    input  wire signed [31:0]       cy_q12,
    output reg                      out_valid,
    output reg  signed [31:0]       map_x_q12,
    output reg  signed [31:0]       map_y_q12
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            map_x_q12 <= 32'sd0;
            map_y_q12 <= 32'sd0;
        end else begin
            out_valid <= in_valid;
            map_x_q12 <= round_shift(fx_q12 * in_x, NORM_FRAC) + cx_q12;
            map_y_q12 <= round_shift(fy_q12 * in_y, NORM_FRAC) + cy_q12;
        end
    end

endmodule
