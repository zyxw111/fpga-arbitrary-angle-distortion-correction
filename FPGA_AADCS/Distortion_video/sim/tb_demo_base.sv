`timescale 1ns/1ps
module tb_demo_base #(parameter GROUP=0,VIEW=0,parameter WIDTH=128,HEIGHT=80,parameter TEST_RESETS=1,
 parameter GOLDEN="sim/demo_vectors/bars_128x80.hex",parameter DUMP="checks/regression/demo_bars_actual.hex");
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,enable=0;
 wire valid,sof,sol;wire [15:0] pixel;wire [11:0] x,y;wire [31:0] frame_id;
 reg [15:0] expected[0:WIDTH*HEIGHT-1];
 integer received=0,phase=0,f;
 demo #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(WIDTH+16),.V_TOTAL(HEIGHT+4),
 .GROUP(GROUP),.VIEW(VIEW)) dut(.*);
 always @(posedge clk)begin #1;
  if(rst_n && enable && valid)begin
   if(x!==received%WIDTH || y!==(received/WIDTH)%HEIGHT ||
    frame_id!==received/(WIDTH*HEIGHT)) $fatal(1,"demo metadata at %d: %d,%d frame=%d",received,x,y,frame_id);
   if(pixel!==expected[received%(WIDTH*HEIGHT)])
    $fatal(1,"demo pixel group=%d view=%d at %d,%d got %h expected %h",GROUP,VIEW,x,y,pixel,expected[received%(WIDTH*HEIGHT)]);
   if(sof!==(x==0 && y==0) || sol!==(x==0)) $fatal(1,"demo markers");
   if(phase==0 && received<WIDTH*HEIGHT)$fdisplay(f,"%04x",pixel);
   received=received+1;
  end
 end
 initial begin
  $readmemh(GOLDEN,expected);f=$fopen(DUMP,"w");if(!f)$fatal(1,"dump open");
  repeat(4)@(negedge clk);rst_n=1;enable=1;
  wait(received==(TEST_RESETS?2:1)*WIDTH*HEIGHT);@(negedge clk);
  if(!TEST_RESETS)begin
   $fclose(f);$display("PASS demo preview group=%0d view=%0d: %0dx%0d complete RTL frame equals golden",GROUP,VIEW,WIDTH,HEIGHT);$finish;
  end
  enable=0;rst_n=0;
  phase=1;received=0;repeat(30)@(negedge clk);
  if(valid)$fatal(1,"reset must flush pipeline");rst_n=1;enable=1;
  wait(received==13);@(negedge clk);enable=0;rst_n=0;
  received=0;repeat(30)@(negedge clk);rst_n=1;enable=1;
  wait(received==WIDTH*HEIGHT);@(negedge clk);$fclose(f);
  $display("PASS demo group=%0d view=%0d: %0dx%0d exact golden pixels, frame/line tags, back-to-back frames and mid-frame reset",GROUP,VIEW,WIDTH,HEIGHT);$finish;
 end
 initial begin #(100*WIDTH*HEIGHT*10);$fatal(1,"demo timeout");end
endmodule
