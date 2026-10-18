// Deterministic 128-bit test data for the legacy PCIe DMA read port.
// One-cycle synchronous read; this is a transport probe, not a video frame.
module dmapat #(
    parameter ADDR_WIDTH = 12
)(
    input                     clk,
    input                     rst_n,
    input                     rd_en,
    input  [ADDR_WIDTH-1:0]    rd_addr,
    output reg [127:0]        rd_data
);

    wire [31:0] addr_word = {{(32-ADDR_WIDTH){1'b0}}, rd_addr};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rd_data <= 128'd0;
        else if (rd_en)
            rd_data <= {
                32'hD4A5_0000 ^ addr_word,
                32'hB3C6_0000 ^ addr_word,
                32'hE2F7_0000 ^ addr_word,
                32'hA1B8_0000 ^ addr_word
            };
    end
endmodule
