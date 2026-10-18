`timescale 1ns/1ps

// Internal RGB565 test video -> 128-bit cross-clock stream.
// No PCIe TLP generation or host-buffer DMA is performed here.
// overflow is sticky in pix_clk domain; on overflow, stop the source
// and discard the incomplete frame at the receiver before reset/restart.
module stream #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080,
    parameter integer H_TOTAL = 2200,
    parameter integer V_TOTAL = 1125,
    parameter integer FIFO_ADDR_BITS = 9,
    parameter integer DEMO_GROUP = 0,
    parameter integer DEMO_VIEW = 1,
    parameter integer DYNAMIC_MODE = 0
)(
    input  wire         pix_clk,
    input  wire         tx_clk,
    input  wire         rst_n,
    input  wire         enable,
    input  wire [1:0]   mode,
    output wire         tx_valid,
    input  wire         tx_ready,
    output wire [127:0] tx_data,
    output wire         tx_sof,
    output wire         tx_eof,
    output wire [31:0]  tx_frame_id,
    output reg          overflow
);
    wire pix_valid, pix_sof, pix_sol;
    wire [15:0] pix_data;
    wire [11:0] pix_x, pix_y;
    wire [31:0] pix_frame_id;
    wire pack_ready, pack_valid, pack_sof, pack_eof, pack_error;
    wire [127:0] pack_data;
    wire [31:0] pack_frame_id;
    wire fifo_ready;
    wire [161:0] fifo_data;

    generate if(DYNAMIC_MODE) begin:runtime_source
    demo_select #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL),.V_TOTAL(V_TOTAL)) u_pat(
        .clk(pix_clk),.rst_n(rst_n),.enable(enable),.mode(mode),
        .valid(pix_valid),.pixel(pix_data),.x(pix_x),.y(pix_y),
        .sof(pix_sof),.sol(pix_sol),.frame_id(pix_frame_id));
    end else begin:static_source
    demo #(.GROUP(DEMO_GROUP), .VIEW(DEMO_VIEW), .WIDTH(WIDTH), .HEIGHT(HEIGHT),
          .H_TOTAL(H_TOTAL), .V_TOTAL(V_TOTAL)) u_pat (
        .clk(pix_clk), .rst_n(rst_n), .enable(enable),
        .valid(pix_valid), .pixel(pix_data),
        .x(pix_x), .y(pix_y), .sof(pix_sof), .sol(pix_sol),
        .frame_id(pix_frame_id)
    );

    end endgenerate

    pack u_pack (
        .clk(pix_clk), .rst_n(rst_n),
        .in_valid(pix_valid && !overflow), .in_ready(pack_ready),
        .in_pixel(pix_data), .in_sof(pix_valid && pix_sof),
        .in_eof(pix_valid && pix_x == WIDTH-1 && pix_y == HEIGHT-1),
        .in_frame_id(pix_frame_id),
        .out_valid(pack_valid), .out_ready(fifo_ready),
        .out_data(pack_data), .out_sof(pack_sof),
        .out_eof(pack_eof), .out_frame_id(pack_frame_id),
        .frame_error(pack_error)
    );

    afifo #(.WIDTH(162), .ADDR_BITS(FIFO_ADDR_BITS)) u_fifo (
        .wr_clk(pix_clk), .rd_clk(tx_clk), .rst_n(rst_n),
        .wr_valid(pack_valid), .wr_ready(fifo_ready),
        .wr_data({pack_frame_id, pack_eof, pack_sof, pack_data}),
        .rd_valid(tx_valid), .rd_ready(tx_ready), .rd_data(fifo_data)
    );
    assign {tx_frame_id, tx_eof, tx_sof, tx_data} = fifo_data;

    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n)
            overflow <= 1'b0;
        else if ((pix_valid && !pack_ready) || pack_error)
            overflow <= 1'b1;
    end
endmodule
