`timescale 1ns/1ps

// Standalone synthesis top for coordinate-pipeline resource/timing checks.
module top (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire [11:0]              pix_x,
    input  wire [11:0]              pix_y,
    input  wire                     cfg_we,
    input  wire [3:0]               cfg_addr,
    input  wire signed [31:0]       cfg_data,
    output wire                     out_valid,
    output wire signed [31:0]       map_x_q12,
    output wire signed [31:0]       map_y_q12
);

    wire signed [31:0] fx_q12;
    wire signed [31:0] fy_q12;
    wire signed [31:0] cx_q12;
    wire signed [31:0] cy_q12;
    wire signed [31:0] inv_fx_q30;
    wire signed [31:0] inv_fy_q30;
    wire signed [31:0] k1_q30;
    wire signed [31:0] k2_q30;
    wire signed [31:0] p1_q30;
    wire signed [31:0] p2_q30;

    cfg u_cfg (
        .clk(clk), .rst_n(rst_n),
        .wr_en(cfg_we), .wr_addr(cfg_addr), .wr_data(cfg_data),
        .fx_q12(fx_q12), .fy_q12(fy_q12),
        .cx_q12(cx_q12), .cy_q12(cy_q12),
        .inv_fx_q30(inv_fx_q30), .inv_fy_q30(inv_fy_q30),
        .k1_q30(k1_q30), .k2_q30(k2_q30),
        .p1_q30(p1_q30), .p2_q30(p2_q30)
    );

    coord u_coord (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .pix_x(pix_x), .pix_y(pix_y),
        .fx_q12(fx_q12), .fy_q12(fy_q12),
        .cx_q12(cx_q12), .cy_q12(cy_q12),
        .inv_fx_q30(inv_fx_q30), .inv_fy_q30(inv_fy_q30),
        .k1_q30(k1_q30), .k2_q30(k2_q30),
        .p1_q30(p1_q30), .p2_q30(p2_q30),
        .out_valid(out_valid),
        .map_x_q12(map_x_q12), .map_y_q12(map_y_q12)
    );

endmodule
