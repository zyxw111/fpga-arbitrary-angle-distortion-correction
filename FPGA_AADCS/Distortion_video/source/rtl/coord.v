`timescale 1ns/1ps

// Connect the four arithmetic stages into one 9-clock coordinate mapper.
module coord #(
    parameter integer PIXEL_FRAC = 12,
    parameter integer NORM_FRAC  = 28,
    parameter integer COEFF_FRAC = 30
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire [11:0]              pix_x,
    input  wire [11:0]              pix_y,
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
    output wire signed [31:0]       map_x_q12,
    output wire signed [31:0]       map_y_q12
);

    wire n_valid;
    wire r_valid;
    wire d_valid;
    wire signed [63:0] n_x, n_y;
    wire signed [63:0] r_x, r_y, r_x2, r_y2, r_xy, r_r2, r_scale;
    wire signed [63:0] d_x, d_y;

    norm #(
        .PIXEL_FRAC(PIXEL_FRAC),
        .NORM_FRAC(NORM_FRAC),
        .COEFF_FRAC(COEFF_FRAC)
    ) u_norm (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .pix_x(pix_x), .pix_y(pix_y),
        .cx_q12(cx_q12), .cy_q12(cy_q12),
        .inv_fx_q30(inv_fx_q30), .inv_fy_q30(inv_fy_q30),
        .out_valid(n_valid), .x_q28(n_x), .y_q28(n_y)
    );

    radial #(
        .NORM_FRAC(NORM_FRAC),
        .COEFF_FRAC(COEFF_FRAC)
    ) u_radial (
        .clk(clk), .rst_n(rst_n), .in_valid(n_valid),
        .in_x(n_x), .in_y(n_y), .k1_q30(k1_q30), .k2_q30(k2_q30),
        .out_valid(r_valid), .out_x(r_x), .out_y(r_y),
        .out_x2(r_x2), .out_y2(r_y2), .out_xy(r_xy),
        .out_r2(r_r2), .out_radial(r_scale)
    );

    distort #(
        .COEFF_FRAC(COEFF_FRAC)
    ) u_distort (
        .clk(clk), .rst_n(rst_n), .in_valid(r_valid),
        .in_x(r_x), .in_y(r_y), .in_x2(r_x2), .in_y2(r_y2),
        .in_xy(r_xy), .in_r2(r_r2), .in_radial(r_scale),
        .p1_q30(p1_q30), .p2_q30(p2_q30),
        .out_valid(d_valid), .out_x(d_x), .out_y(d_y)
    );

    pixel #(
        .NORM_FRAC(NORM_FRAC)
    ) u_pixel (
        .clk(clk), .rst_n(rst_n), .in_valid(d_valid),
        .in_x(d_x), .in_y(d_y),
        .fx_q12(fx_q12), .fy_q12(fy_q12),
        .cx_q12(cx_q12), .cy_q12(cy_q12),
        .out_valid(out_valid),
        .map_x_q12(map_x_q12), .map_y_q12(map_y_q12)
    );

endmodule
