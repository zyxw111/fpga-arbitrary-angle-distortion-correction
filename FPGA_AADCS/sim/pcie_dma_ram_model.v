// Simulation boundary model only. BAR RAM is not in the streaming DMA path.
// Exclude the vendor RAM wrapper when compiling this model; synthesis uses IP.
module ips2l_pcie_dma_ram(
    input [127:0] wr_data, input [8:0] wr_addr,
    input wr_en, input [15:0] wr_byte_en, input wr_clk, wr_rst,
    input [8:0] rd_addr, output reg [127:0] rd_data,
    input rd_clk, rd_clk_en, rd_rst
);
    reg [127:0] mem [0:511];
    integer i;
    always @(posedge wr_clk) if (!wr_rst && wr_en)
        for (i=0;i<16;i=i+1)
            if (wr_byte_en[i]) mem[wr_addr][i*8+:8] <= wr_data[i*8+:8];
    always @(posedge rd_clk)
        if (rd_rst) rd_data <= 0;
        else if (rd_clk_en) rd_data <= mem[rd_addr];
endmodule
