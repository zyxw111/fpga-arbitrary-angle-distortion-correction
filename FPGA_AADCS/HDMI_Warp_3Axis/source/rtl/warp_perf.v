// Passive DDR-domain observer. No output feeds ready, address or pixel logic.
// All inputs are tapped into registers before counting. Counts wrap modulo 2^32.
module warp_perf #(parameter [27:0] LUT_BASE=28'h2000000)(
 input clk,rst_n,input [3:0] active,input [1:0] queue_wait,
 input [3:0] frames,input [7:0] error_flags,
 input [1:0] arvalid,arready,rvalid,rlast,
 input [27:0] warp_addr,input [7:0] arlen,input [2:0] write_beat,
 output [1023:0] counters);
 reg [3:0] a,f;reg [1:0] qw,av,ar,rv,rl;reg [27:0] addr;
 reg [7:0] len,err;reg [2:0] wb;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin a<=0;f<=0;qw<=0;av<=0;ar<=0;rv<=0;rl<=0;addr<=0;len<=0;err<=0;wb<=0;end
 else begin a<=active;f<=frames;qw<=queue_wait;av<=arvalid;ar<=arready;
  rv<=rvalid;rl<=rlast;addr<=warp_addr;len<=arlen;err<=error_flags;wb<=write_beat;end
 wire push0=av[0] && ar[0],push1=av[1] && ar[1];
 wire pop0=rv[0] && rl[0],pop1=rv[1] && rl[1];
 reg kind[0:15];reg [3:0] head,tail;reg [4:0] pending0,pending1;
 wire map_request=addr>=LUT_BASE;
 wire map_return=pending0!=0?kind[head]:map_request;
 wire [5:0] total={1'b0,pending0}+{1'b0,pending1};
 wire [5:0] next0={1'b0,pending0}+(push0?6'd1:6'd0)-(pop0?6'd1:6'd0);
 wire [5:0] next1={1'b0,pending1}+(push1?6'd1:6'd0)-(pop1?6'd1:6'd0);
 wire [6:0] next_total={1'b0,total}+(push0?7'd1:7'd0)+(push1?7'd1:7'd0)
                      -(pop0?7'd1:7'd0)-(pop1?7'd1:7'd0);
 reg [31:0] c[0:31];reg [31:0] warp_run;
 genvar g;generate for(g=0;g<32;g=g+1)begin:flatten
  assign counters[g*32+:32]=c[g];
 end endgenerate
 integer i;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  for(i=0;i<32;i=i+1)c[i]<=0;
  head<=0;tail<=0;pending0<=0;pending1<=0;warp_run<=0;
 end else begin
  c[0]<=c[0]+1'b1;
  for(i=0;i<4;i=i+1)if(a[i])c[1+i]<=c[1+i]+1'b1;
  if(qw[0])c[5]<=c[5]+1'b1;
  if(rv[0] && (pending0!=0 || push0))begin
   if(map_return)c[6]<=c[6]+1'b1;else c[7]<=c[7]+1'b1;
  end
  if(rv[1])c[8]<=c[8]+1'b1;
  for(i=0;i<3;i=i+1)if(wb[i])c[9+i]<=c[9+i]+1'b1;
  if(push0)begin
   kind[tail]<=map_request;tail<=tail+1'b1;
   if(map_request)begin c[12]<=c[12]+1'b1;c[15]<=c[15]+{28'd0,len[3:0]}+1'b1;end
   else begin c[13]<=c[13]+1'b1;c[16]<=c[16]+{28'd0,len[3:0]}+1'b1;end
  end
  if(push1)begin c[14]<=c[14]+1'b1;c[17]<=c[17]+{28'd0,len[7:4]}+1'b1;end
  if(pop0)head<=head+1'b1;
  case({push0,pop0})2'b10:pending0<=pending0+1'b1;2'b01:pending0<=pending0-1'b1;endcase
  case({push1,pop1})2'b10:pending1<=pending1+1'b1;2'b01:pending1<=pending1-1'b1;endcase
  if(av[0] && !ar[0])c[18]<=c[18]+1'b1;
  if(av[1] && !ar[1])c[19]<=c[19]+1'b1;
  if(pending0!=0 && !rv[0])c[20]<=c[20]+1'b1;
  if(pending1!=0 && !rv[1])c[21]<=c[21]+1'b1;
  if(next0>c[22])c[22]<=next0;
  if(next1>c[23])c[23]<=next1;
  if(next_total>c[24])c[24]<=next_total;
  for(i=0;i<3;i=i+1)if(f[i])c[25+i]<=c[25+i]+1'b1;
  if(a[2])warp_run<=warp_run+1'b1;else warp_run<=0;
  if(f[1])c[28]<=warp_run+(a[2]?32'd1:32'd0);
  if(qw[1])c[29]<=c[29]+1'b1;
  if(f[3])c[30]<=c[30]+1'b1;
  c[31]<=c[31]|{24'd0,err}|
    ((rv[0] && pending0==0 && !push0)?32'h100:32'd0)|
    ((rv[1] && pending1==0 && !push1)?32'h200:32'd0)|
    ((next0>16 || next1>16 || next_total>16)?32'h400:32'd0);
 end
endmodule
