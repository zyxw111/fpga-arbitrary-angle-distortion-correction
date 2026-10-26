// Snapshot consumer of the v2 video_rx pixel stream. Final beat is withheld
// until frame_end/frame_good; incomplete or changing-mode frames never publish.
module hdmi_rx_stream #(parameter FIFO_BITS=11)(
 input pclk,clk,rst_n,enable,input [15:0] width,height,
 input pixel_valid,sof,input [23:0] pixel_rgb,input [15:0] pixel_x,pixel_y,
 input frame_end,frame_good,
 output valid,input ready,output [127:0] data,output out_sof,out_eof,output reg bad);
 reg [1:0] en,reset_sync;reg [1:0] state;
 reg [31:0] count,total;reg [15:0] expected_width,expected_height;
 reg [2:0] lane;reg [111:0] partial;reg [127:0] final_word,push_data;
 reg final_pending,push_valid,push_sof,push_eof;
 wire push_ready;wire room=!push_valid || push_ready;
 wire [15:0] pixel={pixel_rgb[23:19],pixel_rgb[15:10],pixel_rgb[7:3]};
 wire [129:0] fifo_data;
 afifo #(.WIDTH(130),.ADDR_BITS(FIFO_BITS)) fifo(
  .wr_clk(pclk),.rd_clk(clk),.rst_n(rst_n),.wr_valid(push_valid),.wr_ready(push_ready),
  .wr_data({push_eof,push_sof,push_data}),.rd_valid(valid),.rd_ready(ready),.rd_data(fifo_data));
 assign {out_eof,out_sof,data}=fifo_data;
 always @(posedge pclk or negedge rst_n)
 if(!rst_n)begin en<=0;reset_sync<=0;end
 else begin en<={en[0],enable};reset_sync<={reset_sync[0],1'b1};end
 always @(posedge pclk or negedge rst_n)
 if(!rst_n)begin
  state<=0;count<=0;total<=0;expected_width<=0;expected_height<=0;
  lane<=0;partial<=0;final_word<=0;final_pending<=0;push_data<=0;
  push_valid<=0;push_sof<=0;push_eof<=0;bad<=0;
 end else if(reset_sync[1])begin
  if(push_valid && push_ready)push_valid<=0;
  if(state==0 && en[1] && pixel_valid && sof)begin
   expected_width<=width;expected_height<=height;total<=width*height;
   partial[15:0]<=pixel;lane<=1;count<=1;state<=1;
  end else if(state==1)begin
   if(frame_end)begin
    state<=2;
    if(frame_good && !bad && count==total && final_pending && room)begin
     push_data<=final_word;push_sof<=0;push_eof<=1;push_valid<=1;
    end else bad<=1;
   end else if(pixel_valid)begin
    // video_rx independently checks each full raster, including ragged lines.
    if(sof || pixel_x>=expected_width || pixel_y>=expected_height || count>=total)bad<=1;
    if(!bad && count<total)begin
     count<=count+1'b1;
     if(lane==7)begin
      lane<=0;
      if(count==total-1)begin final_word<={pixel,partial};final_pending<=1;end
      else if(room)begin push_data<={pixel,partial};push_sof<=count==7;push_eof<=0;push_valid<=1;end
      else bad<=1;
     end else begin partial[lane*16+:16]<=pixel;lane<=lane+1'b1;end
    end
   end
  end
 end
endmodule
