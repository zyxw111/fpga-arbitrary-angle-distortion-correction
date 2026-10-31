// RGB888/DE receiver. One immutable frame; final beat waits for next VS edge
// to validate all lines. A stopped/incorrect source is discarded by hdmi_frame.
module hdmi_stream #(
 parameter integer WIDTH=640,HEIGHT=480,FIFO_BITS=11,VS_ACTIVE_HIGH=0
)(input pclk,input clk,input rst_n,input enable,
 input vsync,input de,input [23:0] rgb,
 output valid,input ready,output [127:0] data,output sof,output eof,
 output reg bad);
 reg [1:0] en,reset_sync;
 reg vs_d,de_d;reg [1:0] state;
 reg [12:0] columns,lines;reg [31:0] pixels;
 reg [2:0] lane;reg [111:0] partial;
 reg [127:0] final_word,push_data;reg final_pending,push_valid,push_sof,push_eof;
 wire vs=VS_ACTIVE_HIGH?vsync:!vsync;
 wire line_end=de_d && !de;
 wire [13:0] completed_lines={1'b0,lines}+line_end;
 wire push_ready;
 wire room=!push_valid || push_ready;
 wire [15:0] pixel={rgb[23:19],rgb[15:10],rgb[7:3]};
 wire [129:0] fifo_data;
 afifo #(.WIDTH(130),.ADDR_BITS(FIFO_BITS)) fifo(
  .wr_clk(pclk),.rd_clk(clk),.rst_n(rst_n),.wr_valid(push_valid),
  .wr_ready(push_ready),.wr_data({push_eof,push_sof,push_data}),
  .rd_valid(valid),.rd_ready(ready),.rd_data(fifo_data));
 assign {eof,sof,data}=fifo_data;
 always @(posedge pclk or negedge rst_n)
  if(!rst_n)begin en<=0;reset_sync<=0;end
  else begin en<={en[0],enable};reset_sync<={reset_sync[0],1'b1};end
 always @(posedge pclk or negedge rst_n)begin
  if(!rst_n)begin
   vs_d<=0;de_d<=0;state<=0;columns<=0;lines<=0;pixels<=0;lane<=0;partial<=0;
   final_word<=0;final_pending<=0;push_data<=0;push_valid<=0;push_sof<=0;push_eof<=0;bad<=0;
  end else if(reset_sync[1])begin
   vs_d<=vs;de_d<=de;
   if(push_valid && push_ready)push_valid<=0;
   if(state==0)begin
    if(en[1] && vs && !vs_d)begin state<=1;columns<=0;lines<=0;pixels<=0;end
   end else if(state==1)begin
    if(vs && !vs_d)begin
     state<=2;
     if(!bad && !de && (line_end?columns==WIDTH:columns==0) &&
       completed_lines==HEIGHT && pixels==WIDTH*HEIGHT && final_pending && room)begin
      push_data<=final_word;push_sof<=WIDTH*HEIGHT==8;push_eof<=1;push_valid<=1;
     end else bad<=1;
    end else if(de && !vs)begin
     if(columns!=8191)columns<=columns+1'b1;else bad<=1;
     if(columns>=WIDTH || lines>=HEIGHT)bad<=1;
     if(!bad && columns<WIDTH && lines<HEIGHT)begin
      pixels<=pixels+1'b1;
      if(lane==7)begin
       lane<=0;
       if(pixels==WIDTH*HEIGHT-1)begin final_word<={pixel,partial};final_pending<=1;end
       else if(room)begin
        push_data<={pixel,partial};push_sof<=pixels==7;push_eof<=0;push_valid<=1;
       end else bad<=1;
      end else begin partial[lane*16+:16]<=pixel;lane<=lane+1'b1;end
     end
    end else if(line_end)begin
     if(columns!=WIDTH)bad<=1;
     columns<=0;if(lines!=8191)lines<=lines+1'b1;else bad<=1;
    end
   end
  end
 end
endmodule
