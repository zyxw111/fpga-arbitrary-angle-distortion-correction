// Synchronous 128-bit payload source for the Pango DMA read interface.
// Advances only on an accepted read; host descriptors do not reset the stream.
module pcie_test_source #(
    parameter integer WIDTH = 640,
    parameter integer HEIGHT = 400,
    parameter integer SWAP_RGB565_BYTES = 1
)(
    input wire clk,
    input wire rst_n,
    input wire ramp_mode,
    input wire read_enable,
    output reg [127:0] read_data
);
    reg [15:0] x;
    reg [15:0] y;
    reg [31:0] ramp_word;
    wire [127:0] color_word;
    genvar lane;
    generate for (lane = 0; lane < 8; lane = lane + 1) begin : pixels
        wire [15:0] px = x + lane;
        wire [15:0] pixel = test_pixel(px, y);
        assign color_word[lane*16 +: 16] = SWAP_RGB565_BYTES ?
            {pixel[7:0], pixel[15:8]} : pixel;
    end endgenerate

    function [15:0] test_pixel;
        input [15:0] px;
        input [15:0] py;
        begin
            // Bottom quarter is a ramp: unlike eight flat bars alone, it also
            // passes the existing viewer's pixel-variety signal heuristic.
            if (py >= HEIGHT * 3 / 4)
                test_pixel = {px[4:0], px[5:0], px[4:0]};
            else if (px < WIDTH * 1 / 8) test_pixel = 16'hffff;
            else if (px < WIDTH * 2 / 8) test_pixel = 16'hffe0;
            else if (px < WIDTH * 3 / 8) test_pixel = 16'h07ff;
            else if (px < WIDTH * 4 / 8) test_pixel = 16'h07e0;
            else if (px < WIDTH * 5 / 8) test_pixel = 16'hf81f;
            else if (px < WIDTH * 6 / 8) test_pixel = 16'hf800;
            else if (px < WIDTH * 7 / 8) test_pixel = 16'h001f;
            else test_pixel = 16'h0000;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x <= 0;
            y <= 0;
            ramp_word <= 0;
            read_data <= 0;
        end else if (read_enable) begin
            if (ramp_mode) begin
                read_data <= {ramp_word + 32'd3, ramp_word + 32'd2,
                              ramp_word + 32'd1, ramp_word};
                ramp_word <= ramp_word + 32'd4;
            end else if (x == 0 && y == 0) begin
                // Raw, unswapped status header expected by fpga_find_header_line.
                read_data <= {32'h3568cafe, 32'h5a000000,
                              32'ha55a0000, 32'hd5000001};
            end else begin
                read_data <= color_word;
            end
            if (x >= WIDTH - 8) begin
                x <= 0;
                if (y >= HEIGHT - 1) y <= 0;
                else y <= y + 1'b1;
            end else x <= x + 16'd8;
        end
    end
endmodule
