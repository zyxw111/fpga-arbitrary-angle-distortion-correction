`timescale 1ns/1ps
module tb_demostream_base #(parameter VIEW=0,parameter GOLDEN="sim/demo_vectors/raw_128x80.hex");
 reg pix_clk=0;always #5 pix_clk=~pix_clk;
 reg tx_clk=0;always #7 tx_clk=~tx_clk;
 reg rst_n=0,enable=0;wire overflow,tx_valid,tx_sof,tx_eof;
 wire [127:0] tx_data;wire [31:0] tx_frame_id;
 reg [15:0] expected[0:10239];integer cycle=0,count=0,lane;
 wire tx_ready=cycle%11!=0 && cycle%7!=0;
 stream #(.WIDTH(128),.HEIGHT(80),.H_TOTAL(144),.V_TOTAL(84),.FIFO_ADDR_BITS(5),
 .DEMO_GROUP(1),.DEMO_VIEW(VIEW)) dut(.*);
 always @(posedge tx_clk)begin
  if(!rst_n)cycle<=0;else cycle<=cycle+1;
  if(rst_n && tx_valid && tx_ready)begin
   for(lane=0;lane<8;lane=lane+1)
    if(tx_data[lane*16+:16]!==expected[(count%1280)*8+lane])$fatal(1,"demo stream pixel");
   if(tx_sof!==(count%1280==0)||tx_eof!==(count%1280==1279)||tx_frame_id!==count/1280)
    $fatal(1,"demo stream metadata");
   count=count+1;
  end
 end
 initial begin
  $readmemh(GOLDEN,expected);repeat(4)@(negedge pix_clk);rst_n=1;enable=1;
  wait(count==2560);if(overflow)$fatal(1,"demo stream overflow");
  $display("PASS demostream view=%0d: synthetic source/warp -> pack -> unequal clocks -> stalled receiver, two exact frames",VIEW);$finish;
 end
 initial begin #1000000;$fatal(1,"demo stream timeout");end
endmodule
