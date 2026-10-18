// One host descriptor in flight. DDR page is complete BEFORE DMA can start.
// complete_count means final posted TLP accepted by the PCIe IP, not a CPU
// cache maintenance operation. Host additionally checks full expected payload.
module hostlink #(
 parameter integer WIDTH=640,HEIGHT=400,GROUP=0,VIEW=1,TIMEOUT=268435455
)(input clk,input rst_n,input frame_ready,input [7:0] engine_error,
 input [31:0] checksum,input [27:0] cursor,input request,input [9:0] length,input [63:0] address,
 input tx_busy,input prepared,input rd_done,
 output ready,output launch,output reg request_toggle,output reg [12:0] bytes,
 output busy,output [3:0] status_addr, input [11:0] bar_addr,
 output reg [127:0] status_data,output reg [7:0] error_code);
 localparam IDLE=0,PREPARE=1,SEND=2,DRAIN=3,HALT=4;
 localparam [31:0] W=WIDTH,H=HEIGHT,STRIDE=WIDTH*2,FRAME=WIDTH*HEIGHT*2,G=GROUP,V=VIEW;
 reg [2:0] state;reg [1:0] frame_sync,err_sync;
 reg [31:0] count,timer;reg source_done,seen_tx;
 // The vendor controller already converts count-minus-one to PCIe DW count;
 // zero in its 10-bit output represents 1024 DW, i.e. a full 4096-byte page.
 wire [12:0] size=(length==0)?13'd4096:{1'b0,length,2'b00};
 assign busy=state!=IDLE;
 // Vendor request acknowledgement is registered: keep the gated request
 // asserted through SEND until the controller actually withdraws it.
 assign ready=((state==PREPARE && prepared) || state==SEND) && error_code==0 && !err_sync[1];
 assign launch=state==PREPARE && prepared && request && error_code==0 && !err_sync[1];
 assign status_addr=bar_addr[3:0];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin frame_sync<=0;err_sync<=0;end
 else begin frame_sync<={frame_sync[0],frame_ready};err_sync<={err_sync[0],|engine_error};end
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin state<=IDLE;request_toggle<=0;bytes<=0;count<=0;timer<=0;
 error_code<=0;source_done<=0;seen_tx<=0;end
 else begin
  if(state==IDLE)timer<=0;else timer<=timer+1;
  if(err_sync[1])begin error_code<=8'h10;state<=HALT;end
  else if(state!=IDLE && timer>=TIMEOUT)begin error_code<=8'h11;state<=HALT;end
  else case(state)
   IDLE:if(request && frame_sync[1])begin
    if(size==0 || size>4096 || size[3:0]!=0 || address[3:0]!=0 ||
       address[63:32]!=0 || {1'b0,address[11:0]}+size>4096)begin
      error_code<=8'h12;state<=HALT;
    end else begin bytes<=size;request_toggle<=!request_toggle;state<=PREPARE;end
   end
   PREPARE:if(launch)begin state<=SEND;source_done<=0;seen_tx<=0;end
   SEND:begin
    if(rd_done)source_done<=1;
    if(tx_busy)seen_tx<=1;
    if(!request)state<=DRAIN;
   end
   DRAIN:begin
    if(rd_done)source_done<=1;
    if(tx_busy)seen_tx<=1;
    if(source_done && seen_tx && !tx_busy)begin count<=count+1;state<=IDLE;end
   end
   default:state<=HALT;
  endcase
 end
 end
 // BAR address is measured in 128-bit words by the existing completion reader.
 // checksum is immutable after frame_ready; engine_error is diagnostic only.
 always @*begin
  case(bar_addr)
   0:status_data={count,{24'd0,5'd0,(error_code!=0 || err_sync[1]),busy,frame_sync[1]},32'h00010000,32'h44564d31};
   1:status_data={FRAME,STRIDE,H,W};
   2:status_data={checksum,{4'd0,cursor},V,G};
   3:status_data={96'd0,16'd0,engine_error,error_code};
   default:status_data=0;
  endcase
 end
endmodule
