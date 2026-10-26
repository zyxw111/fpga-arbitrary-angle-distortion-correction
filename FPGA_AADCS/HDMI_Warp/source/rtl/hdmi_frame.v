// HDMI RGB888 frame with DDR-backed inverse warp -> external DDR -> checked readback -> PCIe pages.
// Hold DDR immutable until every page of that frame has been staged for DMA.
// Bad/short/overflowed input frames finish native writes using padding and
// are discarded. Camera/FIFO restart never resets an in-flight DDR or PCIe IP.
module hdmi_frame #(
 parameter integer WIDTH=640,HEIGHT=400,IN_WIDTH=640,IN_HEIGHT=480,VS_ACTIVE_HIGH=0,TIMEOUT=268435455,FIFO_BITS=11,
 parameter RUNTIME=0,USE_RX_STREAM=0,parameter [27:0] OUTPUT_BASE=28'h0100000
)(input pclk,input clk,input dma_clk,input rst_n,input init_done,input camera_ready,
 input vsync,input de,input [23:0] rgb,
 input [543:0] runtime_config,input [31:0] active_generation,
 input [15:0] input_width,input_height,input pixel_valid,pixel_sof,
 input [23:0] pixel_rgb,input [15:0] pixel_x,pixel_y,input frame_end,frame_good,
 output frame_safe,output reg [31:0] published_generation,
 output reg [15:0] source_width,source_height,
 input request_toggle,input [12:0] request_bytes,
 output reg frame_ready,output reg [7:0] error_code,
 output reg [31:0] checksum,output reg [27:0] cursor,
 output reg [31:0] good_frames,output reg [31:0] dropped_frames,
 output [255:0] diagnostics,output reg [31:0] native_checksum,
 output prepared,input launch,input rd_req,output [127:0] rd_data,
 output rd_valid,output rd_done,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,input wlast,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,input rlast);
 reg [31:0] capture_beats;
 wire [31:0] BEATS=capture_beats;
 wire [31:0] input_pixels=input_width*input_height;
 localparam integer OUT_BEATS=WIDTH*HEIGHT/8;

 localparam BOOT=0,WRITE=1,SETTLE=2,VERIFY_START=3,VERIFY=4,
            IDLE=5,READ_START=6,READ=7,RELEASE=8,HALT=9,RESTART=10,PROCESS_START=11,PROCESS=12,PREPARE=13,VERIFY_DONE=14;
 reg [3:0] state;reg processed,verify_ok;
 assign frame_safe=state==RESTART || state==BOOT || state==IDLE;
 wire active=rst_n && error_code==0;
 wire processing=state==PROCESS_START || state==PROCESS;
 wire pav,prv,pdone,pready,perror;wire [31:0] phash;
 wire [27:0] paa,pra,caa,cra;wire [3:0] pal,prlen,cal,crlen;
 wire [127:0] pwd,cwd;wire [15:0] pws,cws;wire cav,crv;
 assign awvalid=processing?pav:cav;assign awaddr=processing?paa:caa;assign awlen=processing?pal:cal;
 assign wdata=processing?pwd:cwd;assign wstrb=processing?pws:cws;
 assign arvalid=processing?prv:crv;assign araddr=processing?pra:cra;assign arlen=processing?prlen:crlen;
 hdmi_resample #(.IN_WIDTH(IN_WIDTH),.IN_HEIGHT(IN_HEIGHT),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.RUNTIME(RUNTIME),.OUTPUT_BASE(OUTPUT_BASE)) processor(
  .runtime_config(runtime_config),.source_width(source_width),.source_height(source_height),
  .clk(clk),.rst_n(active),.start(state==PROCESS_START),.ready(pready),.done(pdone),.error(perror),.checksum(phash),
  .awvalid(pav),.awready(awready && processing),.awaddr(paa),.awlen(pal),
  .wdata(pwd),.wstrb(pws),.wready(wready && processing),.wlast(wlast),
  .arvalid(prv),.arready(arready && processing),.araddr(pra),.arlen(prlen),
  .rdata(rdata),.rvalid(rvalid && processing),.rlast(rlast));
 reg [31:0] timer,write_count,read_count,read_hash;
 reg timeout_expired;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)timeout_expired<=0;else timeout_expired<=timer>=TIMEOUT;
 reg [31:0] last_reason,last_write,last_expected,last_actual,last_read;
 assign diagnostics={read_hash,read_count,write_count,last_read,last_actual,last_expected,last_write,last_reason};
 always @(posedge clk or negedge rst_n)
  if(!rst_n)native_checksum<=0;
  else if(state==VERIFY_START)native_checksum<=0;
  else if(state==VERIFY && rvalid)native_checksum<=mix(native_checksum,rdata);
 reg source_enable,source_run,seen,pad;
 reg [12:0] bytes;
 reg [1:0] req_sync,bad_sync;
 reg camera_ready_meta /* synthesis syn_preserve=1 */;
 reg camera_ready_sync /* synthesis syn_preserve=1 */;
 wire sv,sr,sof,eof,source_bad;wire [127:0] sd;
 wire bs_ready,bd,be,fr_ready,fd,fe,fv,fl,br_ready,br_done,br_error;
 wire [127:0] data;
 wire bridge_ready;
 wire source_reset_n=active && source_run;
 wire writer_valid=state==WRITE && (pad || sv);
 wire [127:0] writer_data=pad?128'd0:sd;
 function [31:0] mix;
 input [31:0] h;input [127:0] d;
 begin mix={h[26:0],h[31:27]} ^ d[31:0] ^
 {d[62:32],d[63]} ^ {d[92:64],d[95:93]} ^ {d[120:96],d[127:121]};end
 endfunction
 generate if(USE_RX_STREAM)begin:rx_source
 hdmi_rx_stream #(.FIFO_BITS(FIFO_BITS)) source(
  .pclk(pclk),.clk(clk),.rst_n(source_reset_n),.enable(source_enable),
  .width(source_width),.height(source_height),.pixel_valid(pixel_valid),.sof(pixel_sof),
  .pixel_rgb(pixel_rgb),.pixel_x(pixel_x),.pixel_y(pixel_y),.frame_end(frame_end),.frame_good(frame_good),
  .valid(sv),.ready(sr && state==WRITE && !pad),.data(sd),.out_sof(sof),.out_eof(eof),.bad(source_bad));
 end else begin:legacy_source
 hdmi_stream #(.WIDTH(IN_WIDTH),.HEIGHT(IN_HEIGHT),.FIFO_BITS(FIFO_BITS),.VS_ACTIVE_HIGH(VS_ACTIVE_HIGH)) source(
  .pclk(pclk),.clk(clk),.rst_n(source_reset_n),.enable(source_enable),
  .vsync(vsync),.de(de),.rgb(rgb),.valid(sv),
  .ready(sr && state==WRITE && !pad),.data(sd),.sof(sof),.eof(eof),.bad(source_bad));
 end endgenerate
 burst writer(.clk(clk),.rst_n(active),.start(state==PREPARE),
  .start_ready(bs_ready),.base_addr(28'd0),.beats(BEATS),
  .in_valid(writer_valid),.in_ready(sr),.in_data(writer_data),
  .awvalid(cav),.awready(awready && !processing),.awaddr(caa),.awlen(cal),
  .wdata(cwd),.wstrb(cws),.wready(wready && !processing),.wlast(wlast),.done(bd),.error(be));
 fetch reader(.clk(clk),.rst_n(active),
  .start(state==VERIFY_START || (state==READ_START && br_ready)),
  .start_ready(fr_ready),.base_addr(OUTPUT_BASE+(state==VERIFY_START?28'd0:cursor)),
  .beats(state==VERIFY_START?OUT_BEATS:{23'd0,bytes[12:4]}),
  .arvalid(crv),.arready(arready && !processing),.araddr(cra),.arlen(crlen),
  .rvalid(rvalid && !processing),.rlast(rlast),.rdata(rdata),.out_valid(fv),
  .out_ready(state==VERIFY || (state==READ && bridge_ready)),
  .out_data(data),.out_last(fl),.done(fd),.error(fe));
 bridge page(.wr_clk(clk),.rd_clk(dma_clk),.rst_n(active),
  .start(state==READ_START && fr_ready),.start_ready(br_ready),.bytes(bytes),
  .in_valid(fv && state==READ),.in_ready(bridge_ready),.in_data(data),
  .prepared(prepared),.launch(launch),.rd_req(rd_req),.rd_data(rd_data),
  .rd_valid(rd_valid),.rd_done(rd_done),.wr_done(br_done),.error(br_error));
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin req_sync<=0;bad_sync<=0;camera_ready_meta<=0;camera_ready_sync<=0;end
  else begin req_sync<={req_sync[0],request_toggle};bad_sync<={bad_sync[0],source_bad};
   camera_ready_meta<=camera_ready;camera_ready_sync<=camera_ready_meta;end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=RESTART;processed<=0;verify_ok<=0;timer<=0;write_count<=0;read_count<=0;
   checksum<=0;read_hash<=0;source_enable<=0;source_run<=0;seen<=0;bytes<=0;pad<=0;
   cursor<=0;frame_ready<=0;error_code<=0;good_frames<=0;dropped_frames<=0;
   last_reason<=0;last_write<=0;last_expected<=0;last_actual<=0;last_read<=0;published_generation<=0;
   source_width<=IN_WIDTH;source_height<=IN_HEIGHT;capture_beats<=IN_WIDTH*IN_HEIGHT/8;end
  else if(error_code==0)begin
   if(state!=IDLE && state!=BOOT)timer<=timer+1'b1;else timer<=0;
   if(be || fe || br_error || perror)begin error_code<=8'h01;state<=HALT;frame_ready<=0;end
   else if(state!=BOOT && state!=RESTART && !init_done)begin error_code<=8'h02;state<=HALT;frame_ready<=0;end
   else if(timeout_expired && state!=WRITE)begin error_code<=8'h03;state<=HALT;frame_ready<=0;end
   else case(state)
    RESTART:begin
     source_enable<=0;source_run<=0;frame_ready<=0;cursor<=0;processed<=0;
     if(timer==31)begin source_run<=1;timer<=0;write_count<=0;read_count<=0;checksum<=0;pad<=0;state<=BOOT;end
    end
    BOOT:if(init_done && camera_ready_sync && bs_ready)begin
     if(!RUNTIME || (input_width>=8 && input_width<=1920 && input_height>=8 && input_height<=1080 && input_pixels[6:0]==0))begin
      source_width<=RUNTIME?input_width:IN_WIDTH;source_height<=RUNTIME?input_height:IN_HEIGHT;
      capture_beats<=RUNTIME?(input_pixels>>3):IN_WIDTH*IN_HEIGHT/8;
      state<=PREPARE;timer<=0;
     end
    end
    PREPARE:begin source_enable<=1;state<=WRITE;timer<=0;end
    WRITE:begin
     if(bad_sync[1] || timeout_expired)begin pad<=1;source_enable<=0;end
     if(writer_valid && sr)begin
      checksum<=mix(checksum,writer_data);write_count<=write_count+1'b1;
      if(!pad && (sof!=(write_count==0) || eof!=(write_count==BEATS-1)))pad<=1;
      if(!pad && eof)source_enable<=0;
     end
     if(bd)begin
      timer<=0;
      if(pad || bad_sync[1])begin
       dropped_frames<=dropped_frames+1'b1;state<=RESTART;
       last_reason<=1;last_write<=write_count;last_expected<=checksum;last_actual<=read_hash;last_read<=read_count;
      end
      else state<=SETTLE;
     end
    end
    SETTLE:if(timer==1023)begin state<=processed?VERIFY_START:PROCESS_START;timer<=0;end
    PROCESS_START:if(pready)begin published_generation<=active_generation;state<=PROCESS;timer<=0;end
    PROCESS:if(pdone)begin checksum<=phash;processed<=1;state<=SETTLE;timer<=0;end
    VERIFY_START:if(fr_ready)begin read_hash<=0;read_count<=0;state<=VERIFY;end
    VERIFY:begin
     if(fv)begin read_hash<=mix(read_hash,data);read_count<=read_count+1'b1;end
     if(fd)begin
      verify_ok<=read_count==OUT_BEATS && write_count==BEATS && read_hash==checksum;
      state<=VERIFY_DONE;timer<=0;
     end
    end
    VERIFY_DONE:begin
      if(!verify_ok)begin
       dropped_frames<=dropped_frames+1'b1;state<=RESTART;
       last_reason<=4;last_write<=write_count;last_expected<=checksum;last_actual<=read_hash;last_read<=read_count;
      end else begin frame_ready<=1;good_frames<=good_frames+1'b1;state<=IDLE;end
      timer<=0;
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
