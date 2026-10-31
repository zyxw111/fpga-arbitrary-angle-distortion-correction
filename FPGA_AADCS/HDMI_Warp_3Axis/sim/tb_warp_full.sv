`timescale 1ns/1ps
module tb_warp_full;
 parameter OVERLAP_WRITE=1,FAST=0,SAMPLE_PIPELINE=0;
 localparam W=1920,H=1080,N=W*H,BEATS=N/8;
 reg clk=0,rst_n=0,start=0;always #4 clk=~clk;
 wire ready,done;wire [7:0] error;wire [31:0] checksum;wire [255:0] perf;
 wire av,ar,wr,wl,rv,rr,valid,last;wire [27:0] aa,ra;wire [3:0] al,rl;
 wire [127:0] wd,rd;wire [15:0] strb;
 wire cav,car,cwr,cwl,crv,crr,cv,cl;wire [27:0] caa,cra;wire [3:0] cal,crl;
 wire [127:0] cwd,crd;wire [15:0] cstrb;
 reg [31:0] config_words[0:16];wire [543:0] config_bank;
 genvar cfg;generate for(cfg=0;cfg<17;cfg=cfg+1)begin:configuration
  assign config_bank[cfg*32+:32]=config_words[cfg];
 end endgenerate
 generate if(!FAST)begin:original
 warp_tiles #(.WARP_OVERLAP_WRITE(OVERLAP_WRITE)) dut(.clk(clk),.rst_n(rst_n),.start(start),
  .width(16'd1920),.height(16'd1080),.source_base(28'd0),.output_base(28'h1000000),
  .ready(ready),.done(done),.error(error),.checksum(checksum),.tile_perf(perf),
  .awvalid(cav),.awready(car),.awaddr(caa),.awlen(cal),.wdata(cwd),.wstrb(cstrb),.wready(cwr),.wlast(cwl),
  .arvalid(crv),.arready(crr),.araddr(cra),.arlen(crl),.rdata(crd),.rvalid(cv),.rlast(cl));
 end else begin:online
 warp_fast #(.CACHE_NATIVE_TDP(0),.SAMPLE_PIPELINE(SAMPLE_PIPELINE)) dut(.clk(clk),.rst_n(rst_n),.start(start),.config_bank(config_bank),
  .width(16'd1920),.height(16'd1080),.source_base(28'd0),.output_base(28'h1000000),
  .ready(ready),.done(done),.error(error),.checksum(checksum),.tile_perf(perf),
  .awvalid(cav),.awready(car),.awaddr(caa),.awlen(cal),.wdata(cwd),.wstrb(cstrb),.wready(cwr),.wlast(cwl),
  .arvalid(crv),.arready(crr),.araddr(cra),.arlen(crl),.rdata(crd),.rvalid(cv),.rlast(cl));
 end endgenerate
 video_ddr_arb #(.WRITERS(1),.READERS(1)) arb(.clk(clk),.rst_n(rst_n),
  .wav(cav),.war(car),.waa(caa),.wal(cal),.wd(cwd),.ws(cstrb),.wr(cwr),.wl(cwl),
  .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(strb),.wready(wr),.wlast(wl),
  .rav(crv),.rar(crr),.raa(cra),.ral(crl),.rv(cv),.rl(cl),.rd(crd),
  .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rl),.rdata(rd),.rvalid(valid),.rlast(last));
 ddrmodel #(.WORDS('h300000),.READ_QUEUE(16),.READ_DELAY(26)) mem(.clk(clk),.rst_n(rst_n),
  .awvalid(av),.awready(ar),.awaddr(aa),.awlen(al),.wdata(wd),.wstrb(strb),.wready(wr),.wlast(wl),
  .arvalid(rv),.arready(rr),.araddr(ra),.arlen(rl),.rdata(rd),.rvalid(valid),.rlast(last));
 reg [15:0] golden[0:N-1];integer i,cycle=0,began,written=0;reg [31:0] hash=0;
 string source_file,map_file,golden_file,params_file;
 function [31:0] mix(input [31:0] h,input [127:0] d);
  mix={h[26:0],h[31:27]}^d[31:0]^{d[62:32],d[63]}^{d[92:64],d[95:93]}^{d[120:96],d[127:121]};
 endfunction
 always @(posedge clk)begin
  cycle<=cycle+1;if(cwr)written<=written+1;
  if(error)$fatal(1,"warp error %h",error);
  if(cycle>10000000)$fatal(1,"full-frame timeout");
  if(done && written!=BEATS)$fatal(1,"early done: %0d beats",written);
 end
 initial begin
  if(!$value$plusargs("SOURCE=%s",source_file) || !$value$plusargs("MAP=%s",map_file) ||
     !$value$plusargs("GOLDEN=%s",golden_file))$fatal(1,"input files missing");
  if(FAST)begin
   if(!$value$plusargs("PARAMS=%s",params_file))$fatal(1,"parameters missing");
   $readmemh(params_file,config_words);
  end
  $readmemh(source_file,mem.memory,0,BEATS-1);
  $readmemh(map_file,mem.memory,'h200000,'h200000+N/2-1);
  $readmemh(golden_file,golden);
  for(i=0;i<BEATS;i=i+1)mem.memory['h100000+i]=128'hdeadbeefdeadbeefdeadbeefdeadbeef;
  repeat(5)@(negedge clk);rst_n=1;wait(ready);
  @(negedge clk);start=1;began=cycle;@(negedge clk);start=0;
  wait(done);@(negedge clk);
  for(i=0;i<N;i=i+1)if(mem.memory['h100000+i/8][(i%8)*16+:16]!==golden[i])
   $fatal(1,"pixel %0d got=%h expected=%h",i,mem.memory['h100000+i/8][(i%8)*16+:16],golden[i]);
  for(i=0;i<BEATS;i=i+1)hash=mix(hash,mem.memory['h100000+i]);
  if(checksum!==hash)$fatal(1,"frame checksum %h != %h",checksum,hash);
  $display("PASS FULL1080 mode=%0d pixels=%0d max_error=0 cycles=%0d checksum=%h",FAST?2:OVERLAP_WRITE,N,cycle-began,checksum);
  $finish;
 end
endmodule
