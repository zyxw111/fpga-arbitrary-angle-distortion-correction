// Progressive RGB888, all timing measurements in the source pixel clock domain.
// Every VS rising edge is a frame boundary, independent of VS pulse polarity.
// Raw stream is unbuffered: a consumer must commit/discard at frame_end using
// frame_good. Geometry/rate changes, partial or ragged frames deassert lock.
module video_rx(
 input pix_clk,rst_n,input vs,hs,de,input [23:0] rgb,
 output reg pixel_valid,sof,eol,output reg [23:0] pixel_rgb,
 output reg [15:0] pixel_x,pixel_y,
 output reg frame_end,frame_good,output reg [319:0] frame_record);
 reg [1:0] reset_pipe;
 reg vs_sample,hs_sample,de_sample;
 reg [23:0] rgb_sample;
 reg vs_previous,hs_previous,de_previous,seen_frame;
 reg [15:0] line_pixels,lines,width,h_period,line_clock;
 reg [31:0] pixels,period,checksum,frames,bad_frames,changes;
 reg [15:0] previous_width,previous_height;
 reg [31:0] previous_period;
 reg previous_good,ragged;
 wire v_edge=vs_sample && !vs_previous;
 wire h_edge=hs_sample && !hs_previous;
 wire line_end=!de_sample && de_previous;
 wire good=seen_frame && !ragged && !de_sample && !de_previous && width!=0 && lines!=0 && period!=32'hffffffff;
 wire [31:0] tolerance=(previous_period>>7)+1'b1;
 wire [31:0] period_delta=(period>previous_period)?period-previous_period:previous_period-period;
 wire same_mode=previous_good && width==previous_width && lines==previous_height && period_delta<=tolerance;
 wire stable_frame=good && same_mode;
 // Capture the HDMIK parallel bus on the opposite clock edge, then process
 // the held sample on the rising edge. Rising-edge capture showed ragged
 // 1919/1920-pixel lines at 148.5 MHz on this board; validate falling capture
 // on hardware rather than treating unconstrained external inputs as signed off.
 always @(negedge pix_clk or negedge rst_n)
 if(!rst_n)begin
  reset_pipe<=0;vs_sample<=0;hs_sample<=0;de_sample<=0;rgb_sample<=0;
 end else begin
  reset_pipe<={reset_pipe[0],1'b1};
  vs_sample<=vs;hs_sample<=hs;de_sample<=de;rgb_sample<=rgb;
 end
 always @(posedge pix_clk or negedge rst_n)
 if(!rst_n)begin
  vs_previous<=0;hs_previous<=0;de_previous<=0;seen_frame<=0;
  line_pixels<=0;lines<=0;width<=0;h_period<=0;line_clock<=0;
  pixels<=0;period<=0;checksum<=0;frames<=0;bad_frames<=0;changes<=0;
  previous_width<=0;previous_height<=0;previous_period<=0;previous_good<=0;ragged<=0;
  pixel_valid<=0;pixel_rgb<=0;pixel_x<=0;pixel_y<=0;sof<=0;eol<=0;
  frame_end<=0;frame_good<=0;frame_record<=0;
 end else if(reset_pipe[1])begin
  vs_previous<=vs_sample;hs_previous<=hs_sample;de_previous<=de_sample;
  pixel_valid<=0;sof<=0;eol<=0;frame_end<=0;frame_good<=0;
  if(period!=32'hffffffff)period<=period+1'b1;
  if(line_clock!=16'hffff)line_clock<=line_clock+1'b1;
  if(h_edge)begin h_period<=line_clock+1'b1;line_clock<=0;end
  if(de_sample && seen_frame)begin
   pixel_valid<=1;pixel_rgb<=rgb_sample;pixel_x<=line_pixels;pixel_y<=lines;
   sof<=(lines==0 && line_pixels==0);
   if(line_pixels==16'hffff || pixels==32'hffffffff)ragged<=1;
   else begin line_pixels<=line_pixels+1'b1;pixels<=pixels+1'b1;end
   checksum<={checksum[26:0],checksum[31:27]}^{8'd0,rgb_sample};
  end
  if(line_end && seen_frame)begin
   eol<=1;
   if(lines==0)width<=line_pixels;
   else if(width!=line_pixels)ragged<=1;
   if(lines==16'hffff)ragged<=1;else lines<=lines+1'b1;
   line_pixels<=0;
  end
  if(v_edge)begin
   frame_end<=seen_frame;frame_good<=stable_frame;
   if(seen_frame)begin
    frames<=frames+1'b1;
    if(!good)bad_frames<=bad_frames+1'b1;
    if(good && previous_good && !same_mode)changes<=changes+1'b1;
    frame_record<={{31'd0,stable_frame},{8'd0,pixel_rgb},changes,bad_frames,frames+1'b1,checksum,
                    {16'd0,h_period},period+1'b1,pixels,{lines,width}};
   end
   previous_good<=good;previous_width<=width;previous_height<=lines;previous_period<=period;
   seen_frame<=1;lines<=0;line_pixels<=0;width<=0;pixels<=0;period<=0;checksum<=0;ragged<=0;
  end
 end
endmodule
