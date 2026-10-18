// Board bring-up: one immutable frame, checked DDR readback, then paged DMA.
// No camera. Frame checksum detects DDR faults; host compares every byte.
module still #(
 parameter integer WIDTH=640,HEIGHT=400,GROUP=0,VIEW=1,
 parameter integer DYNAMIC_MODE=0,
 parameter integer H_TOTAL=800,V_TOTAL=450,TIMEOUT=268435455
)(input pix_clk,input clk,input dma_clk,input rst_n,input init_done,
 input request_toggle,input [12:0] request_bytes,input [1:0] mode,
 output idle,
 output reg frame_ready,output reg [7:0] error_code,
 output reg [31:0] checksum,output reg [27:0] cursor,
 output prepared,input launch,input rd_req,output [127:0] rd_data,
 output rd_valid,output rd_done,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,input wlast,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,input rlast);
 localparam integer BEATS=WIDTH*HEIGHT/8;
 localparam BOOT=0,WRITE=1,SETTLE=2,VERIFY_START=3,VERIFY=4,
            IDLE=5,READ_START=6,READ=7,RELEASE=8,HALT=9;
 reg [3:0] state;
 reg [31:0] timer,write_count,read_count,read_hash;
 reg source_enable,seen;
 reg [12:0] bytes;
 reg [1:0] req_sync;
 reg [1:0] enable_sync,overflow_sync;
 wire sv,sr,sof,eof,overflow;wire [127:0] sd;wire [31:0] fid;
 wire bs_ready,bd,be,fr_ready,fd,fe,fv,fl,br_ready,br_done,br_error;
 wire [127:0] data;
 wire bridge_ready;
 wire active=rst_n && error_code==0;
 assign idle=(state==IDLE || state==HALT);
 function [31:0] mix;
 input [31:0] h;input [127:0] d;
 begin mix={h[26:0],h[31:27]} ^ d[31:0] ^
 {d[62:32],d[63]} ^ {d[92:64],d[95:93]} ^ {d[120:96],d[127:121]};end
 endfunction
 stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL),.V_TOTAL(V_TOTAL),
 .FIFO_ADDR_BITS(10),.DEMO_GROUP(GROUP),.DEMO_VIEW(VIEW),.DYNAMIC_MODE(DYNAMIC_MODE)) source(
 .pix_clk(pix_clk),.tx_clk(clk),.rst_n(active),.enable(enable_sync[1]),.mode(mode),
 .tx_valid(sv),.tx_ready(sr),.tx_data(sd),.tx_sof(sof),.tx_eof(eof),
 .tx_frame_id(fid),.overflow(overflow));
 burst writer(.clk(clk),.rst_n(active),.start(state==BOOT && init_done),
 .start_ready(bs_ready),.base_addr(28'd0),.beats(BEATS),
 .in_valid(sv && state==WRITE),.in_ready(sr),.in_data(sd),
 .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
 .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),.done(bd),.error(be));
 fetch reader(.clk(clk),.rst_n(active),
 .start(state==VERIFY_START || (state==READ_START && br_ready)),
 .start_ready(fr_ready),.base_addr(state==VERIFY_START?28'd0:cursor),
 .beats(state==VERIFY_START?BEATS:{23'd0,bytes[12:4]}),
 .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
 .rvalid(rvalid),.rlast(rlast),.rdata(rdata),.out_valid(fv),
 .out_ready(state==VERIFY || (state==READ && bridge_ready)),
 .out_data(data),.out_last(fl),.done(fd),.error(fe));
 bridge page(.wr_clk(clk),.rd_clk(dma_clk),.rst_n(active),
 .start(state==READ_START && fr_ready),.start_ready(br_ready),.bytes(bytes),
 .in_valid(fv && state==READ),.in_ready(bridge_ready),.in_data(data),
 .prepared(prepared),.launch(launch),.rd_req(rd_req),.rd_data(rd_data),
 .rd_valid(rd_valid),.rd_done(rd_done),.wr_done(br_done),.error(br_error));
 always @(posedge clk or negedge rst_n)
 if(!rst_n) req_sync<=0;else req_sync<={req_sync[0],request_toggle};
 always @(posedge pix_clk or negedge active)
 if(!active)enable_sync<=0;else enable_sync<={enable_sync[0],source_enable};
 always @(posedge clk or negedge rst_n)
 if(!rst_n)overflow_sync<=0;else overflow_sync<={overflow_sync[0],overflow};
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin state<=BOOT;timer<=0;write_count<=0;read_count<=0;
 checksum<=0;read_hash<=0;source_enable<=0;seen<=0;bytes<=0;
 cursor<=0;frame_ready<=0;error_code<=0;end
 else if(error_code==0)begin
  if(state!=IDLE && state!=BOOT)timer<=timer+1'b1;else timer<=0;
  if(be || fe || br_error || overflow_sync[1])begin error_code<=8'h01;state<=HALT;end
  else if(state!=BOOT && !init_done)begin error_code<=8'h02;state<=HALT;end
  else if(timer>=TIMEOUT)begin error_code<=8'h03;state<=HALT;end
  else case(state)
   BOOT:if(init_done && bs_ready)begin source_enable<=1;state<=WRITE;end
   WRITE:begin
    if(sv && sr)begin
     checksum<=mix(checksum,sd);write_count<=write_count+1;
     if(sof!=(write_count==0) || eof!=(write_count==BEATS-1))begin
       error_code<=8'h04;state<=HALT;end
     if(eof)source_enable<=0;
    end
    if(bd)begin state<=SETTLE;timer<=0;end
   end
   SETTLE:if(timer==1023)begin state<=VERIFY_START;timer<=0;end
   VERIFY_START:if(fr_ready)begin read_hash<=0;read_count<=0;state<=VERIFY;end
   VERIFY:begin
    if(fv)begin read_hash<=mix(read_hash,data);read_count<=read_count+1;end
    if(fd)begin
     if(read_count!=BEATS || write_count!=BEATS || read_hash!=checksum)begin
      error_code<=8'h05;state<=HALT;
     end else begin frame_ready<=1;state<=IDLE;timer<=0;end
    end
   end
   IDLE:if(req_sync[1]!=seen)begin
    seen<=req_sync[1];bytes<=request_bytes;
    if(request_bytes==0 || request_bytes>4096 || request_bytes[3:0]!=0 ||
       cursor+request_bytes>WIDTH*HEIGHT*2)begin error_code<=8'h06;state<=HALT;end
    else begin state<=READ_START;timer<=0;end
   end
   READ_START:if(fr_ready && br_ready)state<=READ;
   READ:if(fd)state<=RELEASE;
   RELEASE:if(br_done)begin
    if(cursor+bytes==WIDTH*HEIGHT*2)cursor<=0;else cursor<=cursor+bytes;
    state<=IDLE;timer<=0;
   end
   default:state<=HALT;
  endcase
 end else begin frame_ready<=0;source_enable<=0;end
 end
endmodule
