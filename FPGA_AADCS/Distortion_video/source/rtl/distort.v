`timescale 1ns/1ps

// Apply radial and tangential terms to normalized coordinates.
// Latency: 2 clocks. Throughput: 1 coordinate/clock.
module distort #(
    parameter integer COEFF_FRAC = 30
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire signed [63:0]       in_x,
    input  wire signed [63:0]       in_y,
    input  wire signed [63:0]       in_x2,
    input  wire signed [63:0]       in_y2,
    input  wire signed [63:0]       in_xy,
    input  wire signed [63:0]       in_r2,
    input  wire signed [63:0]       in_radial,
    input  wire signed [31:0]       p1_q30,
    input  wire signed [31:0]       p2_q30,
    output wire                     out_valid,
    output reg  signed [63:0]       out_x,
    output reg  signed [63:0]       out_y
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
    reg signed [63:0] xr, yr, p1xy, p2xy, p2rx, p1ry;

    assign out_valid = valid_pipe[1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 2'd0;
            out_x <= 64'sd0;
            out_y <= 64'sd0;
        end else begin
            valid_pipe <= {valid_pipe[0], in_valid};

            xr <= round_shift(in_x * in_radial, COEFF_FRAC);
            yr <= round_shift(in_y * in_radial, COEFF_FRAC);
            p1xy <= round_shift(p1_q30 * in_xy, COEFF_FRAC);
            p2xy <= round_shift(p2_q30 * in_xy, COEFF_FRAC);
            p2rx <= round_shift(p2_q30 * (in_r2 + (in_x2 <<< 1)),
                                COEFF_FRAC);
            p1ry <= round_shift(p1_q30 * (in_r2 + (in_y2 <<< 1)),
                                COEFF_FRAC);

            out_x <= xr + (p1xy <<< 1) + p2rx;
            out_y <= yr + p1ry + (p2xy <<< 1);
        end
    end

endmodule
