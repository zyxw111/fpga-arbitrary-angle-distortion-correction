// DDR user-domain burst reader. No RREADY exists on the Pango DDR interface:
// reserve a whole burst before AR, absorb every return, then drain to consumer.
// One outstanding command, 1..16 beats, no 4 KiB crossing. Byte addresses.
module fetch (
    input clk, input rst_n,
    input start, output start_ready,
    input [27:0] base_addr, input [31:0] beats,
    output arvalid, input arready, output [27:0] araddr,
    output [3:0] arlen,
    input rvalid, input rlast, input [127:0] rdata,
    output out_valid, input out_ready, output [127:0] out_data,
    output out_last, output reg done, output reg error
);
    localparam IDLE=3'd0, ADDR=3'd1, RECV=3'd2, SEND=3'd3, HALT=3'd4;
    reg [2:0] state;
    reg [127:0] buffer[0:15];
    reg [3:0] index;
    reg [27:0] cursor;
    reg [31:0] remaining;
    wire [8:0] page_beats = 9'd256 - {1'b0,cursor[11:4]};
    wire [4:0] capacity = (page_beats < 16) ? page_beats[4:0] : 5'd16;
    wire [4:0] chunk = (remaining < {27'd0,capacity}) ? remaining[4:0] : capacity;
    wire [36:0] limit = {9'd0,base_addr} + {1'b0,beats,4'b0};
    wire legal = (base_addr[3:0] == 0) && beats != 0 && limit <= 37'h010000000;
    assign start_ready = state == IDLE && !error;
    assign arvalid = state == ADDR;
    assign araddr = cursor;
    assign arlen = chunk[3:0] - 1'b1;
    assign out_valid = state == SEND;
    assign out_data = buffer[index];
    assign out_last = out_valid && remaining == {27'd0,chunk} &&
                      {1'b0,index} == chunk - 1'b1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; index <= 0; cursor <= 0; remaining <= 0;
            done <= 0; error <= 0;
        end else begin
            done <= 0;
            case(state)
                IDLE: if (rvalid) begin error <= 1; state <= HALT; end
                else if (start && start_ready) begin
                    if (!legal) begin error <= 1; state <= HALT; end
                    else begin cursor <= base_addr; remaining <= beats;
                        index <= 0; state <= ADDR; end
                end
                ADDR: begin
                    if (rvalid && !arready) begin error <= 1; state <= HALT; end
                    else if (arready) begin
                        // Some controllers can return beat 0 with AR acceptance.
                        if (rvalid) begin
                            buffer[0] <= rdata;
                            if (rlast != (chunk == 1)) begin error <= 1; state <= HALT; end
                            else if (chunk == 1) begin index <= 0; state <= SEND; end
                            else begin index <= 1; state <= RECV; end
                        end else begin index <= 0; state <= RECV; end
                    end
                end
                RECV: if (rvalid) begin
                    buffer[index] <= rdata;
                    if (rlast != ({1'b0,index} == chunk - 1'b1)) begin
                        error <= 1; state <= HALT;
                    end else if ({1'b0,index} == chunk - 1'b1) begin
                        index <= 0; state <= SEND;
                    end else index <= index + 1'b1;
                end
                SEND: if (rvalid) begin error <= 1; state <= HALT; end
                else if (out_ready) begin
                    if ({1'b0,index} == chunk - 1'b1) begin
                        index <= 0;
                        if (remaining == {27'd0,chunk}) begin done <= 1; state <= IDLE; end
                        else begin remaining <= remaining - {27'd0,chunk};
                            cursor <= cursor + {19'd0,chunk,4'd0}; state <= ADDR; end
                    end else index <= index + 1'b1;
                end
                default: state <= HALT;
            endcase
        end
    end
endmodule
