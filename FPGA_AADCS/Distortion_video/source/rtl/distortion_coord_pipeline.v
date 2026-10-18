`timescale 1ns/1ps

// Brown-Conrady output-to-input coordinate mapper.
//
// Verilog-2001 synthesis version. The arithmetic and rounding points are kept
// identical to distortion_coord_pipeline.sv, which remains the verified
// SystemVerilog reference implementation.
//
// Latency: 9 rising clock edges from an accepted input to out_valid.
// Throughput: one coordinate per clock after the pipeline is filled.
// Configuration inputs must remain stable while a frame is being processed.
module distortion_coord_pipeline #(
    parameter integer PIXEL_FRAC = 12,
    parameter integer NORM_FRAC  = 28,
    parameter integer COEFF_FRAC = 30
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire [11:0]              out_x,
    input  wire [11:0]              out_y,
    input  wire signed [31:0]       fx_q12,
    input  wire signed [31:0]       fy_q12,
    input  wire signed [31:0]       cx_q12,
    input  wire signed [31:0]       cy_q12,
    input  wire signed [31:0]       inv_fx_q30,
    input  wire signed [31:0]       inv_fy_q30,
    input  wire signed [31:0]       k1_q30,
    input  wire signed [31:0]       k2_q30,
    input  wire signed [31:0]       p1_q30,
    input  wire signed [31:0]       p2_q30,
    output wire                     out_valid,
    output reg signed [31:0]        map_x_q12,
    output reg signed [31:0]        map_y_q12
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

    reg [8:0] valid_pipe;
    reg signed [63:0] s1_du;
    reg signed [63:0] s1_dv;
    reg signed [63:0] s2_x;
    reg signed [63:0] s2_y;
    reg signed [63:0] s3_x;
    reg signed [63:0] s3_y;
    reg signed [63:0] s3_x2;
    reg signed [63:0] s3_y2;
    reg signed [63:0] s3_xy;
    reg signed [63:0] s4_x;
    reg signed [63:0] s4_y;
    reg signed [63:0] s4_x2;
    reg signed [63:0] s4_y2;
    reg signed [63:0] s4_xy;
    reg signed [63:0] s4_r2;
    reg signed [63:0] s5_x;
    reg signed [63:0] s5_y;
    reg signed [63:0] s5_x2;
    reg signed [63:0] s5_y2;
    reg signed [63:0] s5_xy;
    reg signed [63:0] s5_r2;
    reg signed [63:0] s5_r4;
    reg signed [63:0] s5_k1r2;
    reg signed [63:0] s6_x;
    reg signed [63:0] s6_y;
    reg signed [63:0] s6_x2;
    reg signed [63:0] s6_y2;
    reg signed [63:0] s6_xy;
    reg signed [63:0] s6_r2;
    reg signed [63:0] s6_radial;
    reg signed [63:0] s7_xr;
    reg signed [63:0] s7_yr;
    reg signed [63:0] s7_p1xy;
    reg signed [63:0] s7_p2xy;
    reg signed [63:0] s7_p2rx;
    reg signed [63:0] s7_p1ry;
    reg signed [63:0] s8_xd;
    reg signed [63:0] s8_yd;

    assign out_valid = valid_pipe[8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 9'd0;
            map_x_q12 <= 32'sd0;
            map_y_q12 <= 32'sd0;
        end else begin
            valid_pipe <= {valid_pipe[7:0], in_valid};

            s1_du <= ($signed({1'b0, out_x}) <<< PIXEL_FRAC) - cx_q12;
            s1_dv <= ($signed({1'b0, out_y}) <<< PIXEL_FRAC) - cy_q12;

            s2_x <= round_shift(s1_du * inv_fx_q30,
                                PIXEL_FRAC + COEFF_FRAC - NORM_FRAC);
            s2_y <= round_shift(s1_dv * inv_fy_q30,
                                PIXEL_FRAC + COEFF_FRAC - NORM_FRAC);

            s3_x <= s2_x;
            s3_y <= s2_y;
            s3_x2 <= round_shift(s2_x * s2_x, NORM_FRAC);
            s3_y2 <= round_shift(s2_y * s2_y, NORM_FRAC);
            s3_xy <= round_shift(s2_x * s2_y, NORM_FRAC);

            s4_x <= s3_x;
            s4_y <= s3_y;
            s4_x2 <= s3_x2;
            s4_y2 <= s3_y2;
            s4_xy <= s3_xy;
            s4_r2 <= s3_x2 + s3_y2;

            s5_x <= s4_x;
            s5_y <= s4_y;
            s5_x2 <= s4_x2;
            s5_y2 <= s4_y2;
            s5_xy <= s4_xy;
            s5_r2 <= s4_r2;
            s5_r4 <= round_shift(s4_r2 * s4_r2, NORM_FRAC);
            s5_k1r2 <= round_shift(k1_q30 * s4_r2, NORM_FRAC);

            s6_x <= s5_x;
            s6_y <= s5_y;
            s6_x2 <= s5_x2;
            s6_y2 <= s5_y2;
            s6_xy <= s5_xy;
            s6_r2 <= s5_r2;
            s6_radial <= (64'sd1 <<< COEFF_FRAC)
                       + s5_k1r2
                       + round_shift(k2_q30 * s5_r4, NORM_FRAC);

            s7_xr <= round_shift(s6_x * s6_radial, COEFF_FRAC);
            s7_yr <= round_shift(s6_y * s6_radial, COEFF_FRAC);
            s7_p1xy <= round_shift(p1_q30 * s6_xy, COEFF_FRAC);
            s7_p2xy <= round_shift(p2_q30 * s6_xy, COEFF_FRAC);
            s7_p2rx <= round_shift(p2_q30 * (s6_r2 + (s6_x2 <<< 1)),
                                   COEFF_FRAC);
            s7_p1ry <= round_shift(p1_q30 * (s6_r2 + (s6_y2 <<< 1)),
                                   COEFF_FRAC);

            s8_xd <= s7_xr + (s7_p1xy <<< 1) + s7_p2rx;
            s8_yd <= s7_yr + s7_p1ry + (s7_p2xy <<< 1);

            map_x_q12 <= round_shift(fx_q12 * s8_xd, NORM_FRAC) + cx_q12;
            map_y_q12 <= round_shift(fy_q12 * s8_yd, NORM_FRAC) + cy_q12;
        end
    end

endmodule
