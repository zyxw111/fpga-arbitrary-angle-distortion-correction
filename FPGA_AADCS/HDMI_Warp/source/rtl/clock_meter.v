module clock_meter #(parameter SYS_HZ=125000000)(
 input sys_clk,pix_clk,rst_n,output reg [31:0] pixel_hz,output reg clock_changed);
 reg [1:0] pix_reset;
 reg [23:0] count,gray,meta,sync_count,last;
 reg [23:0] gate_count;
 function [23:0] binary(input [23:0] g);
  integer i;begin binary[23]=g[23];for(i=22;i>=0;i=i-1)binary[i]=binary[i+1]^g[i];end
 endfunction
 wire [23:0] delta=binary(sync_count)-last;
 wire [31:0] measured={8'd0,delta}*10;
 wire [31:0] frequency_delta=(measured>pixel_hz)?measured-pixel_hz:pixel_hz-measured;
 always @(posedge pix_clk or negedge rst_n)
 if(!rst_n)begin pix_reset<=0;count<=0;gray<=0;end
 else begin
  pix_reset<={pix_reset[0],1'b1};
  if(pix_reset[1])begin count<=count+1'b1;gray<=count^(count>>1);end
 end
 always @(posedge sys_clk or negedge rst_n)
 if(!rst_n)begin meta<=0;sync_count<=0;last<=0;gate_count<=0;pixel_hz<=0;clock_changed<=0;end
 else begin
  clock_changed<=0;
  meta<=gray;sync_count<=meta;
  if(gate_count==SYS_HZ/10-1)begin
   clock_changed<=pixel_hz!=0 && frequency_delta>((pixel_hz>>6)+1'b1);
   pixel_hz<=measured;last<=binary(sync_count);gate_count<=0;
  end else gate_count<=gate_count+1'b1;
 end
endmodule
