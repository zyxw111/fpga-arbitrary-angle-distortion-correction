// Read-only BAR0 extension, 0x200..0x2ff. Existing BAR1 writes are unaffected.
// Two-flop request/ack synchronization plus held bundled data (frame_mailbox).
module warp_perf_regs #(parameter SNAPSHOT_BITS=20)(
 input dclk,hclk,rst_n,input [1023:0] counters,input [255:0] tile_counters,input [383:0] capture_counters,
 input dma_busy,frame_ready,source_read,txvalid,txready,input [31:0] page_completed,
 input [11:0] status_addr,output reg [127:0] status_data);
 reg [SNAPSHOT_BITS-1:0] timer;reg [31:0] snapshot_seq;
 always @(posedge dclk or negedge rst_n)
 if(!rst_n)begin timer<=0;snapshot_seq<=0;end
 else begin timer<=timer+1'b1;if(&timer)snapshot_seq<=snapshot_seq+1'b1;end
 // Latch directly into the BAR snapshot instead of duplicating a wide CDC
 // destination register followed by another equally wide view register.
 // ACK is delayed until every bank has captured the held source bundle.
 reg [1695:0] held;reg request,ack;reg [1:0] ack_sync;
 always @(posedge dclk or negedge rst_n)
 if(!rst_n)begin held<=0;request<=0;ack_sync<=0;end
 else begin
  ack_sync<={ack_sync[0],ack};
  if((&timer) && request==ack_sync[1])begin
   held<={capture_counters,snapshot_seq+32'd1,tile_counters,counters};request<=!request;
  end
 end
 reg [1:0] host_release;
 always @(posedge hclk or negedge rst_n)
 if(!rst_n)host_release<=0;else host_release<={host_release[0],1'b1};
 wire host_reset_n=host_release[1];
 reg [1:0] request_sync;reg seen;
 reg [15:0] bank_enable /* synthesis syn_preserve=1 */;
 always @(posedge hclk or negedge host_reset_n)
 if(!host_reset_n)begin request_sync<=0;seen<=0;ack<=0;bank_enable<=0;end
 else begin
  request_sync<={request_sync[0],request};bank_enable<=0;ack<=seen;
  if(request_sync[1]!=seen)begin seen<=request_sync[1];bank_enable<=16'hffff;end
 end
 reg [31:0] cycles,busy_cycles,frames,last_dma,run,source_beats,tx_stall,ready_wait;
 reg busy_q;
 always @(posedge hclk or negedge rst_n)
 if(!rst_n)begin cycles<=0;busy_cycles<=0;frames<=0;last_dma<=0;run<=0;
  source_beats<=0;tx_stall<=0;ready_wait<=0;busy_q<=0;end
 else begin
  cycles<=cycles+1'b1;busy_q<=dma_busy;
  if(dma_busy)begin busy_cycles<=busy_cycles+1'b1;run<=run+1'b1;end
  else begin run<=0;if(busy_q)begin frames<=frames+1'b1;last_dma<=run;end end
  if(source_read)source_beats<=source_beats+1'b1;
  if(txvalid && !txready)tx_stall<=tx_stall+1'b1;
  if(!frame_ready && !dma_busy)ready_wait<=ready_wait+1'b1;
 end
 wire [1951:0] host_bundle={held[1695:1024],ready_wait,page_completed,tx_stall,
                           source_beats,last_dma,frames,busy_cycles,cycles,held[1023:0]};
 reg [1951:0] view;
 genvar g;generate for(g=0;g<16;g=g+1)begin:snapshot_bank
  localparam BITS=g==15?32:128;
  always @(posedge hclk or negedge host_reset_n)
  if(!host_reset_n)view[g*128+:BITS]<=0;
  else if(bank_enable[g])view[g*128+:BITS]<=host_bundle[g*128+:BITS];
 end endgenerate
 always @*begin
  status_data=0;
  case(status_addr)
   32:status_data={32'd131250000,view[1567:1536],32'd1,32'h50524630};
   33:status_data=view[0+:128];34:status_data=view[128+:128];
   35:status_data=view[256+:128];36:status_data=view[384+:128];
   37:status_data=view[512+:128];38:status_data=view[640+:128];
   39:status_data=view[768+:128];40:status_data=view[896+:128];
   41:status_data=view[1024+:128];42:status_data=view[1152+:128];
   43:status_data=view[1280+:128];44:status_data=view[1408+:128];
   45:status_data=view[1568+:128];46:status_data=view[1696+:128];47:status_data=view[1824+:128];
  endcase
 end
endmodule
