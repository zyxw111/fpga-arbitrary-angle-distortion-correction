// Measure the raster in its own pixel domain. Never count DE/VS pulses after
// resampling them with an unrelated system clock. Diagnostic outputs only.
module hdmi_input_monitor #(parameter SYS_HZ=125000000,VS_ACTIVE_HIGH=1)(
 input sys_clk,pclk,rst_n,input vs,hs,de,input [23:0] rgb,
 output reg [31:0] pixel_hz,frames,dimensions,output present,
 output [127:0] debug_pixel);
 reg [1:0] pixel_reset;
 reg [23:0] pixel_count,pixel_gray;
 reg vs_d,de_d;reg [15:0] columns,lines,last_width;
 reg [31:0] held_dimensions,held_frames;
 wire v=VS_ACTIVE_HIGH?vs:!vs;
 always @(posedge pclk or negedge rst_n)
  if(!rst_n)begin
   pixel_reset<=0;pixel_count<=0;pixel_gray<=0;vs_d<=0;de_d<=0;
   columns<=0;lines<=0;last_width<=0;held_dimensions<=0;held_frames<=0;
  end else begin
   pixel_reset<={pixel_reset[0],1'b1};
   if(pixel_reset[1])begin
    pixel_count<=pixel_count+1'b1;
    pixel_gray<=(pixel_count+1'b1)^((pixel_count+1'b1)>>1);
    vs_d<=v;de_d<=de;
    if(de)columns<=columns+1'b1;
    else if(de_d)begin last_width<=columns;columns<=0;lines<=lines+1'b1;end
    if(v && !vs_d)begin
     held_dimensions<={lines,last_width};held_frames<=held_frames+1'b1;lines<=0;
    end
   end
  end
 assign debug_pixel={held_frames,lines,columns,held_dimensions,rgb,5'd0,vs,hs,de};
 reg [23:0] pixel_meta,pixel_sync,last_count;
 reg [31:0] dims_meta,dims_sync,frames_meta,frames_sync,last_frame;
 reg [23:0] gate_count;reg [25:0] age;
 function [23:0] binary(input [23:0] g);
  integer i;begin binary[23]=g[23];for(i=22;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];end
 endfunction
 wire [23:0] current_count=binary(pixel_sync);
 wire [23:0] elapsed=current_count-last_count;
 assign present=pixel_hz>1000000 && dimensions[15:0]!=0 && dimensions[31:16]!=0 && age<SYS_HZ/4;
 always @(posedge sys_clk or negedge rst_n)
  if(!rst_n)begin
   pixel_meta<=0;pixel_sync<=0;dims_meta<=0;dims_sync<=0;frames_meta<=0;frames_sync<=0;
   gate_count<=0;last_count<=0;last_frame<=0;pixel_hz<=0;frames<=0;dimensions<=0;age<=SYS_HZ/4;
  end else begin
   pixel_meta<=pixel_gray;pixel_sync<=pixel_meta;
   dims_meta<=held_dimensions;dims_sync<=dims_meta;frames_meta<=held_frames;frames_sync<=frames_meta;
   if(age<SYS_HZ/4)age<=age+1'b1;
   // Bundle is held for an entire frame. Wait one extra system cycle after
   // the synchronized frame number changes before using its dimensions.
   last_frame<=frames_sync;
   if(last_frame==frames_sync && frames!=frames_sync)begin
    frames<=frames_sync;dimensions<=dims_sync;age<=0;
   end
   if(gate_count==SYS_HZ/10-1)begin
    pixel_hz<={8'd0,elapsed}*10;last_count<=current_count;gate_count<=0;
   end else gate_count<=gate_count+1'b1;
  end
endmodule
