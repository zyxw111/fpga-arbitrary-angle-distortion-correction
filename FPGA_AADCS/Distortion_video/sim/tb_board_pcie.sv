`timescale 1ns/1ps
// Real vendor RX/controller/TX, with only hard PCIe PHY and block RAM replaced.
module tb_board_pcie;
reg pix_clk=0,clk=0,dma_clk=0,rst_n=0;always #20 pix_clk=~pix_clk;always #4 clk=~clk;always #5 dma_clk=~dma_clk;
wire av,ar,wr,wl,rv,rr,rl,rvalid;wire [27:0] aa,ra;wire [3:0] al,rlen;
wire [127:0] wd,rd,data,status;wire [15:0] ws;
wire prepared,launch,req_toggle,ready,busy,frame_ready,dvalid,ddone,read_req,request,tx_busy;
wire [7:0] ec,hc;wire [12:0] bytes;wire [31:0] hash;wire [27:0] cursor;
wire [9:0] length;wire [63:0] address;wire [11:0] status_addr;
reg rxv=0,rxlast=0;reg [127:0] rxdata=0;reg [3:0] rxkeep=0;reg [7:0] rxuser=0;
wire txv,txlast;wire [127:0] txdata;reg txready=0;
wire cv,cl;wire [127:0] cd;
still #(.WIDTH(128),.HEIGHT(80),.H_TOTAL(160),.V_TOTAL(110),.GROUP(1),.VIEW(1)) image(
 .pix_clk(pix_clk),.clk(clk),.dma_clk(dma_clk),.rst_n(rst_n),.init_done(rst_n),
 .request_toggle(req_toggle),.request_bytes(bytes),.frame_ready(frame_ready),.error_code(ec),
 .checksum(hash),.cursor(cursor),.prepared(prepared),.launch(launch),.rd_req(read_req),
 .rd_data(data),.rd_valid(dvalid),.rd_done(ddone),
 .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
 .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
hostlink #(.WIDTH(128),.HEIGHT(80),.GROUP(1),.VIEW(1)) host(
 .clk(dma_clk),.rst_n(rst_n),.frame_ready(frame_ready),.engine_error(ec),.checksum(hash),
 .cursor(cursor),.request(request),.length(length),.address(address),.tx_busy(tx_busy),.prepared(prepared),.rd_done(ddone),
 .ready(ready),.launch(launch),.request_toggle(req_toggle),.bytes(bytes),.busy(busy),
 .status_addr(),.bar_addr(status_addr),.status_data(status),.error_code(hc));
ddrmodel #(.WORDS(1280)) mem(.clk(clk),.rst_n(rst_n),
 .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
 .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
ips2l_pcie_dma #(.DEVICE_TYPE(0),.AXIS_SLAVE_NUM(3)) dma(
 .clk(dma_clk),.rst_n(rst_n),.i_cfg_pbus_num(8'd33),.i_cfg_pbus_dev_num(5'd0),
 .i_cfg_max_rd_req_size(3'd0),.i_cfg_max_payload_size(3'd0),
 .i_axis_master_tvld(rxv),.o_axis_master_trdy(),.i_axis_master_tdata(rxdata),
 .i_axis_master_tkeep(rxkeep),.i_axis_master_tlast(rxlast),.i_axis_master_tuser(rxuser),
 .i_axis_slave0_trdy(1'b1),.o_axis_slave0_tvld(cv),.o_axis_slave0_tdata(cd),.o_axis_slave0_tlast(cl),
 .i_axis_slave1_trdy(1'b1),.i_axis_slave2_trdy(txready),.o_axis_slave2_tvld(txv),
 .o_axis_slave2_tdata(txdata),.o_axis_slave2_tlast(txlast),
 .i_cfg_ido_req_en(1'b0),.i_cfg_ido_cpl_en(1'b0),
 .i_xadm_ph_cdts(8'd0),.i_xadm_pd_cdts(12'd0),.i_xadm_nph_cdts(8'd0),.i_xadm_npd_cdts(12'd0),
 .i_xadm_cplh_cdts(8'd0),.i_xadm_cpld_cdts(12'd0),
 .i_apb_psel(1'b0),.i_apb_paddr(9'd0),.i_apb_pwdata(32'd0),.i_apb_pstrb(4'd0),
 .i_apb_pwrite(1'b0),.i_apb_penable(1'b0),
 .o_dma_write_data_req(read_req),.i_dma_write_data(data),
 .i_video_ready(ready),.i_video_busy(busy),.o_video_request(request),
 .o_video_length(length),.o_video_address(address),.o_video_tx_busy(tx_busy),
 .o_video_status_addr(status_addr),.i_video_status_data(status));
function [31:0] swap32(input [31:0] a);swap32={a[7:0],a[15:8],a[23:16],a[31:24]};endfunction
task write32(input [31:0] addr,input [31:0] value);
begin
 @(negedge dma_clk);rxv=1;rxdata={32'd0,addr,32'h0000000f,32'h40000001};rxkeep=15;rxlast=0;rxuser=8'h10;
 @(negedge dma_clk);rxdata={96'd0,swap32(value)};rxkeep=1;rxlast=1;
 @(negedge dma_clk);rxv=0;rxlast=0;repeat(10)@(negedge dma_clk);
end endtask
reg [15:0] golden[0:10239];integer pixels=0,packets=0,n=0,j,pos=0,cmds=0,amount,left,phase=0;
reg payload=0;reg [31:0] value;reg [127:0] held;reg holding=0;
always @(negedge dma_clk)begin n=n+1;txready=(n%7!=0 && n%7!=1 && n%29<23);end
always @(posedge dma_clk)begin
 if(rst_n)begin
  if(holding && (!txv || txdata!==held))$fatal(1,"TX changed while stalled");
  holding=txv && !txready;held=txdata;
  if(txv && txready)begin
   if(!payload)begin
    if(txlast || txdata[31:24]!=8'h40 || txdata[9:0]>32)$fatal(1,"MWr header %h",txdata);
    payload=1;packets=packets+1;
   end else begin
    for(j=0;j<4;j=j+1)begin
     value=swap32(txdata[j*32+:32]);
     if(value[15:0]!==golden[pixels%10240] || value[31:16]!==golden[(pixels+1)%10240])
       $fatal(1,"PCIe payload mismatch pixel=%0d got=%h expected=%h/%h",pixels,value,golden[pixels%10240],golden[(pixels+1)%10240]);
     pixels=pixels+2;
    end
    if(txlast)payload=0;
   end
  end
 end
end
integer completions=0;reg [31:0] cpl_value;
task read32(input [31:0] addr,input [31:0] expected);
integer prior_cpl;
begin
 prior_cpl=completions;
 @(negedge dma_clk);rxv=1;rxdata={32'd0,addr,32'h0000000f,32'h00000001};rxkeep=7;rxlast=1;rxuser=0;
 @(negedge dma_clk);rxv=0;rxlast=0;wait(completions==prior_cpl+1);#1;
 if(cpl_value!==expected)$fatal(1,"BAR0 offset=%h got=%h expected=%h",addr,cpl_value,expected);
 repeat(12)@(negedge dma_clk);
end endtask
always @(posedge dma_clk)if(cv && cl)begin
 cpl_value=swap32(cd[31:0]);completions=completions+1;
end
initial begin
 $display("PCIe test starting");$fflush();
 $readmemh("sim/demo_vectors/corrected_128x80.hex",golden);
 #100;rst_n=1;wait(frame_ready);$display("DDR image ready at %0t",$time);$fflush();repeat(20)@(negedge dma_clk);
 // Read status through REAL PCIe completion path, including address alignment.
 read32(0,32'h44564d31);read32(4,32'h10000);read32(8,1);read32(12,0);
 read32(16,128);read32(20,80);read32(24,256);read32(28,20480);
 read32(32,1);read32(36,1);read32(40,0);read32(44,hash);read32(48,0);
 for(phase=0;phase<2;phase=phase+1)begin
  pos=0;
  while(pos<20480)begin
   amount=16 << (cmds%9);left=20480-pos;
   if(amount>left)amount=left;
   if(amount>4096-(pos%4096))amount=4096-(pos%4096);
   write32(32'h110,32'h100000+pos);write32(32'h120,0);
   write32(32'h100,32'h01000000 | (amount/4-1));cmds=cmds+1;
   wait(host.count==cmds);repeat(12)@(negedge dma_clk);
   if(ec || hc || pixels*2!=(phase*20480+pos+amount))$fatal(1,"command completion mismatch %0d",cmds);
   pos=pos+amount;
  end
 end
 if(cursor!=0)$fatal(1,"cursor wrap");
 $display("PASS real PCIe DMA RX/MMIO/CplD/TX: %0d descriptors %0d TLPs %0d pixels exact, random backpressure",cmds,packets,pixels);$finish;
end
initial begin #2000000;$fatal(1,"timeout state=%0d host=%0d ec=%0d hc=%0d request=%b pixels=%0d cmds=%0d",image.state,host.state,ec,hc,request,pixels,cmds);end
endmodule
