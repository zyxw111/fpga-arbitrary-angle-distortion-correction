`timescale 1ns/1ps
module tb_warp_tiles #(parameter OVERLAP_WRITE=1,OUTPUT_BANKS=2,WRITE_STALL=0);
 reg clk=0;always #4 clk=~clk;
 reg rst_n=0,build_start=0,warp_start=0;
 wire [543:0] bank;hdmi_defaults defaults(.defaults(bank));
 wire build_ready,build_done,build_error,warp_ready,warp_done;
 wire [7:0] warp_error;wire [31:0] checksum;
 wire [1:0] wav,war,wr,wl;wire [55:0] waa;wire [7:0] wal;
 wire [255:0] wd;wire [31:0] ws;
 wire av,ar,wready,wlast,rv,rr,rvalid,rlast;
 wire [27:0] aa,ra;wire [3:0] al,rlen;wire [127:0] data,rd;
 wire crv,crr,cv,cl;wire [27:0] cra;wire [3:0] crl;
 wire [127:0] cache_data;
 warp_lut #(.BASE(28'h10000)) builder(.clk(clk),.rst_n(rst_n),.start(build_start),
  .width(16'd64),.height(16'd40),.config_bank(bank),.ready(build_ready),.done(build_done),.error(build_error),
  .awvalid(wav[0]),.awready(war[0]),.awaddr(waa[0+:28]),.awlen(wal[0+:4]),
  .wdata(wd[0+:128]),.wstrb(ws[0+:16]),.wready(wr[0]),.wlast(wl[0]));
 wire [255:0] perf;integer written_beats=0;
 warp_tiles #(.LUT_BASE(28'h10000),.WARP_OVERLAP_WRITE(OVERLAP_WRITE),.WARP_OUTPUT_BANKS(OUTPUT_BANKS)) dut(.clk(clk),.rst_n(rst_n),.start(warp_start),
  .width(16'd64),.height(16'd40),.source_base(28'd0),.output_base(28'h8000),
  .ready(warp_ready),.done(warp_done),.error(warp_error),.checksum(checksum),
  .awvalid(wav[1]),.awready(war[1]),.awaddr(waa[28+:28]),.awlen(wal[4+:4]),
  .wdata(wd[128+:128]),.wstrb(ws[16+:16]),.wready(wr[1]),.wlast(wl[1]),
  .arvalid(crv),.arready(crr),.araddr(cra),.arlen(crl),.rdata(cache_data),.rvalid(cv),.rlast(cl),.tile_perf(perf));
 video_ddr_arb #(.WRITERS(2),.READERS(1)) arb(.clk(clk),.rst_n(rst_n),
  .wav(wav),.war(war),.waa(waa),.wal(wal),.wd(wd),.ws(ws),.wr(wr),.wl(wl),
  .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(data),.wstrb(),.wready(wready),.wlast(wlast),
  .rav(crv),.rar(crr),.raa(cra),.ral(crl),.rv(cv),.rl(cl),.rd(cache_data),
  .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rlast));
 ddrmodel #(.WORDS(8192),.READ_QUEUE(16),.READ_DELAY(40),.WRITE_STALL_CYCLES(WRITE_STALL)) mem(.clk(clk),.rst_n(rst_n),
  .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(data),.wstrb(16'hffff),.wready(wready),.wlast(wlast),
  .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rlen),.rdata(rd),.rvalid(rvalid),.rlast(rlast));
 reg [15:0] golden[0:2559];reg [127:0] lut[0:1279];
 integer i,x,y,f,start_cycle,cycle=0;reg [31:0] hash;reg [127:0] word;
 always @(posedge clk)begin
  cycle<=cycle+1;
  if(build_error || warp_error)$fatal(1,"engine error LUT=%h warp=%h ls=%d",build_error,warp_error,dut.ls);
  if(cycle>1500000)$fatal(1,"timeout");
  if(warp_start && warp_ready)written_beats<=0;
  else if(wr[1])written_beats<=written_beats+1;
  if(warp_done && written_beats!=320)$fatal(1,"published before final DDR beat: %0d",written_beats);
 end
 function [31:0] mix(input [31:0] h,input [127:0] d);
  mix={h[26:0],h[31:27]}^d[31:0]^{d[62:32],d[63]}^{d[92:64],d[95:93]}^{d[120:96],d[127:121]};
 endfunction
 initial begin
  $readmemh("build/sim/native_golden.hex",golden);
  $readmemh("build/sim/native_lut.hex",lut);
  for(i=0;i<2560;i=i+1)begin
   x=i%64;y=i/64;
   mem.memory[i/8][(i%8)*16+:16]=((x%32)<<11)|((y%64)<<5)|((x+y)%32);
  end
  repeat(5)@(negedge clk);rst_n=1;
  wait(build_ready);@(negedge clk);build_start=1;@(negedge clk);build_start=0;
  wait(build_done);@(negedge clk);
  for(i=0;i<1280;i=i+1)if(mem.memory['h1000+i]!==lut[i])$fatal(1,"LUT word %d actual=%h expected=%h",i,mem.memory['h1000+i],lut[i]);
  for(f=0;f<2;f=f+1)begin
   if(f==1)begin
    $readmemh("build/sim/native_golden_changed.hex",golden);
    for(i=0;i<2560;i=i+1)begin
     x=i%64;y=i/64;
     mem.memory[i/8][(i%8)*16+:16]=(((x+3)%32)<<11)|(((y+7)%64)<<5)|((x+y+11)%32);
    end
   end
   for(i=0;i<320;i=i+1)mem.memory['h800+i]=128'hdeadbeefdeadbeefdeadbeefdeadbeef;
   wait(warp_ready);@(negedge clk);warp_start=1;start_cycle=cycle;@(negedge clk);warp_start=0;
   wait(warp_done);@(negedge clk);hash=0;
   for(i=0;i<2560;i=i+1)if(mem.memory['h800+i/8][(i%8)*16+:16]!==golden[i])
    $fatal(1,"pixel %d actual=%h expected=%h",i,mem.memory['h800+i/8][(i%8)*16+:16],golden[i]);
   for(i=0;i<320;i=i+1)hash=mix(hash,mem.memory['h800+i]);
   if(checksum!==hash)$fatal(1,"hash actual=%h expected=%h",checksum,hash);
   $display("PASS warp tiles frame %0d: 2560 bilinear pixels, raster checksum, cycles=%0d",f,cycle-start_cycle);
  end
  if(mem.queued.max_pending<4)$fatal(1,"prefetch did not queue reads");
  repeat(2)@(negedge clk);
  if(perf[31:0]!==32'h54494c31 || perf[255:224]!==2)$fatal(1,"tile perf header/frames %h",perf);
  if(OVERLAP_WRITE && perf[159:128]==0)$fatal(1,"compute/write did not overlap");
  if(!OVERLAP_WRITE && perf[159:128]!=0)$fatal(1,"serial path reports overlap");
  if(OVERLAP_WRITE && WRITE_STALL>1000 && OUTPUT_BANKS<=4 && perf[191:160]==0)$fatal(1,"output-full backpressure not exercised");
  $display("PASS output scheduling mode=%0d banks=%0d stall=%0d compute=%0d write=%0d overlap=%0d outwait=%0d",OVERLAP_WRITE,OUTPUT_BANKS,WRITE_STALL,perf[95:64],perf[127:96],perf[159:128],perf[191:160]);
  $display("PASS queued DDR prefetch: peak=%0d outstanding",mem.queued.max_pending);
  $finish;
 end
endmodule
