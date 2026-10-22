`timescale 1ns/1ps
// Check actual 640x400 byte stream against the independent old image fixture.
module tb_synthetic_camera;
 localparam W=640,H=400,HT=800,VT=520;
 reg clk=0,rst_n=0;always #20 clk=~clk;
 wire vsync,href;wire [7:0] data;wire [31:0] frame_id;
 synthetic_camera dut(.*);
 reg [15:0] golden[0:W*H-1];reg [15:0] expected,pixel;
 reg href_d=0,vsync_d=0;integer row=0,col=0,bytes=0,frames=0,ticks=0,last_sync=0,f;
 integer total_pixels=0,reset_phase=0;
 always @(posedge clk)begin #1;
  if(!rst_n)begin href_d=0;vsync_d=0;row=0;col=0;bytes=0;frames=0;ticks=0;last_sync=0;end
  else begin
   ticks=ticks+1;
   if(vsync && href)$fatal(1,"HREF active during VSYNC");
   if(href)begin
    if(row>=H || col>=2*W)$fatal(1,"oversize DVP frame");
    expected=golden[row*W+col/2];
    if(row>=H-8 && col/2<64)expected=frame_id[(col/2)/8]?16'hffe0:16'h001f;
    if(data!==(col%2==0?expected[7:0]:expected[15:8]))
     $fatal(1,"DVP pixel/byte order (%0d,%0d) frame %0d byte %0d got %h expected %h",col/2,row,frame_id,col%2,data,expected);
    if(col%2==0)pixel[7:0]=data;
    else begin pixel[15:8]=data;total_pixels=total_pixels+1;if(reset_phase==0 && frames==0)$fdisplay(f,"%04x",pixel);end
    col=col+1;bytes=bytes+1;
   end
   if(href_d && !href)begin if(col!=2*W)$fatal(1,"short line %0d",col);row=row+1;col=0;end
   if(vsync && !vsync_d)begin
    if(row!=H || bytes!=W*H*2)$fatal(1,"short frame rows=%0d bytes=%0d",row,bytes);
    if(last_sync && ticks-last_sync!=2*HT*VT)$fatal(1,"wrong source cadence");
    last_sync=ticks;frames=frames+1;row=0;bytes=0;
   end
   href_d=href;vsync_d=vsync;
  end
 end
 initial begin
  $readmemh("sim/demo_vectors/raw_640x400.hex",golden);
  f=$fopen("build/sim/synthetic_640x400.hex","w");if(!f)$fatal(1,"dump open");
  repeat(4)@(negedge clk);rst_n=1;
  wait(frames==3);@(negedge clk);$fclose(f);
  // Reset during active video must flush the chart/control/serializer pipeline.
  wait(href);repeat(37)@(negedge clk);rst_n=0;reset_phase=1;
  repeat(12)@(negedge clk);if(vsync || href || data)$fatal(1,"reset output not blank");rst_n=1;
  wait(frames==1);@(negedge clk);
  $display("PASS synthetic camera: 640x400 exact distorted fixture, LOW-byte-first, 512000 bytes/frame, continuous 832000-clock cadence, changing marker and mid-frame reset; %0d pixels",total_pixels);$finish;
 end
 initial begin #180000000;$fatal(1,"synthetic source timeout");end
endmodule
