// Bundled-data CDC: src holds a whole frame record until synchronized ACK.
// No bitwise synchronization of counters/geometry. One pending record at a time.
module frame_mailbox #(parameter WIDTH=320)(
 input src_clk,dst_clk,rst_n,input src_send,input [WIDTH-1:0] src_data,
 output reg dst_valid,output reg [WIDTH-1:0] dst_data);
 reg [WIDTH-1:0] held;
 reg request,ack;reg [1:0] ack_sync,request_sync;
 reg [1:0] src_release,dst_release;
 wire src_reset_n=src_release[1],dst_reset_n=dst_release[1];
 // Asynchronous assertion, independently synchronized release in both domains.
 always @(posedge src_clk or negedge rst_n)
 if(!rst_n)src_release<=0;else src_release<={src_release[0],1'b1};
 always @(posedge dst_clk or negedge rst_n)
 if(!rst_n)dst_release<=0;else dst_release<={dst_release[0],1'b1};
 always @(posedge src_clk or negedge src_reset_n)
 if(!src_reset_n)begin held<=0;request<=0;ack_sync<=0;end
 else begin
  ack_sync<={ack_sync[0],ack};
  if(src_send && request==ack_sync[1])begin held<=src_data;request<=!request;end
 end
 always @(posedge dst_clk or negedge dst_reset_n)
 if(!dst_reset_n)begin request_sync<=0;ack<=0;dst_valid<=0;dst_data<=0;end
 else begin
  request_sync<={request_sync[0],request};dst_valid<=0;
  if(request_sync[1]!=ack)begin dst_data<=held;dst_valid<=1;ack<=request_sync[1];end
 end
endmodule
