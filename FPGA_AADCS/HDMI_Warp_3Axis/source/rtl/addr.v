`timescale 1ns/1ps

// Convert one Q12.12 source coordinate into four RGB565 pixel addresses.
// Invalid neighbours must be supplied as black by the memory-read stage.
// Fixed latency: one clock; throughput: one coordinate per clock.
module addr #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               in_valid,
    input  wire signed [31:0] map_x_q12,
    input  wire signed [31:0] map_y_q12,
    output reg                out_valid,
    output reg  [31:0]        a00,
    output reg  [31:0]        a01,
    output reg  [31:0]        a10,
    output reg  [31:0]        a11,
    output reg  [3:0]         mask,
    output reg  [11:0]        dx,
    output reg  [11:0]        dy
);
    wire signed [31:0] x0 = map_x_q12 >>> 12;
    wire signed [31:0] y0 = map_y_q12 >>> 12;
    wire x_ok  = (x0 >= 0) && (x0 < WIDTH);
    wire x1_ok = (x0 >= -1) && (x0 < WIDTH-1);
    wire y_ok  = (y0 >= 0) && (y0 < HEIGHT);
    wire y1_ok = (y0 >= -1) && (y0 < HEIGHT-1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            a00 <= 32'd0; a01 <= 32'd0;
            a10 <= 32'd0; a11 <= 32'd0;
            mask <= 4'd0;
            dx <= 12'd0; dy <= 12'd0;
        end else begin
            out_valid <= in_valid;
            dx <= map_x_q12[11:0];
            dy <= map_y_q12[11:0];
            mask <= {x1_ok && y1_ok, x_ok && y1_ok,
                     x1_ok && y_ok, x_ok && y_ok};
            a00 <= (x_ok && y_ok) ? y0 * WIDTH + x0 : 32'd0;
            a01 <= (x1_ok && y_ok) ? y0 * WIDTH + x0 + 1 : 32'd0;
            a10 <= (x_ok && y1_ok) ? (y0 + 1) * WIDTH + x0 : 32'd0;
            a11 <= (x1_ok && y1_ok) ? (y0 + 1) * WIDTH + x0 + 1 : 32'd0;
        end
    end
endmodule
