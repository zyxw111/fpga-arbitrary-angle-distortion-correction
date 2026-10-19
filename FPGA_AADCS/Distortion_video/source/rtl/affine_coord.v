`timescale 1ns/1ps

// Output-to-input affine map, ahead of lens distortion and resampling.
// a00..a12: signed Q16.16, including translation in pixel units.
// Outputs: signed Q20.12, matching addr's source-coordinate interface.
// Latency: 3 rising edges; throughput: one coordinate per clock.
// Coefficients must remain constant for the complete frame.
module affine_coord(
 input wire clk,input wire rst_n,input wire in_valid,
 input wire [11:0] in_x,input wire [11:0] in_y,
 input wire signed [31:0] a00,a01,a02,a10,a11,a12,
 output wire out_valid,
 output reg signed [31:0] map_x_q12,map_y_q12,
 output reg overflow
);
 reg [2:0] valid_pipe;
 reg signed [47:0] xx,xy,yx,yy,sum_x,sum_y;
 reg signed [31:0] tx,ty;
 wire signed [12:0] x={1'b0,in_x},y={1'b0,in_y};
 function signed [47:0] rounded_q12;
  input signed [47:0] value;
  begin
   if(value>=0)rounded_q12=(value+48'sd8)>>>4;
   else rounded_q12=-(((-value)+48'sd8)>>>4);
  end
 endfunction
 wire signed [47:0] rx=rounded_q12(sum_x),ry=rounded_q12(sum_y);
 wire x_over=rx>48'sd2147483647 || rx< -48'sd2147483648;
 wire y_over=ry>48'sd2147483647 || ry< -48'sd2147483648;
 assign out_valid=valid_pipe[2];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   valid_pipe<=0;xx<=0;xy<=0;yx<=0;yy<=0;tx<=0;ty<=0;
   sum_x<=0;sum_y<=0;map_x_q12<=0;map_y_q12<=0;overflow<=0;
  end else begin
   valid_pipe<={valid_pipe[1:0],in_valid};
   xx<=a00*x;xy<=a01*y;yx<=a10*x;yy<=a11*y;tx<=a02;ty<=a12;
   sum_x<=xx+xy+{{16{tx[31]}},tx};
   sum_y<=yx+yy+{{16{ty[31]}},ty};
   map_x_q12<=x_over?(rx[47]?32'sh80000000:32'sh7fffffff):rx[31:0];
   map_y_q12<=y_over?(ry[47]?32'sh80000000:32'sh7fffffff):ry[31:0];
   overflow<=valid_pipe[1] && (x_over || y_over);
  end
 end
endmodule
