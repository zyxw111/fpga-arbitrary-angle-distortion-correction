// Memory macro simulation only. RX/controller/TX and prefetch FIFOs are actual RTL.
module ips2l_pcie_dma_ram(input [127:0] wr_data,input [11:0] wr_addr,input wr_en,wr_clk,wr_rst,
 input [15:0] wr_byte_en,output reg [127:0] rd_data,input [11:0] rd_addr,input rd_clk,rd_clk_en,rd_rst);
reg [127:0] mem[0:4095];integer k;
always @(posedge wr_clk)if(wr_en)for(k=0;k<16;k=k+1)if(wr_byte_en[k])mem[wr_addr][8*k+:8]<=wr_data[8*k+:8];
always @(posedge rd_clk or posedge rd_rst)if(rd_rst)rd_data<=0;else if(rd_clk_en)rd_data<=mem[rd_addr];
endmodule
