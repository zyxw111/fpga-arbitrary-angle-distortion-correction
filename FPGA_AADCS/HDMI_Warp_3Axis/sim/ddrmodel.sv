`timescale 1ns/1ps
// Interface model, not a PHY model. Optional queued/latent read channel tests
// multiple in-flight commands and in-order returns without RREADY.
module ddrmodel #(parameter integer WORDS=1024,FORMULA=0,READ_QUEUE=1,READ_DELAY=0,
 WRITE_STALL_CYCLES=0,WRITE_RUN_CYCLES=64)(
 input clk,input rst_n,
 input awvalid,output awready,input [27:0] awaddr,input [3:0] awlen,
 input [127:0] wdata,input [15:0] wstrb,output wready,output wlast,
 input arvalid,output arready,input [27:0] araddr,input [3:0] arlen,
 output rvalid,output rlast,output [127:0] rdata);
 reg [127:0] memory[0:WORDS-1];
 integer cycle=0,wb=0,wn=0,wi=0;reg wa=0;
 function [127:0] pattern(input integer n);
 pattern={32'h12340000 ^ n,32'h56780000 ^ n,32'habcd0000 ^ n,32'hfedc0000 ^ n};
 endfunction
 assign awready=rst_n && !wa && cycle%5!=0;
 assign wready=rst_n && (wa || (awvalid && awready)) && cycle%4!=0 &&
               (WRITE_STALL_CYCLES==0 || cycle%(WRITE_STALL_CYCLES+WRITE_RUN_CYCLES)>=WRITE_STALL_CYCLES);
 assign wlast=wa ? wi==wn-1 : awlen==0;
 integer j,addr;
 always @(posedge clk)begin
  if(!rst_n)begin cycle<=0;wa<=0;wi<=0;end
  else begin
   cycle<=cycle+1;
   if(awvalid && awready)begin
    if(awaddr[3:0]!=0 || (awaddr%4096)+(awlen+1)*16>4096)$fatal(1,"DDR write alignment/page");
    wa<=1;wb<=awaddr/16;wn<=awlen+1;wi<=0;
   end
   if(wready)begin
    addr=wa?wb+wi:awaddr/16;
    if((!wa && !(awvalid && awready)) || addr>=WORDS)$fatal(1,"DDR write out of bounds");
    for(j=0;j<16;j=j+1)if(wstrb[j])memory[addr][8*j+:8]<=wdata[8*j+:8];
    if(wa)begin wi<=wi+1;if(wi==wn-1)wa<=0;end
    else begin wi<=1;if(awlen==0)wa<=0;end
   end
  end
 end
 generate if(READ_QUEUE==1 && READ_DELAY==0)begin:single
  integer rb=0,rn=0,ri=0;reg ra=0;
  assign arready=rst_n && !ra && cycle%7!=0;
  assign rvalid=rst_n && (ra || (arvalid && arready)) && cycle%3!=0;
  assign rlast=ra?ri==rn-1:arlen==0;
  wire [27:0] a=ra?rb+ri:araddr/16;
  assign rdata=FORMULA?pattern(a):memory[a];
  always @(posedge clk)begin
   if(!rst_n)begin ra<=0;ri<=0;end
   else begin
    if(arvalid && arready)begin
     if(araddr[3:0]!=0 || (araddr%4096)+(arlen+1)*16>4096)$fatal(1,"DDR read alignment/page");
     ra<=1;rb<=araddr/16;rn<=arlen+1;ri<=0;
    end
    if(rvalid)begin
     if((!ra && !(arvalid && arready)) || a>=WORDS)$fatal(1,"DDR read out of bounds");
     if(ra)begin ri<=ri+1;if(ri==rn-1)ra<=0;end
     else begin ri<=1;if(arlen==0)ra<=0;end
    end
   end
  end
 end else begin:queued
  integer bases[0:READ_QUEUE-1],lengths[0:READ_QUEUE-1],due[0:READ_QUEUE-1];
  integer head=0,tail=0,count=0,index=0,max_pending=0;
  wire push=arvalid && arready,pop=rvalid && rlast;
  assign arready=rst_n && count<READ_QUEUE && cycle%7!=0;
  assign rvalid=rst_n && count!=0 && cycle>=due[head] && cycle%3!=0;
  assign rlast=index==lengths[head]-1;
  wire [27:0] a=bases[head]+index;
  assign rdata=FORMULA?pattern(a):memory[a];
  always @(posedge clk)begin
   if(!rst_n)begin head<=0;tail<=0;count<=0;index<=0;max_pending<=0;end
   else begin
    if(count>max_pending)max_pending<=count;
    if(push)begin
     if(araddr[3:0]!=0 || (araddr%4096)+(arlen+1)*16>4096)$fatal(1,"queued DDR read alignment/page");
     bases[tail]<=araddr/16;lengths[tail]<=arlen+1;due[tail]<=cycle+READ_DELAY;tail<=(tail+1)%READ_QUEUE;
    end
    if(rvalid)begin
     if(a>=WORDS)$fatal(1,"queued DDR read out of bounds");
     index<=rlast?0:index+1;
    end
    if(pop)head<=(head+1)%READ_QUEUE;
    case({push,pop})2'b10:count<=count+1;2'b01:count<=count-1;endcase
   end
  end
 end endgenerate
endmodule
