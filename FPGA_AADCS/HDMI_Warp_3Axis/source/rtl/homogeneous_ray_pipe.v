// Prototype only: homogeneous normalized-ray coefficients precomputed on ARM.
// h = R * inverse(K_output), signed Q2.30. Pixel inputs are unsigned integers.
// Three cycles, one ray/clock. Coefficients must remain frame-stable.
module homogeneous_ray_pipe(input clk,rst_n,in_valid,input [11:0] x,y,
 input [287:0] h_matrix,output out_valid,output reg signed [31:0] rx,ry,rz);
 reg signed [44:0] px[0:2],py[0:2];
 reg signed [46:0] sums[0:2];reg [2:0] valid;
 assign out_valid=valid[2];
 genvar i;
 generate for(i=0;i<3;i=i+1)begin:row
  wire signed [31:0] h0=h_matrix[(i*3)*32+:32];
  wire signed [31:0] h1=h_matrix[(i*3+1)*32+:32];
  wire signed [31:0] h2=h_matrix[(i*3+2)*32+:32];
  always @(posedge clk)begin
   px[i]<=$signed({1'b0,x})*h0;
   py[i]<=$signed({1'b0,y})*h1;
   sums[i]<={{2{px[i][44]}},px[i]}+{{2{py[i][44]}},py[i]}+{{15{h2[31]}},h2};
  end
 end endgenerate
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin valid<=0;rx<=0;ry<=0;rz<=0;end
 else begin valid<={valid[1:0],in_valid};rx<=sums[0]>>>14;ry<=sums[1]>>>14;rz<=sums[2]>>>14;end
endmodule
