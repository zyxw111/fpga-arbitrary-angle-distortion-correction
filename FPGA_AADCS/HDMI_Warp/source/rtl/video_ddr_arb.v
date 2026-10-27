// Writes retain ownership through LAST. Reads use an ordered owner FIFO so
// multiple AR commands can be outstanding; each client reserves its returns.
module video_ddr_arb #(parameter WRITERS=3,READERS=2)(
 input clk,rst_n,
 input [WRITERS-1:0] wav,output reg [WRITERS-1:0] war,
 input [WRITERS*28-1:0] waa,input [WRITERS*4-1:0] wal,
 input [WRITERS*128-1:0] wd,input [WRITERS*16-1:0] ws,
 output reg [WRITERS-1:0] wr,wl,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,wlast,
 input [READERS-1:0] rav,output reg [READERS-1:0] rar,
 input [READERS*28-1:0] raa,input [READERS*4-1:0] ral,
 output reg [READERS-1:0] rv,rl,output [127:0] rd,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,rlast);
 localparam WB=(WRITERS<=1)?1:$clog2(WRITERS),RB=(READERS<=1)?1:$clog2(READERS);
 reg [1:0] wphase,rphase;
 wire wbusy=wphase!=0,rbusy=rphase!=0;
 reg [WB-1:0] wo,wnext,wsel;reg [RB-1:0] ro,rnext,rsel;
 integer i,n;
 reg [RB-1:0] read_owner[0:15];reg [3:0] read_head,read_tail;reg [4:0] read_count;
 wire read_push=arvalid && arready;
 wire response_pending=read_count!=0 || read_push;
 wire [RB-1:0] response_owner=read_count!=0?read_owner[read_head]:ro;
 wire read_pop=response_pending && rvalid && rlast;
 reg whave,rhave;
 always @* begin
  whave=0;wsel=wo;rhave=0;rsel=ro;
  if(!wbusy)for(i=WRITERS-1;i>=0;i=i-1)begin
   n=wnext+i;if(n>=WRITERS)n=n-WRITERS;
   if(wav[n])begin whave=1;wsel=n;end
  end
  if(!rbusy)for(i=READERS-1;i>=0;i=i-1)begin
   n=rnext+i;if(n>=READERS)n=n-READERS;
   if(rav[n])begin rhave=1;rsel=n;end
  end
  war=0;wr=0;wl=0;rar=0;rv=0;rl=0;
  if(wphase==1)war[wo]=awready;
  if(wphase==2 || (wphase==1 && awready))begin wr[wo]=wready;wl[wo]=wlast;end
  if(rphase==1)rar[ro]=arready;
  if(response_pending)begin rv[response_owner]=rvalid;rl[response_owner]=rlast;end
 end
 assign awvalid=wphase==1;
 assign awaddr=waa[wo*28+:28];assign awlen=wal[wo*4+:4];
 assign wdata=wd[wo*128+:128];assign wstrb=ws[wo*16+:16];
 assign arvalid=rphase==1;
 assign araddr=raa[ro*28+:28];assign arlen=ral[ro*4+:4];assign rd=rdata;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin wphase<=0;rphase<=0;wo<=0;ro<=0;wnext<=0;rnext<=0;read_head<=0;read_tail<=0;read_count<=0;end
 else begin
  case(wphase)
   0:if(whave)begin wo<=wsel;wphase<=1;end
   1:if(awready)begin wphase<=(wready && wlast)?0:2;wnext<=wo==WRITERS-1?0:wo+1'b1;end
   2:if(wready && wlast)wphase<=0;
  endcase
  case(rphase)
   0:if(rhave && read_count<16)begin ro<=rsel;rphase<=1;end
   1:if(arready)begin rphase<=0;rnext<=ro==READERS-1?0:ro+1'b1;end
  endcase
  if(read_push)begin read_owner[read_tail]<=ro;read_tail<=read_tail+1'b1;end
  if(read_pop)read_head<=read_head+1'b1;
  case({read_push,read_pop})
   2'b10:read_count<=read_count+1'b1;
   2'b01:read_count<=read_count-1'b1;
  endcase
 end
endmodule
