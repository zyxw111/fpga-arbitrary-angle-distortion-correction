`timescale 1ns/1ps
module tb_h3d_csr_isolation;
reg h=0,f=0,rst=0,we=0;always #5 h=~h;always #7 f=~f;
reg [11:0] addr=0,sa=24;reg [31:0] data=0;
wire [287:0] ah;wire [543:0] ac;wire [31:0] gen;wire [127:0] status,ds;
wire pending,inject,busy;wire [11:0] ia;wire [31:0] id;
wire tx_restart;
ips2l_pcie_dma_controller #(.ADDR_WIDTH(12)) legacy(.clk(h),.rst_n(rst),
 .i_bar1_wr_en(we),.i_bar1_wr_addr(addr),.i_bar1_wr_data({96'd0,data}),.i_bar1_wr_byte_en(16'hffff),
 .i_apb_psel(1'b0),.i_apb_paddr(9'd0),.i_apb_pwdata(32'd0),.i_apb_pstrb(4'd0),.i_apb_pwrite(1'b0),.i_apb_penable(1'b0),
 .i_mwr32_req_ack(1'b0),.i_mwr64_req_ack(1'b0),.i_mrd32_req_ack(1'b0),.i_mrd64_req_ack(1'b0),.i_dma_check_result(64'd0),.o_tx_restart(tx_restart));
always @(negedge h)if(rst && (legacy.dma_cmd_reg_vld || legacy.dma_cmd_l_addr_vld || legacy.dma_cmd_h_addr_vld || tx_restart))
 $fatal(1,"H/CAM3 CSR aliased the legacy low-nine-bit DMA decode");
warp_control control(.host_clk(h),.frame_clk(f),.rst_n(rst),.wr_en(we),.wr_addr(addr),.wr_data(data),.wr_be(16'hffff),
 .defaults(544'd0),.frame_safe(1'b1),.status_addr(sa),.active_config(ac),.active_h(ah),.active_generation(gen),.status_data(status),.pending(pending));
frame_dma dma(.clk(h),.rst_n(rst),.control_wr(we),.control_addr(addr),.control_data(data),.control_be(16'hffff),
 .frame_ready(1'b1),.frame_bytes(32'd5120),.frame_id(32'd7),.page_completed(32'd0),
 .inject(inject),.page_busy(1'b0),.inject_addr(ia),.inject_data(id),.busy(busy),.status_addr(12'd10),.status_data(ds));
task write(input [11:0] a,input [31:0] d);begin @(negedge h);we=1;addr=a;data=d;@(negedge h);we=0;end endtask
integer i;
initial begin
 #31;rst=1;
 for(i=0;i<9;i=i+1)write(12'h340+i*4,32'h12340000+i);
 repeat(3)@(negedge h);
 if(dma.destination!==0 || dma.capacity!==0 || busy || dma.error!==0)$fatal(1,"H writes touched DMA CSR");
 write('h250,1);wait(gen==1);repeat(8)@(negedge h);
 write('h280,'h41000000);write('h284,8192);write('h288,1);
 repeat(12)@(negedge h);
 if(!busy || dma.accepted!==1 || dma.destination!=='h41000000 || dma.capacity!==8192)$fatal(1,"CAM3 DMA command rejected");
 for(i=0;i<9;i=i+1)if(control.shadow_h[i*32+:32]!==32'h12340000+i)$fatal(1,"DMA writes corrupted H word %0d",i);
 for(i=0;i<9;i=i+1)write(12'h340+i*4,32'h56780000+i);
 write('h250,2);wait(gen==2);repeat(8)@(negedge h);
 if(dma.error!==0 || dma.accepted!==1)$fatal(1,"H update disturbed in-flight DMA");
 for(i=0;i<9;i=i+1)if(ah[i*32+:32]!==32'h56780000+i)$fatal(1,"H update lost during DMA");
 $display("PASS shared BAR CSR isolation: H 0x340..0x360 and concurrent CAM3 DMA 0x280/284/288");$finish;
end
initial begin #100000;$fatal(1,"isolation timeout");end
endmodule
