// Compute inverse Brown coordinates once per mode/parameter generation.
// Tile order is 32 columns x 8 rows; one signed Q20.12 XY pair per 64 bits.
// DDR LUT starts at 32 MiB; source/output frame pools occupy the lower 28 MiB.
module warp_lut #(parameter [27:0] BASE=28'h2000000)(
 input clk,rst_n,start,input [15:0] width,height,input [543:0] config_bank,
 output ready,output reg done,output error,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,wlast);
 localparam IDLE=0,MAP=1,WAIT=2,SEND=3,FINISH=4,PREPARE=5,COUNT=6,BEGIN_WRITE=7;
 reg [2:0] state;reg [15:0] tx,ty;reg [7:0] pixel_index;
 reg [63:0] lower;reg [127:0] word;reg word_valid;
 wire map_ready,map_valid;wire signed [31:0] mx,my;
 wire [11:0] x=tx+{7'd0,pixel_index[4:0]};
 wire [11:0] y=ty+{9'd0,pixel_index[7:5]};
 wire writer_ready,writer_take,writer_done,writer_error;
 reg [15:0] padded_height;reg [31:0] padded_pixels;
 assign ready=state==IDLE && writer_ready;
 assign error=writer_error;
 hdmi_config #(.RUNTIME(1)) mapper(.clk(clk),.rst_n(rst_n),
  .runtime_config(config_bank),.start(state==MAP && map_ready),.ready(map_ready),
  .x(x),.y(y),.valid(map_valid),.map_x(mx),.map_y(my));
 burst writer(.clk(clk),.rst_n(rst_n),.start(state==BEGIN_WRITE),.start_ready(writer_ready),
  .base_addr(BASE),.beats(padded_pixels>>1),.in_valid(word_valid),.in_ready(writer_take),.in_data(word),
  .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
  .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),.done(writer_done),.error(writer_error));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin state<=IDLE;tx<=0;ty<=0;pixel_index<=0;lower<=0;word<=0;word_valid<=0;done<=0;padded_height<=0;padded_pixels<=0;end
 else begin
  done<=0;
  case(state)
   IDLE:if(start && ready)begin tx<=0;ty<=0;pixel_index<=0;state<=PREPARE;end
   PREPARE:begin padded_height<=(height+16'd7)&16'hfff8;state<=COUNT;end
   COUNT:begin padded_pixels<=width*padded_height;state<=BEGIN_WRITE;end
   BEGIN_WRITE:if(writer_ready)state<=MAP;
   MAP:if(map_ready)state<=WAIT;
   WAIT:if(map_valid)begin
    if(!pixel_index[0])begin lower<={my,mx};pixel_index<=pixel_index+1'b1;state<=MAP;end
    else begin word<={my,mx,lower};word_valid<=1;state<=SEND;end
   end
   SEND:if(writer_take)begin
    word_valid<=0;
    if(pixel_index==255)begin
     pixel_index<=0;
     if(tx+32>=width)begin tx<=0;ty<=ty+8;if(ty+8>=height)state<=FINISH;else state<=MAP;end
     else begin tx<=tx+32;state<=MAP;end
    end else begin pixel_index<=pixel_index+1'b1;state<=MAP;end
   end
   FINISH:if(writer_done)begin done<=1;state<=IDLE;end
  endcase
 end
endmodule
