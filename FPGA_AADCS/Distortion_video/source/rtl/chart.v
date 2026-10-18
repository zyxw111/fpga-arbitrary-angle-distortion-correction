// Procedural synthetic camera image, eight registered stages, 1 pixel/clock.
// Approximate inverse of Brown k1=-1/4: scale=1+t+3*t^2+12*t^3,
// t=r^2/4. This is a synthetic demonstration lens, not camera calibration.
module chart #(
 parameter integer WIDTH=1920,HEIGHT=1080,
 parameter integer FOCAL_BITS=$clog2(WIDTH),
 parameter integer DISTORTED=1
)(input clk,input rst_n,input in_valid,input [11:0] in_x,in_y,
 output out_valid,output reg [15:0] pixel,output [11:0] out_x,out_y);
 localparam integer GRID_BITS=(FOCAL_BITS>4)?FOCAL_BITS-4:1;
 localparam integer GRID=1<<GRID_BITS;
 localparam integer LINE=(GRID>=16)?GRID/16:1;
 reg [7:0] vp;
 reg [11:0] xp[0:7],yp[0:7];
 reg signed [17:0] nx[0:5],ny[0:5];
 reg signed [35:0] xx,yy;
 reg [17:0] r2;
 reg [15:0] t,t2,td;
 reg [17:0] base,t3;
 reg signed [39:0] product_x,product_y;
 wire [31:0] t_square=t*t;
 wire [31:0] t_cube=t2*td;
 wire [17:0] scale=DISTORTED ? base+12*t3 : 18'd65536;
 wire signed [31:0] ux=($signed(product_x) >>> (32-FOCAL_BITS))+WIDTH/2;
 wire signed [31:0] uy=($signed(product_y) >>> (32-FOCAL_BITS))+HEIGHT/2;
 wire [4:0] bg_r=ux >> ((FOCAL_BITS>4)?FOCAL_BITS-4:0);
 wire [5:0] bg_g=uy >> ((FOCAL_BITS>5)?FOCAL_BITS-5:0);
 reg [15:0] color;
 integer i;
 assign out_valid=vp[7];assign out_x=xp[7];assign out_y=yp[7];
 always @* begin
  if(ux<0 || ux>=WIDTH || uy<0 || uy>=HEIGHT) color=16'h0000;
  else if(ux==WIDTH/2 || uy==HEIGHT/2) color=16'hf800;
  else if((ux&(GRID-1))<LINE || (uy&(GRID-1))<LINE) color=16'hffff;
  else if(ux>WIDTH/4 && ux<WIDTH*3/4 && uy>HEIGHT/3 && uy<HEIGHT*2/3) color=16'h07e0;
  else if(((ux>>GRID_BITS)^(uy>>GRID_BITS))&1) color={bg_r,bg_g,5'd5};
  else color={bg_r,bg_g,5'd10};
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   vp<=0;pixel<=0;xx<=0;yy<=0;r2<=0;t<=0;t2<=0;td<=0;base<=0;t3<=0;
   product_x<=0;product_y<=0;
   for(i=0;i<8;i=i+1)begin xp[i]<=0;yp[i]<=0;end
   for(i=0;i<6;i=i+1)begin nx[i]<=0;ny[i]<=0;end
  end else begin
   vp<={vp[6:0],in_valid};xp[0]<=in_x;yp[0]<=in_y;
   for(i=1;i<8;i=i+1)begin xp[i]<=xp[i-1];yp[i]<=yp[i-1];end
   nx[0]<=($signed({1'b0,in_x})-WIDTH/2) <<< (16-FOCAL_BITS);
   ny[0]<=($signed({1'b0,in_y})-HEIGHT/2) <<< (16-FOCAL_BITS);
   for(i=1;i<6;i=i+1)begin nx[i]<=nx[i-1];ny[i]<=ny[i-1];end
   xx<=nx[0]*nx[0];yy<=ny[0]*ny[0];
   r2<=($signed({1'b0,xx})+$signed({1'b0,yy})) >>> 16;
   t<=r2>>2;
   t2<=t_square>>16;td<=t;
   t3<=t_cube>>16;base<=18'd65536+td+3*t2;
   product_x<=$signed(nx[5])*$signed({1'b0,scale});
   product_y<=$signed(ny[5])*$signed({1'b0,scale});
   pixel<=color;
  end
 end
endmodule
