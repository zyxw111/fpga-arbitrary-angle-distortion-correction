`timescale 1ns/1ps
module tb_affine;
 reg clk=0,rst_n=0,in_valid=0;
 always #4 clk=~clk;
 reg [11:0] in_x=0,in_y=0;
 reg signed [31:0] a00=0,a01=0,a02=0,a10=0,a11=0,a12=0;
 wire out_valid,overflow;
 wire signed [31:0] map_x_q12,map_y_q12;
 reg [281:0] vectors[0:255];
 reg [31:0] expected_x,expected_y;
 reg expected_overflow;
 reg [2:0] valid_ref;
 reg [31:0] x_ref[0:2],y_ref[0:2];
 reg [2:0] overflow_ref;
 integer i,j,checked=0;
 affine_coord dut(.*);
 always @(posedge clk)begin
  if(!rst_n)begin
   valid_ref<=0;overflow_ref<=0;
   for(j=0;j<3;j=j+1)begin x_ref[j]<=0;y_ref[j]<=0;end
  end else begin
   valid_ref<={valid_ref[1:0],in_valid};
   overflow_ref<={overflow_ref[1:0],expected_overflow};
   x_ref[0]<=expected_x;y_ref[0]<=expected_y;
   for(j=1;j<3;j=j+1)begin x_ref[j]<=x_ref[j-1];y_ref[j]<=y_ref[j-1];end
  end
  #1;
  if(out_valid!==valid_ref[2])$fatal(1,"affine valid latency/reset mismatch");
  if(out_valid)begin
   if(map_x_q12!==x_ref[2] || map_y_q12!==y_ref[2] || overflow!==overflow_ref[2])
    $fatal(1,"affine mismatch x=%h/%h y=%h/%h overflow=%b/%b",map_x_q12,x_ref[2],map_y_q12,y_ref[2],overflow,overflow_ref[2]);
   checked=checked+1;
  end
 end
 initial begin
  $readmemh("sim/affine_vectors.hex",vectors);
  repeat(3)@(negedge clk);rst_n=1;
  for(i=0;i<256;i=i+1)begin
   @(negedge clk);
   {in_valid,expected_overflow,expected_y,expected_x,a12,a11,a10,a02,a01,a00,in_y,in_x}=vectors[i];
   if(i==127)begin
    #1;rst_n=0;repeat(2)@(negedge clk);in_valid=0;rst_n=1;
   end
  end
  @(negedge clk);in_valid=0;
  repeat(5)@(negedge clk);
  if(checked<150 || out_valid)$fatal(1,"affine stream did not drain: %0d",checked);
  $display("PASS affine: %0d exact coordinates, arbitrary angles, one per clock, bubbles, signed rounding, saturation and reset",checked);
  $finish;
 end
 initial begin #10000;$fatal(1,"affine timeout");end
endmodule
