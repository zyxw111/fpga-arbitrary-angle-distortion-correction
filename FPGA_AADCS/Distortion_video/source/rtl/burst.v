// 128-bit stream -> prebuffered 16-beat writes, Pango DDR-style interface.
// Byte addresses, 256-byte aligned base; beats must be a nonzero multiple
// of 16. Every command is 256 bytes, so no command crosses a 4 KiB boundary.
// clk is the DDR user clock. Hold source valid/data until in_ready.
// No WVALID/B channel exists on the target IP. Once AW is accepted every
// asserted wready consumes a beat. Full prebuffering prevents underflow.
// done means final data was accepted at this interface, NOT durable DDR
// completion, read-after-write visibility, or host DMA completion.
module burst (
    input clk, input rst_n,
    input start, output start_ready,
    input [27:0] base_addr, input [31:0] beats,
    input in_valid, output in_ready, input [127:0] in_data,
    output awvalid, input awready, output [27:0] awaddr,
    output [3:0] awlen,
    output [127:0] wdata, output [15:0] wstrb,
    input wready, input wlast,
    output reg done, output reg error
);
    localparam IDLE=3'd0, FILL=3'd1, ADDR=3'd2, DATA=3'd3, HALT=3'd4;
    reg [2:0] state;
    reg [127:0] buffer [0:15];
    reg [3:0] index;
    reg [27:0] cursor;
    reg [31:0] remaining;
    wire [36:0] limit = {9'd0,base_addr} + {1'b0,beats,4'b0};
    wire legal = (base_addr[7:0] == 0) && (beats != 0) &&
                 (beats[3:0] == 0) && (limit <= 37'h010000000);
    assign start_ready = (state == IDLE) && !error;
    assign in_ready = (state == FILL);
    assign awvalid = (state == ADDR);
    assign awaddr = cursor;
    assign awlen = 4'd15;
    assign wdata = buffer[index];
    assign wstrb = (state == DATA || state == ADDR) ? 16'hffff : 16'h0000;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; index <= 0; cursor <= 0; remaining <= 0;
            done <= 0; error <= 0;
        end else begin
            done <= 0;
            case (state)
                IDLE: if (start && start_ready) begin
                    if (!legal) begin error <= 1; state <= HALT; end
                    else begin cursor <= base_addr; remaining <= beats;
                        index <= 0; state <= FILL; end
                end
                FILL: if (in_valid) begin
                    buffer[index] <= in_data;
                    if (index == 15) begin index <= 0; state <= ADDR; end
                    else index <= index + 1'b1;
                end
                ADDR: if (awready) begin
                    // Also support first data accepted with the address.
                    if (wready && wlast) begin error <= 1; state <= HALT; end
                    else begin
                        if (wready) index <= 1;
                        state <= DATA;
                    end
                end
                DATA: if (wready) begin
                    if (wlast != (index == 15)) begin
                        error <= 1; state <= HALT;
                    end else if (index == 15) begin
                        index <= 0;
                        if (remaining == 16) begin state <= IDLE; done <= 1; end
                        else begin remaining <= remaining - 16;
                            cursor <= cursor + 28'd256; state <= FILL; end
                    end else index <= index + 1'b1;
                end
                default: state <= HALT;
            endcase
        end
    end
endmodule
