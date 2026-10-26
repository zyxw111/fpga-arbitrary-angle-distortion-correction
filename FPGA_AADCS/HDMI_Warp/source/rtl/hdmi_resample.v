// DDR-backed four-neighbour inverse warp, then DDR output frame.
// Snapshot implementation: one pixel in flight, four 128-bit cache entries.
// AR uses fetch to absorb returns without an RREADY signal. Writer prebuffers
// complete bursts. Only source region is read, only OUTPUT_BASE is written.
module hdmi_resample #(
 parameter integer IN_WIDTH=640,IN_HEIGHT=480,WIDTH=640,HEIGHT=400,RUNTIME=0,
 parameter [27:0] OUTPUT_BASE=28'h0100000
)(input clk,input rst_n,input start,output ready,output reg done,
 input [543:0] runtime_config,input [15:0] source_width,source_height,
 output error,output reg [31:0] checksum,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,input wlast,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,input rlast);
 localparam IDLE=0,MAP=1,COORD=2,LOOK=3,FSTART=4,FREAD=5,FDONE=6,
            INTERP=7,PIXEL=8,PUSH=9,FINISH=10,EXTRACT=11,ADVANCE=12;
 reg [3:0] state;reg [11:0] x,y;reg [1:0] neighbour;
 wire mready,mvalid,avalid,bvalid;wire signed [31:0] mx,my;
 wire [31:0] a0,a1,a2,a3;
 wire [3:0] amask;wire [11:0] adx,ady;
 reg [31:0] addresses[0:3];reg [3:0] mask;reg [11:0] dx,dy;
 reg [15:0] samples[0:3],pixel;
 reg [27:0] cache_tag[0:3];reg [127:0] cache_data[0:3];
 reg [3:0] cache_valid;reg [1:0] replace_index;
 reg [127:0] sample_word;reg [2:0] sample_lane;
 wire [27:0] wanted={addresses[neighbour][26:3],4'd0};
 reg hit;reg [127:0] cached;integer i,j;
 always @(*)begin
  hit=0;cached=0;
  for(i=0;i<4;i=i+1)if(cache_valid[i] && cache_tag[i]==wanted)begin hit=1;cached=cache_data[i];end
 end
 wire fready,fvalid,fdone,ferror;wire [127:0] fetched;reg [27:0] read_base;
 wire pready,pvalid,psof,peof,perror;wire [127:0] packed_word;
 wire wready_in,wstart_ready,wdone,werror;wire [15:0] interpolated;
 assign ready=state==IDLE && wstart_ready && !error;
 assign error=ferror || werror || perror;
 function [31:0] mix;
 input [31:0] h;input [127:0] d;
 begin mix={h[26:0],h[31:27]} ^ d[31:0] ^
 {d[62:32],d[63]} ^ {d[92:64],d[95:93]} ^ {d[120:96],d[127:121]};end
 endfunction
 hdmi_config #(.RUNTIME(RUNTIME)) mapper(.runtime_config(runtime_config),.clk(clk),.rst_n(rst_n),.start(state==MAP && mready),
  .ready(mready),.x(x),.y(y),.valid(mvalid),.map_x(mx),.map_y(my));
 hdmi_address address_mapper(
  .width(RUNTIME?source_width:IN_WIDTH[15:0]),.height(RUNTIME?source_height:IN_HEIGHT[15:0]),
  .clk(clk),.rst_n(rst_n),.in_valid(mvalid),.map_x(mx),.map_y(my),
  .out_valid(avalid),.a00(a0),.a01(a1),.a10(a2),.a11(a3),.mask(amask),.dx(adx),.dy(ady));
 fetch reader(.clk(clk),.rst_n(rst_n),.start(state==FSTART),.start_ready(fready),
  .base_addr(read_base),.beats(32'd1),.arvalid(arvalid),.arready(arready),
  .araddr(araddr),.arlen(arlen),.rdata(rdata),.rvalid(rvalid),.rlast(rlast),
  .out_valid(fvalid),.out_ready(state==FREAD),.out_data(fetched),.out_last(),.done(fdone),.error(ferror));
 bilin interpolate(.clk(clk),.rst_n(rst_n),.in_valid(state==INTERP),
  .p00(samples[0]),.p01(samples[1]),.p10(samples[2]),.p11(samples[3]),
  .dx(dx),.dy(dy),.out_valid(bvalid),.pixel(interpolated));
 pack packer(.clk(clk),.rst_n(rst_n),.in_valid(state==PUSH),.in_ready(pready),
  .in_pixel(pixel),.in_sof(x==0 && y==0),.in_eof(x==WIDTH-1 && y==HEIGHT-1),
  .in_frame_id(32'd0),.out_valid(pvalid),.out_ready(wready_in),.out_data(packed_word),
  .out_sof(psof),.out_eof(peof),.out_frame_id(),.frame_error(perror));
 burst writer(.clk(clk),.rst_n(rst_n),.start(start && ready),.start_ready(wstart_ready),
  .base_addr(OUTPUT_BASE),.beats(WIDTH*HEIGHT/8),.in_valid(pvalid),.in_ready(wready_in),
  .in_data(packed_word),.awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
  .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),.done(wdone),.error(werror));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;x<=0;y<=0;neighbour<=0;cache_valid<=0;replace_index<=0;
   mask<=0;dx<=0;dy<=0;pixel<=0;read_base<=0;done<=0;checksum<=0;sample_word<=0;sample_lane<=0;
   for(j=0;j<4;j=j+1)begin addresses[j]<=0;samples[j]<=0;cache_tag[j]<=0;cache_data[j]<=0;end
  end else begin
   done<=0;
   if(pvalid && wready_in)checksum<=mix(checksum,packed_word);
   case(state)
    IDLE:if(start && ready)begin x<=0;y<=0;cache_valid<=0;replace_index<=0;checksum<=0;state<=MAP;end
    MAP:if(mready)state<=COORD;
    COORD:if(avalid)begin
     addresses[0]<=a0;addresses[1]<=a1;addresses[2]<=a2;addresses[3]<=a3;
     mask<=amask;dx<=adx;dy<=ady;neighbour<=0;state<=LOOK;
    end
    LOOK:if(!mask[neighbour] || hit)begin
     // Separate tag lookup / 128-bit cache selection from lane extraction
     // and interpolation DSP inputs to close timing at the DDR user clock.
     sample_word<=mask[neighbour]?cached:128'd0;
     sample_lane<=addresses[neighbour][2:0];state<=EXTRACT;
    end else begin read_base<=wanted;state<=FSTART;end
    FSTART:if(fready)state<=FREAD;
    FREAD:if(fvalid)begin
     cache_valid[replace_index]<=1;cache_tag[replace_index]<=read_base;
     cache_data[replace_index]<=fetched;replace_index<=replace_index+1'b1;
     sample_word<=fetched;sample_lane<=addresses[neighbour][2:0];state<=FDONE;
    end
    FDONE:if(fdone)state<=EXTRACT;
    EXTRACT:begin samples[neighbour]<=sample_word>>(sample_lane*16);state<=ADVANCE;end
    ADVANCE:if(neighbour==3)state<=INTERP;else begin neighbour<=neighbour+1'b1;state<=LOOK;end
    INTERP:state<=PIXEL;
    PIXEL:if(bvalid)begin pixel<=interpolated;state<=PUSH;end
    PUSH:if(pready)begin
     if(x==WIDTH-1)begin x<=0;y<=y+1'b1;if(y==HEIGHT-1)state<=FINISH;else state<=MAP;end
     else begin x<=x+1'b1;state<=MAP;end
    end
    FINISH:if(wdone)begin done<=1;state<=IDLE;end
   endcase
  end
 end
endmodule
