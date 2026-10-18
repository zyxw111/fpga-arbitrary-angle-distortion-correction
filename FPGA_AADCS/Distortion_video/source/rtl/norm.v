`timescale 1ns/1ps

// Convert integer output pixels to Q3.28 normalized camera coordinates.
// Latency: 2 clocks. Throughput: 1 coordinate/clock.
module norm #(
    parameter integer PIXEL_FRAC = 12,
    parameter integer NORM_FRAC  = 28,
    parameter integer COEFF_FRAC = 30
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire [11:0]              pix_x,
    input  wire [11:0]              pix_y,
    input  wire signed [31:0]       cx_q12,
    input  wire signed [31:0]       cy_q12,
    input  wire signed [31:0]       inv_fx_q30,
    input  wire signed [31:0]       inv_fy_q30,
    output wire                     out_valid,
    output reg  signed [63:0]       x_q28,
    output reg  signed [63:0]       y_q28
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

    reg [1:0] valid_pipe;
    reg signed [63:0] delta_x;
    reg signed [63:0] delta_y;

    assign out_valid = valid_pipe[1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 2'd0;
            x_q28 <= 64'sd0;
            y_q28 <= 64'sd0;
        end else begin
            valid_pipe <= {valid_pipe[0], in_valid};
            delta_x <= ($signed({1'b0, pix_x}) <<< PIXEL_FRAC) - cx_q12;
            delta_y <= ($signed({1'b0, pix_y}) <<< PIXEL_FRAC) - cy_q12;
            x_q28 <= round_shift(delta_x * inv_fx_q30,
                                 PIXEL_FRAC + COEFF_FRAC - NORM_FRAC);
            y_q28 <= round_shift(delta_y * inv_fy_q30,
                                 PIXEL_FRAC + COEFF_FRAC - NORM_FRAC);
        end
    end

endmodule
