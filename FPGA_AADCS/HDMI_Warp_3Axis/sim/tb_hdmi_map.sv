`timescale 1ns/1ps
module tb_hdmi_map;
reg clk=0,rst_n=0,start=0;always #5 clk=~clk;
reg [11:0] x,y;reg signed [31:0] c[0:16];
reg [31:0] vectors[0:6899];wire ready,valid;wire signed [31:0] mx,my;
integer i,j,ex,ey,delta;
hdmi_map dut(.clk(clk),.rst_n(rst_n),.start(start),.ready(ready),.x(x),.y(y),
 .a00(c[0]),.a01(c[1]),.a02(c[2]),.a10(c[3]),.a11(c[4]),.a12(c[5]),
 .fx(c[6]),.fy(c[7]),.cx(c[8]),.cy(c[9]),.inv_fx(c[10]),.inv_fy(c[11]),
 .k1(c[12]),.k2(c[13]),.k3(c[14]),.p1(c[15]),.p2(c[16]),
 .valid(valid),.map_x(mx),.map_y(my));
initial begin
 $readmemh("build/sim/map_vectors.hex",vectors);
 #20;rst_n=1;
 for(i=0;i<300;i=i+1)begin
  @(negedge clk);wait(ready);
  x=vectors[i*23];y=vectors[i*23+1];
  for(j=0;j<17;j=j+1)c[j]=vectors[i*23+2+j];
  ex=vectors[i*23+19];ey=vectors[i*23+20];start=1;
  @(negedge clk);start=0;wait(valid);#1;
  delta=mx-ex;if(delta!=0)$fatal(1,"map x i=%0d got=%0d expected=%0d",i,mx,ex);
  delta=my-ey;if(delta!=0)$fatal(1,"map y i=%0d got=%0d expected=%0d",i,my,ey);
  ex=vectors[i*23+21];ey=vectors[i*23+22];
  delta=mx-ex;if(delta>1024 || delta< -1024)$fatal(1,"float map x error %0d",delta);
  delta=my-ey;if(delta>1024 || delta< -1024)$fatal(1,"float map y error %0d",delta);
 end
 $display("PASS 300 inverse-affine/Brown coordinates exact versus independent fixed model; <=1/4 pixel versus float model incl k1,k2,k3,p1,p2, negative borders, non-square focal lengths");$finish;
end
initial begin #1000000;$fatal(1,"map timeout");end
endmodule
