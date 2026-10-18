`timescale 1ns/1ps

// Isolated internal-video stress top. This is NOT the PCIe/DDR product top.
// Supply an actual 148.5 MHz pix_clk and a separate 125 MHz tx_clk in
// implementation; the 25 MHz board oscillator alone cannot drive these.
module vtop #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080,
    parameter integer H_TOTAL = 2200,
    parameter integer V_TOTAL = 1125,
    // USER SETTINGS: 0=color bars; 1=synthetic distorted camera demo.
    parameter integer DEMO_GROUP = 0,
    // For group 1: 0=distorted input; 1=actual warp corrected output.
    parameter integer DEMO_VIEW = 1,
    parameter integer FIFO_ADDR_BITS = 9
)(
    input  wire        pix_clk,
    input  wire        tx_clk,
    input  wire        rst_n,
    input  wire        enable,
    output reg  [31:0] beat_count,
    output reg  [31:0] frame_count,
    output reg  [31:0] hash,
    output wire        overflow
);
    wire tx_valid, tx_sof, tx_eof;
    wire [127:0] tx_data;
    wire [31:0] tx_frame_id;
    wire overflow_pix;
    reg overflow_s1, overflow_s2;

    stream #(
        .WIDTH(WIDTH), .HEIGHT(HEIGHT),
        .H_TOTAL(H_TOTAL), .V_TOTAL(V_TOTAL),
        .FIFO_ADDR_BITS(FIFO_ADDR_BITS),
        .DEMO_GROUP(DEMO_GROUP), .DEMO_VIEW(DEMO_VIEW)
    ) u_stream (
        .pix_clk(pix_clk), .tx_clk(tx_clk),
        .rst_n(rst_n), .enable(enable),
        .tx_valid(tx_valid), .tx_ready(1'b1),
        .tx_data(tx_data), .tx_sof(tx_sof),
        .tx_eof(tx_eof), .tx_frame_id(tx_frame_id),
        .overflow(overflow_pix)
    );

    always @(posedge tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            beat_count <= 32'd0;
            frame_count <= 32'd0;
            hash <= 32'd0;
            overflow_s1 <= 1'b0;
            overflow_s2 <= 1'b0;
        end else begin
            overflow_s1 <= overflow_pix;
            overflow_s2 <= overflow_s1;
            if (tx_valid) begin
                beat_count <= beat_count + 32'd1;
                hash <= {hash[30:0], hash[31]} ^
                        tx_data[31:0] ^ tx_data[63:32] ^
                        tx_data[95:64] ^ tx_data[127:96] ^
                        tx_frame_id ^ {30'd0, tx_eof, tx_sof};
                if (tx_eof)
                    frame_count <= frame_count + 32'd1;
            end
        end
    end
    assign overflow = overflow_s2;
endmodule
