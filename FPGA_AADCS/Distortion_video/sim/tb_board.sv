`timescale 1ns/1ps
module board_bench #(parameter GROUP=0,VIEW=1,FAULT=0);
reg pix_clk=0,clk=0,dma_clk=0,rst_n=0,init_done=0;
always #20 pix_clk=~pix_clk;always #4 clk=~clk;always #6.5 dma_clk=~dma_clk;
wire av,ar,wr,wl,rv,rr,rl,rvalid;wire [27:0] aa,ra;wire [3:0] al,rlen;
wire [127:0] wd,rd,data;wire [15:0] ws;wire prepared,launch,req_toggle;
wire ready,busy,frame_ready,dvalid,ddone;wire [7:0] ec,hc;
wire [12:0] bytes;wire [31:0] hash;wire [27:0] cursor;wire [127:0] status;
reg request=0,tx_busy=0,read_req=0;reg [9:0] len=64;reg [63:0] address=64'h100000;
reg corrupt=0;
always @(posedge clk) if(rst_n && (dut.be || dut.fe || dut.br_error || dut.overflow))
 $display("engine fault state=%0d burst=%b fetch=%b bridge=%b overflow=%b wc=%0d",dut.state,dut.be,dut.fe,dut.br_error,dut.overflow,dut.write_count);
still #(.WIDTH(64),.HEIGHT(4),.H_TOTAL(96),.V_TOTAL(40),.GROUP(GROUP),.VIEW(VIEW),.TIMEOUT(100000)) dut(
 .pix_clk(pix_clk),.clk(clk),.dma_clk(dma_clk),.rst_n(rst_n),.init_done(init_done),
 .request_toggle(req_toggle),.request_bytes(bytes),.frame_ready(frame_ready),.error_code(ec),
 .checksum(hash),.cursor(cursor),.prepared(prepared),.launch(launch),.rd_req(read_req),
 .rd_data(data),.rd_valid(dvalid),.rd_done(ddone),
 .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
 .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd ^ (corrupt ? 128'd1:128'd0)),.rvalid(rvalid),.rlast(rl));
hostlink #(.WIDTH(64),.HEIGHT(4),.GROUP(GROUP),.VIEW(VIEW),.TIMEOUT(100000)) host(
 .clk(dma_clk),.rst_n(rst_n),.frame_ready(frame_ready),.engine_error(ec),.checksum(hash),
 .cursor(cursor),.request(request),.length(len),.address(address),.tx_busy(tx_busy),.prepared(prepared),.rd_done(ddone),
 .ready(ready),.launch(launch),.request_toggle(req_toggle),.bytes(bytes),.busy(busy),
 .status_addr(),.bar_addr(12'd0),.status_data(status),.error_code(hc));
ddrmodel #(.WORDS(32)) mem(.clk(clk),.rst_n(rst_n),
 .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
 .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
reg [15:0] golden[0:255];integer received=0,j,i,k;
always @(posedge dma_clk)begin
 #1;
 if(dvalid)begin
  for(j=0;j<8;j=j+1)if(data[j*16+:16]!==golden[(received*8+j)%256])
    $fatal(1,"pixel mismatch beat=%0d lane=%0d got=%h expected=%h",received,j,data[j*16+:16],golden[(received*8+j)%256]);
  received=received+1;
 end
end
initial begin
 if(GROUP==0)$readmemh("sim/demo_vectors/bars_64x4.hex",golden);
 else if(VIEW==0)$readmemh("sim/demo_vectors/raw_64x4.hex",golden);
 else $readmemh("sim/demo_vectors/corrected_64x4.hex",golden);
 #80;rst_n=1;#80;init_done=1;
 if(FAULT==1)begin
  wait(dut.state==2);corrupt=1;wait(ec!=0);if(ec!=5)$fatal(1,"checksum error code %0d",ec);
  repeat(12)@(posedge dma_clk);if(frame_ready || hc!=16)$fatal(1,"bad frame published");
 end else begin
  wait(frame_ready);repeat(8)@(posedge dma_clk);
  if(status[31:0]!=32'h44564d31 || status[64]!=1)$fatal(1,"status map");
  if(FAULT==2)begin
   @(negedge dma_clk);address=64'h100003;request=1;
   wait(hc!=0);if(hc!=18 || req_toggle)$fatal(1,"unaligned command not rejected");
  end else begin
   for(k=0;k<6;k=k+1)begin
    @(negedge dma_clk);request=1;address=64'h100000+k*256;
    wait(launch);@(posedge dma_clk);#1;@(negedge dma_clk);tx_busy=1;request=0;
    // Read the entire descriptor, inserting gaps and long final-TLP delay.
    for(i=0;i<16;i=i+1)begin
     @(negedge dma_clk);read_req=1;
     @(negedge dma_clk);read_req=0;
     repeat(i%3)@(negedge dma_clk);
    end
    repeat(9)@(negedge dma_clk);
    if(status[127:96]!=k || !busy)$fatal(1,"premature completion");
    tx_busy=0;wait(!busy);repeat(8)@(posedge dma_clk);
    if(status[127:96]!=k+1 || ec || hc)$fatal(1,"completion/error %h %h",ec,hc);
   end
   if(received!=96 || cursor!=0)$fatal(1,"wrap/received %0d %0d",cursor,received);
  end
 end
 $display("PASS board GROUP=%0d VIEW=%0d FAULT=%0d DDR checked, CDC pages, delayed TX completion",GROUP,VIEW,FAULT);$finish;
end
initial begin #4000000;$fatal(1,"timeout state=%0d host=%0d err=%0d/%0d received=%0d",dut.state,host.state,ec,hc,received);end
endmodule
module tb_board_bars;board_bench #(.GROUP(0)) t();endmodule
module tb_board_raw;board_bench #(.GROUP(1),.VIEW(0)) t();endmodule
module tb_board_corrected;board_bench #(.GROUP(1),.VIEW(1)) t();endmodule
module tb_board_corrupt;board_bench #(.FAULT(1)) t();endmodule
module tb_board_invalid;board_bench #(.FAULT(2)) t();endmodule
