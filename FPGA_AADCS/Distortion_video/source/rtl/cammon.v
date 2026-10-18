`timescale 1ns/1ps

// Count raw 8-bit DVP bytes and HREF lines between active-high VSYNC pulses.
// A complete RGB565 frame has WIDTH*2 bytes/line and HEIGHT lines.
module cammon #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080
)(
    input  wire        pclk,
    input  wire        rst_n,
    input  wire        vsync,
    input  wire        href,
    output reg         frame_toggle,
    output reg         last_bad,
    output reg  [11:0] last_lines,
    output reg  [31:0] good_frames,
    output reg  [31:0] bad_frames
);
    reg vsync_d, href_d;
    reg have_frame;
    reg frame_bad;
    reg [12:0] byte_count;
    reg [11:0] line_count;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d <= 1'b0;
            href_d <= 1'b0;
            have_frame <= 1'b0;
            frame_bad <= 1'b0;
            byte_count <= 13'd0;
            line_count <= 12'd0;
            frame_toggle <= 1'b0;
            last_bad <= 1'b0;
            last_lines <= 12'd0;
            good_frames <= 32'd0;
            bad_frames <= 32'd0;
        end else begin
            vsync_d <= vsync;
            href_d <= href;
            if (vsync && !vsync_d) begin
                frame_toggle <= ~frame_toggle;
                if (have_frame) begin
                    last_lines <= line_count;
                    last_bad <= frame_bad || (line_count != HEIGHT);
                    if (frame_bad || (line_count != HEIGHT))
                        bad_frames <= bad_frames + 32'd1;
                    else
                        good_frames <= good_frames + 32'd1;
                end
                have_frame <= 1'b1;
                frame_bad <= 1'b0;
                byte_count <= 13'd0;
                line_count <= 12'd0;
            end else if (have_frame) begin
                if (href && !vsync) begin
                    if (byte_count != 13'h1fff)
                        byte_count <= byte_count + 13'd1;
                    else
                        frame_bad <= 1'b1;
                end else if (href_d && !href) begin
                    if (byte_count != WIDTH*2)
                        frame_bad <= 1'b1;
                    byte_count <= 13'd0;
                    if (line_count != 12'hfff)
                        line_count <= line_count + 12'd1;
                    else
                        frame_bad <= 1'b1;
                end
            end
        end
    end
endmodule
