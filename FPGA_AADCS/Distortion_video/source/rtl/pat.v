`timescale 1ns/1ps

// Synthetic RGB565 video source. At 148.5 MHz, default 2200x1125 timing
// produces 1920x1080 active pixels at 60 frames/s. No backpressure is allowed.
module pat #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080,
    parameter integer H_TOTAL = 2200,
    parameter integer V_TOTAL = 1125
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    output reg         valid,
    output reg  [15:0] pixel,
    output reg  [11:0] x,
    output reg  [11:0] y,
    output reg         sof,
    output reg         sol,
    output reg  [31:0] frame_id
);
    reg [11:0] h_count;
    reg [11:0] v_count;
    reg [31:0] next_frame_id;
    reg [15:0] color;

    always @(*) begin
        if (h_count < WIDTH/8)       color = 16'hffff; // white
        else if (h_count < WIDTH/4)  color = 16'hffe0; // yellow
        else if (h_count < WIDTH*3/8) color = 16'h07ff; // cyan
        else if (h_count < WIDTH/2)  color = 16'h07e0; // green
        else if (h_count < WIDTH*5/8) color = 16'hf81f; // magenta
        else if (h_count < WIDTH*3/4) color = 16'hf800; // red
        else if (h_count < WIDTH*7/8) color = 16'h001f; // blue
        else                          color = 16'h0000; // black
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 12'd0;
            v_count <= 12'd0;
            next_frame_id <= 32'd0;
            frame_id <= 32'd0;
            valid <= 1'b0;
            pixel <= 16'd0;
            x <= 12'd0;
            y <= 12'd0;
            sof <= 1'b0;
            sol <= 1'b0;
        end else if (!enable) begin
            h_count <= 12'd0;
            v_count <= 12'd0;
            next_frame_id <= 32'd0;
            frame_id <= 32'd0;
            valid <= 1'b0;
            sof <= 1'b0;
            sol <= 1'b0;
        end else begin
            valid <= (h_count < WIDTH) && (v_count < HEIGHT);
            pixel <= color;
            x <= h_count;
            y <= v_count;
            sof <= (h_count == 0) && (v_count == 0);
            sol <= (h_count == 0) && (v_count < HEIGHT);
            frame_id <= next_frame_id;

            if (h_count == H_TOTAL-1) begin
                h_count <= 12'd0;
                if (v_count == V_TOTAL-1) begin
                    v_count <= 12'd0;
                    next_frame_id <= next_frame_id + 32'd1;
                end else begin
                    v_count <= v_count + 12'd1;
                end
            end else begin
                h_count <= h_count + 12'd1;
            end
        end
    end
endmodule
