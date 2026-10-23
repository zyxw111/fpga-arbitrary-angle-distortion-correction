`timescale 1ns/1ps
module tb_synthetic_full;
 reg pclk=0,clk=0,rst_n=0;
 always #20 pclk=~pclk;always #4 clk=~clk;
 wire vsync,href;wire [7:0] camera_data;wire [31:0] fid;
 synthetic_camera sensor(.clk(pclk),.rst_n(rst_n),.vsync(vsync),.href(href),.data(camera_data),.frame_id(fid));
 wire av,ar,wr,wl,rv,rr,rl,rvalid;wire [27:0] aa,ra;wire [3:0] al,rlen;
 wire [127:0] wd,rd;wire [15:0] ws;wire frame_ready;wire [7:0] ec;
 wire [31:0] good,dropped,checksum;wire [255:0] diagnostics;
 camera_frame image(.pclk(pclk),.clk(clk),.dma_clk(clk),.rst_n(rst_n),.init_done(rst_n),.camera_ready(rst_n),
  .vsync(vsync),.href(href),.camera_data(camera_data),.good_frames(good),.dropped_frames(dropped),
  .diagnostics(diagnostics),.request_toggle(1'b0),.request_bytes(13'd0),.frame_ready(frame_ready),.error_code(ec),.checksum(checksum),
  .launch(1'b0),.rd_req(1'b0),.awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
  .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
 ddrmodel #(.WORDS(32000)) mem(.clk(clk),.rst_n(rst_n),
  .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(ws),.wready(wr),.wlast(wl),
  .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rl));
 reg [15:0] golden[0:255999];reg [31:0] selected_frame=0;integer i,x,y;reg [15:0] expected;
 always @(posedge pclk)if(rst_n && image.source.state==1 && vsync && !image.source.vsync_d && image.source.final_pending)selected_frame=fid;
 always @(posedge clk)if(ec || dropped)$fatal(1,"full geometry dropped/error: ec=%h diag=%h",ec,diagnostics);
 initial begin
  $readmemh("sim/demo_vectors/raw_640x400.hex",golden);
  #200;rst_n=1;wait(frame_ready);#1;
  for(i=0;i<256000;i=i+1)begin
   x=i%640;y=i/640;
   expected=(y>=392 && x<64)?(selected_frame[x/8]?16'hffe0:16'h001f):golden[i];
   if(mem.memory[i/8][(i%8)*16+:16]!==expected)$fatal(1,"full pixel %0d mismatch",i);
  end
  $display("PASS full 640x400 synthetic DVP capture: all 256000 DDR pixels exact, geometry accepted, readback checksum=%h",checksum);$finish;
 end
 initial begin #150000000;$fatal(1,"full synthetic capture timeout diag=%h",diagnostics);end
endmodule
