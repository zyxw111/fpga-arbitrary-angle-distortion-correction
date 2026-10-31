`timescale 1ns/1ps
module tb_hdmi_rx_count_ab;
 reg p=0,c=0,rst=0,en=0,pv=0,sof=0,fe=0,fg=0,ready=1;
 reg [15:0] w=16,h=8,x=0,y=0;reg [23:0] rgb=0;
 wire [1:0] valid,s,e,bad;wire [127:0] data[0:1];wire [3:0] failure[0:1];
 always #5 p=~p;always #3 c=~c;
 genvar g;
 generate for(g=0;g<2;g=g+1)begin:ab
  hdmi_rx_stream #(.FIFO_BITS(3),.COUNT_PIPELINE(g)) dut(
   .pclk(p),.clk(c),.rst_n(rst),.enable(en),.width(w),.height(h),
   .pixel_valid(pv),.sof(sof),.pixel_rgb(rgb),.pixel_x(x),.pixel_y(y),
   .frame_end(fe),.frame_good(fg),.valid(valid[g]),.ready(ready),
   .data(data[g]),.out_sof(s[g]),.out_eof(e[g]),.bad(bad[g]),.failure(failure[g]));
 end endgenerate
 integer accepted=0;
 always @(posedge c)if(rst)begin
  if(valid[0]!==valid[1])$fatal(1,"A/B valid cycle changed");
  if(valid[0] && {s[0],e[0],data[0]}!=={s[1],e[1],data[1]})$fatal(1,"A/B payload/markers changed");
  if(valid[0] && ready)accepted=accepted+1;
 end
 always @(negedge p)if(rst && (bad[0]!==bad[1] || failure[0]!==failure[1]))
  $fatal(1,"A/B rejection/reason changed");
 task frame(input integer width,height,input bit good,blocked,bubbles);
  integer i;
  begin
   @(negedge p);rst=0;en=0;pv=0;sof=0;fe=0;fg=0;ready=!blocked;w=width;h=height;
   repeat(5)@(negedge p);rst=1;en=1;repeat(6)@(negedge p);
   for(i=0;i<width*height;i=i+1)begin
    if(bubbles && i%5==3)begin @(negedge p);pv=0;sof=0;end
    @(negedge p);pv=1;sof=i==0;x=i%width;y=i/width;rgb=24'(i*71893);
   end
   @(negedge p);pv=0;sof=0;repeat(4)@(negedge p);
   fe=1;fg=good;@(negedge p);fe=0;repeat(20)@(negedge p);
   ready=1;repeat(40)@(negedge p);
  end
 endtask
 initial begin
  frame(4,2,1,0,0); // Earliest possible final-word decision.
  frame(16,8,1,0,0);
  frame(32,8,1,0,1);
  frame(64,8,0,0,1);
  frame(32,8,1,1,0);
  frame(1920,1080,1,0,0);
  if(accepted==0)$fatal(1,"No output compared");
  $display("PASS capture count A/B: cycle-exact full 1080p payload/markers, 8-pixel boundary, geometry changes, bubbles, bad frames and FIFO overflow");$finish;
 end
 initial begin #100000000;$fatal(1,"A/B timeout");end
endmodule
