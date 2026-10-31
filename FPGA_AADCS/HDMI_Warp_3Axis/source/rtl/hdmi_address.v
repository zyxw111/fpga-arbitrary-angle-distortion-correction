// Runtime input geometry. Register multiplication separately from addition.
module hdmi_address(input clk,rst_n,in_valid,input signed [31:0] map_x,map_y,
 input [15:0] width,height,output reg out_valid,
 output reg [31:0] a00,a01,a10,a11,output reg [3:0] mask,output reg [11:0] dx,dy);
 wire signed [31:0] x=map_x>>>12,y=map_y>>>12;
 wire x0=x>=0 && x<width,x1=x>=-1 && x<$signed({1'b0,width})-1;
 wire y0=y>=0 && y<height,y1=y>=-1 && y<$signed({1'b0,height})-1;
 reg valid;reg [31:0] row;reg signed [31:0] column;reg [15:0] pitch;
 reg [3:0] mask_q;reg [11:0] dx_q,dy_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin valid<=0;out_valid<=0;row<=0;column<=0;pitch<=0;
  mask_q<=0;dx_q<=0;dy_q<=0;a00<=0;a01<=0;a10<=0;a11<=0;mask<=0;dx<=0;dy<=0;end
 else begin
  valid<=in_valid;row<=y*width;column<=x;pitch<=width;
  mask_q<={x1&&y1,x0&&y1,x1&&y0,x0&&y0};dx_q<=map_x[11:0];dy_q<=map_y[11:0];
  out_valid<=valid;mask<=mask_q;dx<=dx_q;dy<=dy_q;
  a00<=row+column;a01<=row+column+1;a10<=row+column+pitch;a11<=row+column+pitch+1;
 end
endmodule
