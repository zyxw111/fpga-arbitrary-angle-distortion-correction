// Complete camera frame -> external DDR -> checked readback -> PCIe pages.
// Hold DDR immutable until every page of that frame has been staged for DMA.
// Bad/short/overflowed camera frames finish native writes using padding and
// are discarded. Camera/FIFO restart never resets an in-flight DDR or PCIe IP.
module camera_frame #(
 parameter integer WIDTH=640,HEIGHT=400,TIMEOUT=268435455,FIFO_BITS=11
)(input pclk,input clk,input dma_clk,input rst_n,input init_done,input camera_ready,
 input vsync,input href,input [7:0] camera_data,
 input request_toggle,input [12:0] request_bytes,
 output reg frame_ready,output reg [7:0] error_code,
 output reg [31:0] checksum,output reg [27:0] cursor,
 output reg [31:0] good_frames,output reg [31:0] dropped_frames,
 output wire [255:0] diagnostics,
 output wire [127:0] debug_verify_data,output wire debug_verify_valid,
 output reg [31:0] native_checksum,
 output prepared,input launch,input rd_req,output [127:0] rd_data,
 output rd_valid,output rd_done,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,input wlast,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,input rlast);
 localparam integer BEATS=WIDTH*HEIGHT/8;
 localparam BOOT=0,WRITE=1,SETTLE=2,VERIFY_START=3,VERIFY=4,
            IDLE=5,READ_START=6,READ=7,RELEASE=8,HALT=9,RESTART=10;
 reg [3:0] state;
 reg [31:0] timer,write_count,read_count,read_hash;
 reg source_enable,source_run,seen,pad;
 reg [12:0] bytes;
 reg [1:0] req_sync,bad_sync,camera_sync;
 wire sv,sr,sof,eof,source_bad;wire [127:0] sd;
 wire [7:0] source_reason;
 reg [7:0] reason_meta,reason_sync;
 reg [31:0] discard_code,last_reason,last_write,last_read,last_expected,last_actual;
 assign diagnostics={read_hash,read_count,write_count,last_read,last_actual,last_expected,last_write,last_reason};
 wire bs_ready,bd,be,fr_ready,fd,fe,fv,fl,br_ready,br_done,br_error;
 wire [127:0] data;
 assign debug_verify_data=data;
 assign debug_verify_valid=fv && state==VERIFY;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)native_checksum<=0;
  else if(state==VERIFY_START)native_checksum<=0;
  else if(state==VERIFY && rvalid)native_checksum<=mix(native_checksum,rdata);
 wire bridge_ready;
 wire active=rst_n && error_code==0;
 wire source_reset_n=active && source_run;
 wire writer_valid=state==WRITE && (pad || sv);
 wire [127:0] writer_data=pad?128'd0:sd;
 function [31:0] mix;
 input [31:0] h;input [127:0] d;
 begin mix={h[26:0],h[31:27]} ^ d[31:0] ^
 {d[62:32],d[63]} ^ {d[92:64],d[95:93]} ^ {d[120:96],d[127:121]};end
 endfunction
 camera_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.FIFO_BITS(FIFO_BITS)) source(
  .pclk(pclk),.clk(clk),.rst_n(source_reset_n),.enable(source_enable),
  .vsync(vsync),.href(href),.cam_data(camera_data),.valid(sv),
  .ready(sr && state==WRITE && !pad),.data(sd),.sof(sof),.eof(eof),.bad(source_bad),.bad_reason(source_reason));
 burst writer(.clk(clk),.rst_n(active),.start(state==BOOT && init_done && camera_sync[1]),
  .start_ready(bs_ready),.base_addr(28'd0),.beats(BEATS),
  .in_valid(writer_valid),.in_ready(sr),.in_data(writer_data),
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
  if(!rst_n)begin req_sync<=0;bad_sync<=0;camera_sync<=0;reason_meta<=0;reason_sync<=0;end
  else begin req_sync<={req_sync[0],request_toggle};bad_sync<={bad_sync[0],source_bad};
   camera_sync<={camera_sync[0],camera_ready};reason_meta<=source_reason;reason_sync<=reason_meta;end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=RESTART;timer<=0;write_count<=0;read_count<=0;
   checksum<=0;read_hash<=0;source_enable<=0;source_run<=0;seen<=0;bytes<=0;pad<=0;
   cursor<=0;frame_ready<=0;error_code<=0;good_frames<=0;dropped_frames<=0;
   discard_code<=0;last_reason<=0;last_write<=0;last_read<=0;last_expected<=0;last_actual<=0;end
  else if(error_code==0)begin
   if(state!=IDLE && state!=BOOT)timer<=timer+1'b1;else timer<=0;
   if(be || fe || br_error)begin error_code<=8'h01;state<=HALT;frame_ready<=0;end
   else if(state!=BOOT && state!=RESTART && !init_done)begin error_code<=8'h02;state<=HALT;frame_ready<=0;end
   else if(timer>=TIMEOUT && state!=WRITE)begin error_code<=8'h03;state<=HALT;frame_ready<=0;end
   else case(state)
    RESTART:begin
     source_enable<=0;source_run<=0;frame_ready<=0;cursor<=0;discard_code<=0;
     if(timer==31)begin source_run<=1;timer<=0;write_count<=0;read_count<=0;checksum<=0;pad<=0;state<=BOOT;end
    end
    BOOT:if(init_done && camera_sync[1] && bs_ready)begin source_enable<=1;state<=WRITE;timer<=0;end
    WRITE:begin
     if(bad_sync[1] || timer>=TIMEOUT)begin
       pad<=1;source_enable<=0;
       if(!pad) discard_code<=bad_sync[1]?{16'd0,reason_sync,8'h01}:32'd3;
     end
     if(writer_valid && sr)begin
      checksum<=mix(checksum,writer_data);write_count<=write_count+1'b1;
      if(!pad && (sof!=(write_count==0) || eof!=(write_count==BEATS-1)))begin
        pad<=1;discard_code<=2;
      end
      if(!pad && eof)source_enable<=0;
     end
     if(bd)begin
      timer<=0;
      if(pad || bad_sync[1])begin
       dropped_frames<=dropped_frames+1'b1;state<=RESTART;
       last_reason<=discard_code;last_write<=write_count;last_read<=read_count;
       last_expected<=checksum;last_actual<=read_hash;
      end
      else state<=SETTLE;
     end
    end
    SETTLE:if(timer==1023)begin state<=VERIFY_START;timer<=0;end
    VERIFY_START:if(fr_ready)begin read_hash<=0;read_count<=0;state<=VERIFY;end
    VERIFY:begin
     if(fv)begin read_hash<=mix(read_hash,data);read_count<=read_count+1'b1;end
     if(fd)begin
      if(read_count!=BEATS || write_count!=BEATS || read_hash!=checksum)begin
       dropped_frames<=dropped_frames+1'b1;state<=RESTART;
       last_reason<=4;last_write<=write_count;last_read<=read_count;
       last_expected<=checksum;last_actual<=read_hash;
      end else begin frame_ready<=1;good_frames<=good_frames+1'b1;state<=IDLE;end
      timer<=0;
     end
    end
    IDLE:if(req_sync[1]!=seen)begin
     seen<=req_sync[1];bytes<=request_bytes;
     if(request_bytes==0 || request_bytes>4096 || request_bytes[3:0]!=0 ||
        cursor+request_bytes>WIDTH*HEIGHT*2)begin error_code<=8'h06;state<=HALT;frame_ready<=0;end
     else begin state<=READ_START;timer<=0;end
    end
    READ_START:if(fr_ready && br_ready)state<=READ;
    READ:if(fd)state<=RELEASE;
    RELEASE:if(br_done)begin
     if(cursor+bytes==WIDTH*HEIGHT*2)begin cursor<=0;frame_ready<=0;state<=RESTART;end
     else begin cursor<=cursor+bytes;state<=IDLE;end
     timer<=0;
    end
    default:state<=HALT;
   endcase
  end else begin frame_ready<=0;source_enable<=0;end
 end
endmodule
