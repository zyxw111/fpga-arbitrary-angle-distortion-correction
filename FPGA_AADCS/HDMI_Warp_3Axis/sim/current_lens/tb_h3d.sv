`timescale 1ns/1ps
module tb_h3d;
reg clk=0;always #4 clk=~clk;
reg rst=0,iv=0;reg [11:0] x,y;reg [543:0] cfg;reg [287:0] h;
wire ov,usable;wire signed [31:0] mx,my;
reg [31:0] vec[0:10751];reg [31:0] cw[0:16];integer i,j,g,received=0;
hdmi_map_h3d_pipe dut(.clk(clk),.rst_n(rst),.in_valid(iv),.x(x),.y(y),.config_bank(cfg),.projection_h(h),.out_valid(ov),.out_usable(usable),.map_x(mx),.map_y(my));
always @(negedge clk)if(ov)begin
 if(mx!==vec[received*14+11] || my!==vec[received*14+12] || usable!==vec[received*14+13][0])$fatal(1,"vector %0d got %h,%h expected %h,%h",received,mx,my,vec[received*14+11],vec[received*14+12]);
 received=received+1;
end
initial begin
 $readmemh("sim/vectors.hex",vec);$readmemh("sim/config.hex",cw);
 for(j=0;j<17;j=j+1)cfg[j*32+:32]=cw[j];
 #20;rst=1;
 for(g=0;g<12;g=g+1)begin
  @(negedge clk);for(j=0;j<9;j=j+1)h[j*32+:32]=vec[g*64*14+2+j];
  for(i=0;i<64;i=i+1)begin
   @(negedge clk);x=vec[(g*64+i)*14];y=vec[(g*64+i)*14+1];iv=1;
   if(i%7==0)begin @(negedge clk);iv=0;end
  end
  @(negedge clk);iv=0;wait(received==(g+1)*64);repeat(2)@(negedge clk);
 end
 $display("PASS %0d bit-exact normalized-homography + perspective + NONZERO Brown vectors",received);$finish;
end
initial begin #2000000;$fatal(1,"timeout");end
endmodule
