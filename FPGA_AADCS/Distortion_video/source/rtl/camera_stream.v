`timescale 1ns/1ps
// Capture ONE complete RGB565 DVP frame after enable, starting at VSYNC.
// OV5640 0x4300=0x6f sends LOW byte first (RGB565_2X8_LE).
// The final word is published only at the following VSYNC, after checking
// every raw line and byte count. Source cannot be backpressured: on overflow
// set bad and stop; the DDR writer pads/discards this frame before retrying.
module camera_stream #(
 parameter integer WIDTH=640,HEIGHT=400,FIFO_BITS=11
)(input pclk,input clk,input rst_n,input enable,
 input vsync,input href,input [7:0] cam_data,
 output valid,input ready,output [127:0] data,output sof,output eof,
 output reg bad,output reg [7:0] bad_reason);
 reg [1:0] enable_sync,reset_sync;
 reg vsync_d,href_d,phase;
 reg [1:0] state;
 reg [7:0] first_byte;
 reg [12:0] byte_count;
 reg [11:0] line_count;
 reg [31:0] pixel_count;
 reg [2:0] lane;
 reg [111:0] partial;
 reg [127:0] final_word;
 reg final_pending;
 reg push_valid,push_sof,push_eof;
 reg [127:0] push_data;
 wire push_ready;
 wire source_ok=reset_sync[1];
 wire room=!push_valid || push_ready;
 wire line_ending=href_d && !href;
 wire [12:0] completed_lines={1'b0,line_count}+line_ending;
 wire last_line_ok=line_ending ? byte_count==WIDTH*2 : byte_count==0;
 wire [129:0] fifo_data;
 afifo #(.WIDTH(130),.ADDR_BITS(FIFO_BITS)) fifo(
  .wr_clk(pclk),.rd_clk(clk),.rst_n(rst_n),
  .wr_valid(push_valid),.wr_ready(push_ready),.wr_data({push_eof,push_sof,push_data}),
  .rd_valid(valid),.rd_ready(ready),.rd_data(fifo_data));
 assign {eof,sof,data}=fifo_data;
 always @(posedge pclk or negedge rst_n)
  if(!rst_n)begin enable_sync<=0;reset_sync<=0;end
  else begin enable_sync<={enable_sync[0],enable};reset_sync<={reset_sync[0],1'b1};end
 always @(posedge pclk or negedge rst_n)begin
  if(!rst_n)begin
   state<=0;vsync_d<=0;href_d<=0;phase<=0;first_byte<=0;
   byte_count<=0;line_count<=0;pixel_count<=0;lane<=0;partial<=0;
   final_word<=0;final_pending<=0;push_valid<=0;push_data<=0;
   push_sof<=0;push_eof<=0;bad<=0;bad_reason<=0;
  end else if(source_ok)begin
   vsync_d<=vsync;href_d<=href;
   if(push_valid && push_ready)push_valid<=0;
   if(state==0)begin
    if(enable_sync[1] && vsync && !vsync_d)begin
     state<=1;byte_count<=0;line_count<=0;pixel_count<=0;lane<=0;phase<=0;
    end
   end else if(state==1)begin
    if(vsync && !vsync_d)begin
     state<=2;
     if(!bad && !href && last_line_ok && completed_lines==HEIGHT &&
        pixel_count==WIDTH*HEIGHT && final_pending && room)begin
      push_data<=final_word;push_sof<=WIDTH*HEIGHT==8;push_eof<=1;push_valid<=1;
     end else begin bad<=1;bad_reason[3]<=1;end
    end else if(href && !vsync)begin
     if(byte_count!=8191)byte_count<=byte_count+1'b1;
     if(byte_count>=WIDTH*2 || line_count>=HEIGHT)begin bad<=1;bad_reason[0]<=1;end
     if(!phase)begin first_byte<=cam_data;phase<=1;end
     else begin
      phase<=0;
      if(!bad && byte_count<WIDTH*2 && line_count<HEIGHT)begin
       pixel_count<=pixel_count+1'b1;
       if(lane==7)begin
        lane<=0;
        if(pixel_count==WIDTH*HEIGHT-1)begin
         final_word<={cam_data,first_byte,partial};final_pending<=1;
        end else if(room)begin
         push_data<={cam_data,first_byte,partial};push_sof<=pixel_count==7;
         push_eof<=0;push_valid<=1;
        end else begin bad<=1;bad_reason[1]<=1;end
       end else begin partial[lane*16+:16]<={cam_data,first_byte};lane<=lane+1'b1;end
      end
     end
    end else if(line_ending)begin
     if(byte_count!=WIDTH*2 || phase)begin bad<=1;bad_reason[2]<=1;end
     byte_count<=0;phase<=0;
     if(line_count!=4095)line_count<=line_count+1'b1;else begin bad<=1;bad_reason[4]<=1;end
    end
   end
  end
 end
endmodule
