`timescale 1ns/1ps

// Dual-clock ready/valid FIFO with Gray-coded pointer synchronizers.
// Depth is 2**ADDR_BITS; ADDR_BITS must be at least 2. Reset must be
// asserted to both domains; release is synchronized independently in each domain.
// Verify block-RAM inference and CDC constraints in the final PDS design.
module afifo #(
    parameter integer WIDTH = 162,
    parameter integer ADDR_BITS = 9
)(
    input  wire             wr_clk,
    input  wire             rd_clk,
    input  wire             rst_n,
    input  wire             wr_valid,
    output wire             wr_ready,
    input  wire [WIDTH-1:0] wr_data,
    output wire             rd_valid,
    input  wire             rd_ready,
    output wire [WIDTH-1:0] rd_data
);
    // Asynchronous assertion, independent synchronous release. Keeping ready/
    // valid low until release prevents a producer from losing its first word.
    reg [1:0] wr_reset_pipe = 0, rd_reset_pipe = 0;
    always @(posedge wr_clk or negedge rst_n)
        if (!rst_n) wr_reset_pipe <= 0;
        else wr_reset_pipe <= {wr_reset_pipe[0],1'b1};
    always @(posedge rd_clk or negedge rst_n)
        if (!rst_n) rd_reset_pipe <= 0;
        else rd_reset_pipe <= {rd_reset_pipe[0],1'b1};
    wire wr_rst_n = wr_reset_pipe[1];
    wire rd_rst_n = rd_reset_pipe[1];
    localparam integer PTR_BITS = ADDR_BITS + 1;
    reg [WIDTH-1:0] mem [0:(1<<ADDR_BITS)-1];
    reg [PTR_BITS-1:0] wr_bin, wr_gray;
    reg [PTR_BITS-1:0] rd_bin, rd_gray;
    reg [PTR_BITS-1:0] rd_gray_w1, rd_gray_w2;
    reg [PTR_BITS-1:0] wr_gray_r1, wr_gray_r2;
    reg full;
    reg out_valid;
    reg [WIDTH-1:0] out_data;

    wire wr_fire = wr_valid && wr_ready;
    wire [PTR_BITS-1:0] wr_bin_next = wr_bin + wr_fire;
    wire [PTR_BITS-1:0] wr_gray_next =
        (wr_bin_next >> 1) ^ wr_bin_next;
    wire [PTR_BITS-1:0] rd_gray_inverted =
        {~rd_gray_w2[ADDR_BITS:ADDR_BITS-1],
          rd_gray_w2[ADDR_BITS-2:0]};
    wire mem_empty = (rd_gray == wr_gray_r2);
    wire fetch = rd_rst_n && (!out_valid || rd_ready) && !mem_empty;
    wire [PTR_BITS-1:0] rd_bin_next = rd_bin + fetch;

    assign wr_ready = wr_rst_n && !full;
    assign rd_valid = rd_rst_n && out_valid;
    assign rd_data = out_data;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin <= {PTR_BITS{1'b0}};
            wr_gray <= {PTR_BITS{1'b0}};
            rd_gray_w1 <= {PTR_BITS{1'b0}};
            rd_gray_w2 <= {PTR_BITS{1'b0}};
            full <= 1'b0;
        end else begin
            rd_gray_w1 <= rd_gray;
            rd_gray_w2 <= rd_gray_w1;
            if (wr_fire)
                mem[wr_bin[ADDR_BITS-1:0]] <= wr_data;
            wr_bin <= wr_bin_next;
            wr_gray <= wr_gray_next;
            full <= (wr_gray_next == rd_gray_inverted);
        end
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin <= {PTR_BITS{1'b0}};
            rd_gray <= {PTR_BITS{1'b0}};
            wr_gray_r1 <= {PTR_BITS{1'b0}};
            wr_gray_r2 <= {PTR_BITS{1'b0}};
            out_valid <= 1'b0;
            out_data <= {WIDTH{1'b0}};
        end else begin
            wr_gray_r1 <= wr_gray;
            wr_gray_r2 <= wr_gray_r1;
            if (fetch) begin
                out_data <= mem[rd_bin[ADDR_BITS-1:0]];
                out_valid <= 1'b1;
                rd_bin <= rd_bin_next;
                rd_gray <= (rd_bin_next >> 1) ^ rd_bin_next;
            end else if (out_valid && rd_ready) begin
                out_valid <= 1'b0;
            end
        end
    end
endmodule
