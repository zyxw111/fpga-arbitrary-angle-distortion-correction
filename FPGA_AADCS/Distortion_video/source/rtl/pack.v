`timescale 1ns/1ps

// Pack eight consecutive RGB565 pixels into one 128-bit little-lane word.
// The first pixel occupies data[15:0]. One clock domain, ready/valid on
// both sides. Source must hold its pixel and markers while !in_ready.
// A free-running DVP/pattern source requires an elastic FIFO before this.
module pack (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         in_valid,
    output wire         in_ready,
    input  wire [15:0]  in_pixel,
    input  wire         in_sof,
    input  wire         in_eof,
    input  wire [31:0]  in_frame_id,
    output reg          out_valid,
    input  wire         out_ready,
    output reg  [127:0] out_data,
    output reg          out_sof,
    output reg          out_eof,
    output reg  [31:0]  out_frame_id,
    output reg          frame_error
);
    reg [2:0] count;
    reg [111:0] partial;
    reg first_beat;
    wire accept = in_valid && in_ready;

    // A complete output beat can replace a consumed one in the same cycle.
    assign in_ready = (count != 3'd7) || !out_valid || out_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 3'd0;
            partial <= 112'd0;
            first_beat <= 1'b0;
            out_valid <= 1'b0;
            out_data <= 128'd0;
            out_sof <= 1'b0;
            out_eof <= 1'b0;
            out_frame_id <= 32'd0;
            frame_error <= 1'b0;
        end else begin
            if (out_valid && out_ready)
                out_valid <= 1'b0;

            if (accept) begin
                if (in_sof && count != 3'd0) begin
                    // Previous frame ended mid-word. Discard its partial data.
                    frame_error <= 1'b1;
                    partial[15:0] <= in_pixel;
                    count <= 3'd1;
                    first_beat <= 1'b1;
                end else if (count == 3'd7) begin
                    out_data <= {in_pixel, partial};
                    out_sof <= first_beat || in_sof;
                    out_eof <= in_eof;
                    out_frame_id <= in_frame_id;
                    out_valid <= 1'b1;
                    count <= 3'd0;
                    first_beat <= 1'b0;
                end else begin
                    partial[count*16 +: 16] <= in_pixel;
                    count <= count + 3'd1;
                    if (in_sof)
                        first_beat <= 1'b1;
                end

                if (in_eof && count != 3'd7) begin
                    // Every supported frame size must be a multiple of eight.
                    frame_error <= 1'b1;
                    count <= 3'd0;
                    first_beat <= 1'b0;
                end
            end
        end
    end
endmodule
