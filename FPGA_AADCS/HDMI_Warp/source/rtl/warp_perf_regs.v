// Read-only BAR0 extension, 0x200..0x2af. Existing BAR1 writes are unaffected.
// Two-flop request/ack synchronization plus held bundled data (frame_mailbox).
module warp_perf_regs #(parameter SNAPSHOT_BITS=20)(
 input dclk,hclk,rst_n,input [1023:0] counters,input [255:0] tile_counters,
 input dma_busy,frame_ready,source_read,txvalid,txready,input [31:0] page_completed,
 input [11:0] status_addr,output reg [127:0] status_data);
 reg [SNAPSHOT_BITS-1:0] timer;reg [31:0] snapshot_seq;
 always @(posedge dclk or negedge rst_n)
 if(!rst_n)begin timer<=0;snapshot_seq<=0;end
 else begin timer<=timer+1'b1;if(&timer)snapshot_seq<=snapshot_seq+1'b1;end
 wire snapshot_valid;wire [1311:0] incoming;
 frame_mailbox #(.WIDTH(1312)) snapshot(.src_clk(dclk),.dst_clk(hclk),.rst_n(rst_n),
  .src_send(&timer),.src_data({snapshot_seq+32'd1,tile_counters,counters}),.dst_valid(snapshot_valid),.dst_data(incoming));
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
 reg [1567:0] view;
 always @(posedge hclk or negedge rst_n)
 if(!rst_n)view<=0;
 else if(snapshot_valid)view<={incoming[1311:1024],ready_wait,page_completed,tx_stall,
                              source_beats,last_dma,frames,busy_cycles,cycles,incoming[1023:0]};
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
  endcase
 end
endmodule
