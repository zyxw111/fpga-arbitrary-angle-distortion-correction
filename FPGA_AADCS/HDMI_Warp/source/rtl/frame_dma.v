// One ARM doorbell transfers one immutable frame, split into legal PCIe pages.
// Descriptor completion includes the final TLP being accepted by the PCIe IP.
module frame_dma(input clk,rst_n,input control_wr,input [11:0] control_addr,
 input [31:0] control_data,input [15:0] control_be,
 input frame_ready,input [31:0] frame_bytes,frame_id,page_completed,
 output reg inject,input page_busy,output reg [11:0] inject_addr,output reg [31:0] inject_data,
 output busy,input [11:0] status_addr,output [127:0] status_data);
 reg wr_en;reg [11:0] wr_addr;reg [31:0] wr_data;reg [15:0] wr_be;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin wr_en<=0;wr_addr<=0;wr_data<=0;wr_be<=0;end
 else begin wr_en<=control_wr;wr_addr<=control_addr;wr_data<=control_data;wr_be<=control_be;end
 localparam IDLE=0,LOW=1,GAP0=2,HIGH=3,GAP1=4,CMD=5,WAIT=6,CHECK=7;
 reg [2:0] state;reg [31:0] destination,capacity,address,left,accepted,completed,observed_id,page_count,expect_page;
 reg [31:0] pending_token;reg pending_ready;
 reg [7:0] error;reg [31:0] watchdog;
 wire [12:0] page_room=13'd4096-{1'b0,address[11:0]};
 wire [12:0] chunk=left<page_room?left[12:0]:page_room;
 assign busy=state!=IDLE;
 assign status_data=(status_addr==10)?{completed,accepted,{23'd0,error,busy},32'h4c495633}:
                    (status_addr==11)?{24'd0,error,page_count,observed_id,32'd0}:128'd0;
 always @*begin
  inject=0;inject_addr=0;inject_data=0;
  if(!page_busy)case(state)
   LOW:begin inject=1;inject_addr=12'h110;inject_data=address;end
   HIGH:begin inject=1;inject_addr=12'h120;inject_data=0;end
   CMD:begin inject=1;inject_addr=12'h100;inject_data=32'h01000000|((chunk>>2)-1'b1);end
  endcase
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  state<=IDLE;destination<=0;capacity<=0;address<=0;left<=0;accepted<=0;completed<=0;
  pending_token<=0;pending_ready<=0;observed_id<=0;page_count<=0;expect_page<=0;error<=0;watchdog<=0;
 end else begin
  if(!busy)watchdog<=0;else watchdog<=watchdog+1'b1;
  if(wr_en && (&wr_be))begin
   if(wr_addr==12'h280 && !busy)destination<=wr_data;
   if(wr_addr==12'h284 && !busy)capacity<=wr_data;
   if(wr_addr==12'h288)begin
    if(busy)error<=8'h01;
    else begin
     pending_token<=wr_data;pending_ready<=frame_ready && !page_busy;
     observed_id<=frame_id;address<=destination;left<=frame_bytes;
     page_count<=0;state<=CHECK;
    end
   end
  end
  case(state)
   CHECK:begin
    if(!pending_ready || !left || left>capacity || address[3:0]!=0 || left[3:0]!=0 ||
       {1'b0,address}+{1'b0,left}>33'h100000000 || pending_token==0 || pending_token==accepted)begin
     error<=8'h01;state<=IDLE;
    end else begin accepted<=pending_token;error<=0;state<=LOW;end
   end
   LOW:if(inject)state<=GAP0;
   GAP0:state<=HIGH;
   HIGH:if(inject)state<=GAP1;
   GAP1:state<=CMD;
   CMD:if(inject)begin expect_page<=page_completed+1'b1;state<=WAIT;end
   WAIT:if(page_completed==expect_page && !page_busy)begin
    page_count<=page_count+1'b1;
    if(left==chunk)begin completed<=accepted;state<=IDLE;end
    else begin address<=address+chunk;left<=left-chunk;state<=LOW;end
   end
  endcase
  // Preserve ownership on timeout; never report a canceled DMA as idle.
  if(busy && watchdog==32'h7fffffff)error<=8'h02;
 end
endmodule
