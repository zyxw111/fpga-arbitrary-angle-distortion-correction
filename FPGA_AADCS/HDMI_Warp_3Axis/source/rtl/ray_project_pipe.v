// Project two signed Q16.16 ray components by positive Q16.16 Z.
// Stage 1 absolute values; 48 divider stages; stage 50 sign restoration.
// Z>=0.25 and |X/Z|,|Y/Z|<=4 initial bounded view envelope.
module ray_project_pipe(input clk,rst_n,in_valid,
 input signed [31:0] ray_x,ray_y,ray_z,
 output reg out_valid,output reg signed [31:0] norm_x,norm_y,output reg usable);
 reg [31:0] ax,ay,z;reg v,ok,sx,sy;
 wire [31:0] qx,qy;wire vx,vy,bx,by;
 reg [48:0] sign_x,sign_y,allowed;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin ax<=0;ay<=0;z<=0;v<=0;ok<=0;sx<=0;sy<=0;sign_x<=0;sign_y<=0;allowed<=0;end
 else begin
  ax<=ray_x[31]?-ray_x:ray_x;ay<=ray_y[31]?-ray_y:ray_y;
  z<=ray_z;v<=in_valid;ok<=ray_z>=32'sd16384;
  sx<=ray_x[31];sy<=ray_y[31];
  sign_x<={sign_x[47:0],sx};sign_y<={sign_y[47:0],sy};allowed<={allowed[47:0],ok};
 end
 ray_divide_pipe dx(.clk(clk),.rst_n(rst_n),.in_valid(v),.numerator(ax),.denominator(z),.out_valid(vx),.quotient(qx),.invalid(bx));
 ray_divide_pipe dy(.clk(clk),.rst_n(rst_n),.in_valid(v),.numerator(ay),.denominator(z),.out_valid(vy),.quotient(qy),.invalid(by));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin out_valid<=0;norm_x<=0;norm_y<=0;usable<=0;end
 else begin
  out_valid<=vx && vy;
  usable<=allowed[47] && !bx && !by && qx<=262144 && qy<=262144;
  norm_x<=sign_x[47]?-$signed(qx):$signed(qx);
  norm_y<=sign_y[47]?-$signed(qy):$signed(qy);
 end
endmodule
