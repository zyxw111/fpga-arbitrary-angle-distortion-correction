// BAR1 shadow coefficients -> held mailbox -> frame-boundary DDR-domain bank.
// PCIe writes are normalized single DW, address is BYTE offset, little endian.
// The held bundle is immutable from COMMIT until the synchronized ACK returns.
module warp_control(input host_clk,frame_clk,rst_n,
 input wr_en,input [11:0] wr_addr,input [31:0] wr_data,input [15:0] wr_be,
 input [543:0] defaults,input frame_safe,input [11:0] status_addr,
 output reg [543:0] active_config,output reg [287:0] active_h,output reg [31:0] active_generation,
 output [127:0] status_data,output pending);
 reg [543:0] shadow,held;
 // Q2.30 normalized inverse homography. Atomically held with all Brown words.
 localparam [287:0] DEFAULT_H={32'sd1073741824,32'sd0,32'sd0,
  -32'sd566231040,32'sd1048576,32'sd0,
  -32'sd1006632960,32'sd0,32'sd1048576};
 reg [287:0] shadow_h,held_h;
 reg [31:0] held_generation,accepted_generation,applied_generation;
 reg request,ack,rejected;reg [1:0] ack_sync,request_sync;
 wire outstanding=request!=ack_sync[1];
 assign pending=outstanding;
 assign status_data=({128{status_addr==8}} & {applied_generation,accepted_generation,{30'd0,rejected,outstanding},32'h57525031}) |
   ({128{status_addr==16}} & shadow[0+:128]) |
   ({128{status_addr==17}} & shadow[128+:128]) |
   ({128{status_addr==18}} & shadow[256+:128]) |
   ({128{status_addr==19}} & shadow[384+:128]) |
   ({128{status_addr==20}} & {96'd0,shadow[512+:32]}) |
   ({128{status_addr==24}} & shadow_h[0+:128]) |
   ({128{status_addr==25}} & shadow_h[128+:128]) |
   ({128{status_addr==26}} & {96'd0,shadow_h[256+:32]}) |
   ({128{status_addr==28}} & {32'd81,32'd9,32'd3,32'h48334431});
 always @(posedge host_clk or negedge rst_n)
 if(!rst_n)begin
  shadow<=defaults;held<=defaults;shadow_h<=DEFAULT_H;held_h<=DEFAULT_H;held_generation<=0;accepted_generation<=0;applied_generation<=0;
  request<=0;ack_sync<=0;rejected<=0;
 end else begin
  ack_sync<={ack_sync[0],ack};
  if(ack_sync[1]==request)applied_generation<=held_generation;
  if(wr_en && (&wr_be))begin
   if(wr_addr>=12'h200 && wr_addr<=12'h240 && wr_addr[1:0]==0)begin
    if(!outstanding)shadow[(wr_addr-12'h200)*8+:32]<=wr_data;else rejected<=1;
   end
   if(wr_addr>=12'h340 && wr_addr<=12'h360 && wr_addr[1:0]==0)begin
    if(!outstanding)shadow_h[(wr_addr-12'h340)*8+:32]<=wr_data;else rejected<=1;
   end
   if(wr_addr==12'h250)begin
    if(!outstanding && wr_data!=0 && wr_data!=accepted_generation)begin
     held<=shadow;held_h<=shadow_h;held_generation<=wr_data;accepted_generation<=wr_data;request<=!request;rejected<=0;
    end else rejected<=1;
   end
  end
 end
 always @(posedge frame_clk or negedge rst_n)
 if(!rst_n)begin request_sync<=0;ack<=0;active_config<=defaults;active_h<=DEFAULT_H;active_generation<=0;end
 else begin
  request_sync<={request_sync[0],request};
  if(frame_safe && request_sync[1]!=ack)begin
   active_config<=held;active_h<=held_h;active_generation<=held_generation;ack<=request_sync[1];
  end
 end
endmodule
