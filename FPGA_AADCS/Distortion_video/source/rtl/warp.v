`timescale 1ns/1ps

// Geometry + four-neighbour RGB565 resampler interface.
// The external frame reader must return one response per request, in order,
// carrying the request's dx/dy/mask/x/y metadata alongside its four pixels.
// It must sustain one response per clock for 1080p60. This module does NOT
// implement DDR3 caching, burst scheduling, clock-domain crossing, or PCIe.
module warp #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     in_valid,
    input  wire [11:0]              in_x,
    input  wire [11:0]              in_y,
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
    output wire                     rd_valid,
    output wire [31:0]              rd_a00,
    output wire [31:0]              rd_a01,
    output wire [31:0]              rd_a10,
    output wire [31:0]              rd_a11,
    output wire [3:0]               rd_mask,
    output wire [11:0]              rd_dx,
    output wire [11:0]              rd_dy,
    output wire [11:0]              rd_x,
    output wire [11:0]              rd_y,
    input  wire                     rsp_valid,
    input  wire [15:0]              rsp_p00,
    input  wire [15:0]              rsp_p01,
    input  wire [15:0]              rsp_p10,
    input  wire [15:0]              rsp_p11,
    input  wire [3:0]               rsp_mask,
    input  wire [11:0]              rsp_dx,
    input  wire [11:0]              rsp_dy,
    input  wire [11:0]              rsp_x,
    input  wire [11:0]              rsp_y,
    output wire                     out_valid,
    output wire [15:0]              out_pixel,
    output wire [11:0]              out_x,
    output wire [11:0]              out_y
);
    wire map_valid;
    wire signed [31:0] map_x_q12, map_y_q12;
    reg [11:0] req_x_pipe [0:9];
    reg [11:0] req_y_pipe [0:9];
    reg [11:0] rsp_x_pipe [0:2];
    reg [11:0] rsp_y_pipe [0:2];
    integer i;

    coord u_coord (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .pix_x(in_x), .pix_y(in_y),
        .fx_q12(fx_q12), .fy_q12(fy_q12),
        .cx_q12(cx_q12), .cy_q12(cy_q12),
        .inv_fx_q30(inv_fx_q30), .inv_fy_q30(inv_fy_q30),
        .k1_q30(k1_q30), .k2_q30(k2_q30),
        .p1_q30(p1_q30), .p2_q30(p2_q30),
        .out_valid(map_valid),
        .map_x_q12(map_x_q12), .map_y_q12(map_y_q12)
    );

    addr #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)) u_addr (
        .clk(clk), .rst_n(rst_n), .in_valid(map_valid),
        .map_x_q12(map_x_q12), .map_y_q12(map_y_q12),
        .out_valid(rd_valid), .a00(rd_a00), .a01(rd_a01),
        .a10(rd_a10), .a11(rd_a11), .mask(rd_mask),
        .dx(rd_dx), .dy(rd_dy)
    );

    bilin u_bilin (
        .clk(clk), .rst_n(rst_n), .in_valid(rsp_valid),
        .p00(rsp_mask[0] ? rsp_p00 : 16'd0),
        .p01(rsp_mask[1] ? rsp_p01 : 16'd0),
        .p10(rsp_mask[2] ? rsp_p10 : 16'd0),
        .p11(rsp_mask[3] ? rsp_p11 : 16'd0),
        .dx(rsp_dx), .dy(rsp_dy),
        .out_valid(out_valid), .pixel(out_pixel)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 10; i = i + 1) begin
                req_x_pipe[i] <= 12'd0;
                req_y_pipe[i] <= 12'd0;
            end
            for (i = 0; i < 3; i = i + 1) begin
                rsp_x_pipe[i] <= 12'd0;
                rsp_y_pipe[i] <= 12'd0;
            end
        end else begin
            req_x_pipe[0] <= in_x;
            req_y_pipe[0] <= in_y;
            for (i = 1; i < 10; i = i + 1) begin
                req_x_pipe[i] <= req_x_pipe[i-1];
                req_y_pipe[i] <= req_y_pipe[i-1];
            end
            rsp_x_pipe[0] <= rsp_x;
            rsp_y_pipe[0] <= rsp_y;
            for (i = 1; i < 3; i = i + 1) begin
                rsp_x_pipe[i] <= rsp_x_pipe[i-1];
                rsp_y_pipe[i] <= rsp_y_pipe[i-1];
            end
        end
    end
    assign rd_x = req_x_pipe[9];
    assign rd_y = req_y_pipe[9];
    assign out_x = rsp_x_pipe[2];
    assign out_y = rsp_y_pipe[2];
endmodule
