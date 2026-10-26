`timescale 1ns/1ps
module tb_video_rx;
 reg pix=0,sys=0,rst_n=0,vs=0,hs=0,de=0;reg [23:0] rgb=0;
 always #5 pix=~pix;always #4 sys=~sys;
 wire valid,sof,eol,ended,good;wire [23:0] data;wire [15:0] x,y;
 wire [319:0] record,sys_record;wire snapshot;
 video_rx dut(pix,rst_n,vs,hs,de,rgb,valid,sof,eol,data,x,y,ended,good,record);
 frame_mailbox mailbox(pix,sys,rst_n,ended,record,snapshot,sys_record);
 integer w=0,h=0,tag=0,good_count=0,bad_count=0,mail_count=0,target_period=0,last_polarity=0;
 integer stream_pixels=0;reg [31:0] expected_checksum=0;
 integer expected_x=0,expected_y=0;
 reg [23:0] rgb_q0,rgb_q1;
 always @(negedge pix)rgb_q0<=rgb;
 always @(posedge pix)rgb_q1<=rgb_q0;
 always @(negedge pix)if(rst_n)begin
  if(valid)begin
   if(data!==rgb_q1 || x!=expected_x || y!=expected_y)$fatal(1,"RGB/coordinates mismatch x=%0d y=%0d rgb=%h",x,y,data);
   if(sof !== (x==0 && y==0))$fatal(1,"SOF mismatch");
   expected_checksum={expected_checksum[26:0],expected_checksum[31:27]}^{8'd0,data};
   stream_pixels=stream_pixels+1;
   expected_x=expected_x+1;
  end
  if(eol)begin expected_x=0;expected_y=expected_y+1;end
  if(ended)begin
   if(record[159:128]!==expected_checksum || record[63:32]!=stream_pixels)$fatal(1,"frame RGB checksum/count mismatch");
   stream_pixels=0;expected_checksum=0;expected_x=0;expected_y=0;
   if(good)begin
    if(record[63:32]!=record[15:0]*record[31:16] || !record[288])$fatal(1,"stable frame geometry");
    if(record[15:0]==w && record[31:16]==h && record[95:64]==target_period)good_count=good_count+1;
   end else bad_count=bad_count+1;
  end
 end
 always @(negedge sys)if(snapshot)begin
  if(sys_record[15:0]==0 || sys_record[31:16]==0)$fatal(1,"torn mailbox");
  mail_count=mail_count+1;
 end
 task frame(input integer width,height,blank,negative,ragged);
  integer row,col,active_width;
  begin
   for(row=0;row<height+4;row=row+1)begin
    active_width=(ragged && row==height/2+2)?width-1:width;
    for(col=0;col<width+blank;col=col+1)begin
     // Model source data changing after the rising clock edge; the receiver
     // must capture it on the falling edge and process the held value later.
     @(posedge pix);#1;
     vs=(row==0)?!negative:negative;hs=(col<2);de=(row>=2 && row<height+2 && col>=4 && col<active_width+4);
     rgb={8'(col-4),8'(row-2),tag[7:0]};
    end
   end
  end
 endtask
 task mode(input integer width,height,blank,negative);
  integer good_before;
  begin
   w=width;h=height;tag=tag+1;good_before=good_count;target_period=(width+blank)*(height+4);
   frame(w,h,blank,negative,0);frame(w,h,blank,negative,0);frame(w,h,blank,negative,0);
   if(negative!=last_polarity)frame(w,h,blank,negative,0);
   if(good_count<=good_before)$fatal(1,"no stable frames at %0dx%0d",w,h);
   last_polarity=negative;
   $display("PASS RGB frame %0dx%0d, polarity %0d",w,h,negative);
  end
 endtask
 integer bad_before;
 initial begin
  repeat(4)@(negedge pix);rst_n=1;
  mode(16,7,16,0);mode(16,7,24,0);
  mode(32,9,16,1);
  bad_before=bad_count;frame(w,h,16,1,1);frame(w,h,16,1,0);frame(w,h,16,1,0);
  if(bad_count<=bad_before)$fatal(1,"ragged frame accepted");
  mode(640,480,160,1);mode(1280,720,700,0);mode(1280,720,370,0);
  mode(1920,1080,280,0);mode(1920,1080,720,0);
  de=0;vs=0;hs=0;repeat(100)@(negedge pix);
  if(mail_count<10)$fatal(1,"mailbox liveness");
  rst_n=0;repeat(2)@(negedge pix);if(record!==0 || sys_record!==0)$fatal(1,"reset stale frame");
  $display("PASS geometry/rate switches, RGB checksum/coordinates, ragged-frame rejection, coherent CDC, reset");$finish;
 end
 initial begin #2000000000;$fatal(1,"video simulation timeout");end
endmodule
