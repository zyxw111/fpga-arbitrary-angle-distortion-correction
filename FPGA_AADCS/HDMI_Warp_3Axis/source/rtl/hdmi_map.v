// Sequential inverse map: affine(output) -> ideal normalized -> Brown lens ->
// source pixel. All internal values Q16.16, inverse focal lengths Q2.30.
// Shared 32x32 multiply uses registered 16-bit partial products. Operands,
// partial products, cross-term sum and final product each have a clock stage.
// Bounds are validated by tools/configure.py; out-of-range samples are black.
module hdmi_map(
 input clk,input rst_n,input start,output ready,
 input [11:0] x,input [11:0] y,
 input signed [31:0] a00,a01,a02,a10,a11,a12,
 input signed [31:0] fx,fy,cx,cy,inv_fx,inv_fy,
 input signed [31:0] k1,k2,k3,p1,p2,
 output reg valid,output reg signed [31:0] map_x,map_y);
 reg [5:0] step;reg [2:0] phase;
 reg signed [31:0] m0,m1;reg signed [63:0] product;
 reg signed [31:0] operand_a,operand_b;
 reg [31:0] low_product;reg signed [31:0] high_product;
 reg signed [32:0] high_low,low_high;
 reg signed [33:0] cross_term;reg signed [63:0] base_product;
 reg signed [31:0] xx,yy,ax,ay,nx,ny,x2,y2,xy,r2,r4,r6,scale;
 reg signed [31:0] tx,ty,dx,dy,term;
 wire signed [31:0] q=product>>>16;
 assign ready=step==0;
 always @(*)begin
  m0=0;m1=0;
  case(step)
   1:begin m0=xx;m1=a00;end
   2:begin m0=yy;m1=a01;end
   3:begin m0=xx;m1=a10;end
   4:begin m0=yy;m1=a11;end
   5:begin m0=ax-cx;m1=inv_fx;end
   6:begin m0=ay-cy;m1=inv_fy;end
   7:begin m0=nx;m1=nx;end
   8:begin m0=ny;m1=ny;end
   9:begin m0=nx;m1=ny;end
   11:begin m0=r2;m1=r2;end
   12:begin m0=r4;m1=r2;end
   13:begin m0=k1;m1=r2;end
   14:begin m0=k2;m1=r4;end
   15:begin m0=k3;m1=r6;end
   16:begin m0=p1;m1=xy<<<1;end
   17:begin m0=p2;m1=r2+(x2<<<1);end
   18:begin m0=p1;m1=r2+(y2<<<1);end
   19:begin m0=p2;m1=xy<<<1;end
   20:begin m0=nx;m1=scale;end
   21:begin m0=ny;m1=scale;end
   22:begin m0=dx;m1=fx;end
   23:begin m0=dy;m1=fy;end
  endcase
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   step<=0;phase<=0;product<=0;valid<=0;map_x<=0;map_y<=0;
   operand_a<=0;operand_b<=0;low_product<=0;high_product<=0;
   high_low<=0;low_high<=0;cross_term<=0;base_product<=0;
   xx<=0;yy<=0;ax<=0;ay<=0;nx<=0;ny<=0;x2<=0;y2<=0;xy<=0;
   r2<=0;r4<=0;r6<=0;scale<=0;tx<=0;ty<=0;dx<=0;dy<=0;term<=0;
  end else begin
   valid<=0;
   if(step==0)begin
    if(start)begin xx<={4'd0,x,16'd0};yy<={4'd0,y,16'd0};step<=1;phase<=0;end
   end else if(phase==0)begin operand_a<=m0;operand_b<=m1;phase<=1;end
   else if(phase==1)begin
    low_product<=operand_a[15:0]*operand_b[15:0];
    high_product<=$signed(operand_a[31:16])*$signed(operand_b[31:16]);
    high_low<=$signed(operand_a[31:16])*$signed({1'b0,operand_b[15:0]});
    low_high<=$signed({1'b0,operand_a[15:0]})*$signed(operand_b[31:16]);
    phase<=2;
   end else if(phase==2)begin
    cross_term<={high_low[32],high_low}+{low_high[32],low_high};
    base_product<={high_product,low_product};phase<=3;
   end else if(phase==3)begin
    product<=base_product+{{14{cross_term[33]}},cross_term,16'd0};phase<=4;
   end else begin
    phase<=0;step<=step+1'b1;
    case(step)
     1:ax<=q;
     2:ax<=ax+q+a02;
     3:ay<=q;
     4:ay<=ay+q+a12;
     5:nx<=product>>>30;
     6:ny<=product>>>30;
     7:x2<=q;
     8:y2<=q;
     9:xy<=q;
     10:r2<=x2+y2;
     11:r4<=q;
     12:r6<=q;
     13:scale<=65536+q;
     14:scale<=scale+q;
     15:scale<=scale+q;
     16:tx<=q;
     17:tx<=tx+q;
     18:ty<=q;
     19:ty<=ty+q;
     20:dx<=q+tx;
     21:dy<=q+ty;
     22:map_x<=($signed(q)+$signed(cx))>>>4;
     23:begin map_y<=($signed(q)+$signed(cy))>>>4;valid<=1;step<=0;end
    endcase
   end
  end
 end
endmodule
