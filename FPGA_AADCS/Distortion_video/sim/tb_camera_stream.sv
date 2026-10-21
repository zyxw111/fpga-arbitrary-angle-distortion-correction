`timescale 1ns/1ps
module tb_camera_stream;
 reg pclk=0,clk=0,rst_n=0,enable=1,vsync=0,href=0,ready=1;
 reg [7:0] cam_data=0;
 always #10 pclk=~pclk;always #7 clk=~clk;
 wire valid,sof,eof,bad;wire [127:0] data;
 integer received=0,endings=0,j;
 camera_stream #(.WIDTH(16),.HEIGHT(4),.FIFO_BITS(2)) dut(.*);
 always @(posedge clk)if(rst_n && valid && ready)begin
  for(j=0;j<8;j=j+1)if(data[j*16+:16]!==16'(received*8+j))$fatal(1,"DVP lane/order %0d",received);
  if(sof!==(received==0))$fatal(1,"camera SOF");
  if(eof)endings=endings+1;
  received=received+1;
 end
 task reset_source;
 begin
  rst_n=0;vsync=0;href=0;repeat(4)@(negedge pclk);
  received=0;endings=0;rst_n=1;repeat(6)@(negedge pclk);
 end endtask
 task boundary;
 begin @(negedge pclk);vsync=1;repeat(3)@(negedge pclk);vsync=0;end endtask
 task frame(input integer fault);
 integer x,y,w;reg [15:0] pixel;
 begin
  boundary();
  for(y=0;y<4;y=y+1)begin
   w=(fault==1 && y==1)?15:16;
   for(x=0;x<w;x=x+1)begin
    pixel=y*16+x;
    @(negedge pclk);href=1;cam_data=pixel[7:0];
    @(negedge pclk);cam_data=pixel[15:8];
   end
   @(negedge pclk);href=0;repeat(4)@(negedge pclk);
  end
  repeat(12)@(negedge pclk);
 end endtask
 initial begin
  reset_source();frame(0);
  if(received!=7 || endings || bad)$fatal(1,"published unchecked final word %0d",received);
  boundary();repeat(12)@(negedge pclk);
  if(received!=8 || endings!=1 || bad)$fatal(1,"full camera frame");
  // Short line aborts the frame without publishing an EOF.
  reset_source();frame(1);boundary();repeat(12)@(negedge pclk);
  if(!bad || endings)$fatal(1,"short frame was published");
  // Consumer stall longer than FIFO capacity must fail, not silently splice.
  ready=0;reset_source();frame(0);boundary();repeat(12)@(negedge pclk);
  if(!bad)$fatal(1,"overflow not detected");
  $display("PASS camera stream: raw DVP counts, RGB565 byte/lane order, delayed EOF, short line and overflow rejection");$finish;
 end
 initial begin #100000;$fatal(1,"camera stream timeout");end
endmodule
