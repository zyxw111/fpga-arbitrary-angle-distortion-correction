// Two DDR frame slots. All control inputs belong to clk (DDR user domain).
// Publish only after ALL DDR writes complete. Release only after ALL DMA
// source reads complete and no in-flight read can still access this slot.
// This module allocates slots; it contains no pixel memory or CDC logic.
module frame (
    input clk, input rst_n,
    input wr_start, output wr_ready, output wr_slot,
    input wr_finish, input wr_good, input [31:0] wr_id,
    output rd_valid, input rd_start, output rd_slot,
    output [31:0] rd_id, input rd_finish,
    output reg error
);
    localparam FREE=2'd0, WRITE=2'd1, FULL=2'd2, READ=2'd3;
    reg [1:0] state0, state1;
    reg [31:0] id0, id1;
    reg wp, rp;
    wire [1:0] ws = wp ? state1 : state0;
    wire [1:0] rs = rp ? state1 : state0;
    assign wr_ready = (ws == FREE);
    assign wr_slot = wp;
    assign rd_valid = (rs == FULL);
    assign rd_slot = rp;
    assign rd_id = rp ? id1 : id0;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state0 <= FREE; state1 <= FREE;
            id0 <= 0; id1 <= 0; wp <= 0; rp <= 0; error <= 0;
        end else begin
            // start while !ready/!valid is allowed: standard handshake.
            // A finish without its active owner is a protocol error.
            if (wr_finish && ws != WRITE) error <= 1;
            if (rd_finish && rs != READ) error <= 1;
            if (wr_start && wr_ready) begin
                if (wp) state1 <= WRITE; else state0 <= WRITE;
            end
            if (wr_finish && ws == WRITE) begin
                if (wp) begin state1 <= wr_good ? FULL : FREE; id1 <= wr_id; end
                else begin state0 <= wr_good ? FULL : FREE; id0 <= wr_id; end
                // A rejected frame reuses the same slot, preserving order.
                if (wr_good) wp <= !wp;
            end
            if (rd_start && rd_valid) begin
                if (rp) state1 <= READ; else state0 <= READ;
            end
            if (rd_finish && rs == READ) begin
                if (rp) state1 <= FREE; else state0 <= FREE;
                rp <= !rp;
            end
        end
    end
endmodule
