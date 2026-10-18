// Stage one complete DMA descriptor (16..4096 bytes) before granting launch.
// All signals use ONE clock. Use CDC outside this module for a PCIe clock.
// Sequential rd_req -> rd_data/rd_valid registered after the accepting edge.
// done marks the final SOURCE RESPONSE, never a host-visible PCIe completion.
module supply (
    input clk, input rst_n,
    input start, output start_ready, input [12:0] bytes,
    input in_valid, output in_ready, input [127:0] in_data,
    output prepared, input launch,
    input rd_req, output reg [127:0] rd_data, output reg rd_valid,
    output reg done, output reg error
);
    localparam IDLE=3'd0, FILL=3'd1, READY=3'd2, READ=3'd3, HALT=3'd4;
    reg [2:0] state;
    reg [127:0] buffer[0:255];
    reg [8:0] total;
    reg [7:0] index;
    assign start_ready = state == IDLE && !error;
    assign in_ready = state == FILL;
    assign prepared = state == READY;
    wire accepted = rd_req && (state == READ || (state == READY && launch));
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; total <= 0; index <= 0;
            rd_data <= 0; rd_valid <= 0; done <= 0; error <= 0;
        end else begin
            rd_valid <= 0; done <= 0;
            if (rd_req && !accepted) begin error <= 1; state <= HALT; end
            else case(state)
                IDLE: if (start && start_ready) begin
                    if (bytes == 0 || bytes > 4096 || bytes[3:0] != 0) begin
                        error <= 1; state <= HALT;
                    end else begin total <= bytes[12:4]; index <= 0; state <= FILL; end
                end
                FILL: if (in_valid) begin
                    buffer[index] <= in_data;
                    if ({1'b0,index} == total - 1'b1) begin index <= 0; state <= READY; end
                    else index <= index + 1'b1;
                end
                READY: if (launch) state <= READ;
                default: begin end
            endcase
            if (accepted) begin
                rd_data <= buffer[index]; rd_valid <= 1;
                if ({1'b0,index} == total - 1'b1) begin
                    done <= 1; index <= 0; state <= IDLE;
                end else begin index <= index + 1'b1; state <= READ; end
            end
        end
    end
endmodule
