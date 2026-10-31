`timescale 1ns/1ps
module tb_hdmi_rx_stream;
reg p=0,c=0,rst=0,en=0,pv=0,sof=0,fe=0,fg=0,ready=1;
reg [15:0] x=0,y=0;reg [23:0] rgb=0;wire valid,s,e,bad;wire [127:0] data;wire [3:0] failure;
always #5 p=~p;always #3 c=~c;
hdmi_rx_stream #(.FIFO_BITS(3)) dut(.pclk(p),.clk(c),.rst_n(rst),.enable(en),
 .width(16'd16),.height(16'd8),.pixel_valid(pv),.sof(sof),.pixel_rgb(rgb),.pixel_x(x),.pixel_y(y),
 .frame_end(fe),.frame_good(fg),.valid(valid),.ready(ready),.data(data),.out_sof(s),.out_eof(e),.bad(bad),.failure(failure));
integer words=0,eofs=0,j,k,phase=0;reg [15:0] want;
always @(posedge c)if(valid && ready)begin
 if(s!==(words==0))$fatal(1,"SOF placement");
 for(k=0;k<8;k=k+1)begin
  want=(((words*8+k)%32)<<11) | (((words*8+k)%64)<<5) | ((words*8+k)%32);
  if(data[k*16+:16]!==want)$fatal(1,"pixel packing word=%0d lane=%0d",words,k);
 end
 words=words+1;if(e)eofs=eofs+1;
end
task reset;begin
 @(negedge p);rst=0;pv=0;sof=0;fe=0;fg=0;en=0;
 repeat(4)@(negedge p);words=0;eofs=0;rst=1;en=1;repeat(6)@(negedge p);
end endtask
task pixels;integer i;begin
 for(i=0;i<128;i=i+1)begin
  @(negedge p);pv=1;sof=i==0;x=i%16;y=i/16;
  // Identical 5/6/5 values in each channel after RGB888 conversion.
  rgb={5'(i),3'd0,6'(i),2'd0,5'(i),3'd0};
 end
 @(negedge p);pv=0;sof=0;repeat(8)@(negedge p);
end endtask
initial begin
 reset();pixels();if(words!=15 || eofs)$fatal(1,"last beat escaped before frame validation");
 fe=1;fg=1;@(negedge p);fe=0;repeat(20)@(negedge p);
 if(words!=16 || eofs!=1 || bad || failure)$fatal(1,"good frame not committed");
 reset();pixels();fe=1;fg=0;@(negedge p);fe=0;repeat(20)@(negedge p);
 if(!bad || eofs || words!=15 || failure!==4'b0010)$fatal(1,"bad frame published/reason %h",failure);
 reset();ready=0;pixels();fe=1;fg=1;@(negedge p);fe=0;repeat(20)@(negedge p);
 if(!bad || !failure[0])$fatal(1,"FIFO overflow not reported");
 $display("PASS HDMI v2 stream: RGB565 packing, final-beat commit, invalid-frame discard, FIFO overflow rejection");$finish;
end
initial begin #100000;$fatal(1,"stream timeout");end
endmodule
