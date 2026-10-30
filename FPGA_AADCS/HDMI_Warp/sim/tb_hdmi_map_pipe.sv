`timescale 1ns/1ps
module tb_hdmi_map_pipe;
 reg clk=0,rst_n=0,iv=0,stream=0;always #4 clk=~clk;
 reg [11:0] x=0,y=0;reg [543:0] config_bank=0;
 wire ov;wire signed [31:0] mx,my;wire [543:0] defaults;
 hdmi_defaults defaults_inst(.defaults(defaults));
 hdmi_map_pipe dut(.clk(clk),.rst_n(rst_n),.in_valid(iv),.config_bank(config_bank),.x(x),.y(y),.out_valid(ov),.map_x(mx),.map_y(my));
 reg [31:0] vectors[0:6899];reg [127:0] maps[0:1279];
 integer i,j,checked=0,tx,ty;reg [63:0] expected;
 always @(posedge clk)begin
  #1;if(stream && ov)begin
   expected=checked[0]?maps[checked/2][127:64]:maps[checked/2][63:0];
   if({my,mx}!==expected)$fatal(1,"stream map %0d got=%h expected=%h",checked,{my,mx},expected);
   checked=checked+1;
  end
 end
 initial begin
  $readmemh("build/sim/map_vectors.hex",vectors);$readmemh("build/sim/native_lut.hex",maps);
  repeat(5)@(negedge clk);rst_n=1;
  for(i=0;i<300;i=i+1)begin
   @(negedge clk);x=vectors[i*23];y=vectors[i*23+1];
   for(j=0;j<17;j=j+1)config_bank[j*32+:32]=vectors[i*23+2+j];
   iv=1;@(negedge clk);iv=0;wait(ov);#1;
   if(mx!==vectors[i*23+19] || my!==vectors[i*23+20])$fatal(1,"random coordinate %0d got=%0d/%0d expected=%0d/%0d",i,mx,my,$signed(vectors[i*23+19]),$signed(vectors[i*23+20]));
  end
  repeat(64)@(negedge clk);config_bank=defaults;stream=1;
  for(i=0;i<2560;i=i+1)begin
   @(negedge clk);tx=(i/256)%2*32;ty=(i/256)/2*8;
   x=tx+i%32;y=ty+(i%256)/32;iv=1;
   if(i%29==7)begin @(negedge clk);iv=0;end
  end
  @(negedge clk);iv=0;wait(checked==2560);
  $display("PASS exact pipelined Brown: 300 random parameter sets and 2560 consecutive/bubbled coordinates; original truncation, tangential terms, rotation and black borders");$finish;
 end
 initial begin #1000000;$fatal(1,"map pipeline timeout");end
endmodule
