// Destructive DDR smoke test; exclusive ownership of BASE..BASE+BEATS*16.
// Byte addressed internally. ddrlink converts to native x16 memory addresses.
// WAIT_CYCLES is a diagnostic delay, NOT a production write visibility fence.
module ddrbist #(
 parameter [27:0] BASE=0, parameter integer BEATS=4096,
 parameter integer WAIT_CYCLES=1024, parameter integer TIMEOUT=10000000
)(
 input clk,input rst_n,input init_done,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,input wlast,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input rvalid,input rlast,input [127:0] rdata,
 output reg passed,output reg failed,output reg [2:0] fail_code,
 output reg [31:0] checked,output reg [27:0] fail_addr,
 output reg [127:0] expected,output reg [127:0] observed
);
 localparam IDLE=0,START_W=1,WRITE=2,WAIT_W=3,START_R=4,READ=5,STOP=6;
 reg [2:0] state;
 reg phase;
 reg [31:0] sent,received,ticks,wait_ticks;
 wire ws_ready,ws_done,ws_error,in_ready;
 wire rs_ready,rs_done,rs_error,out_valid,out_last;
 wire [127:0] out_data;
 function [127:0] pattern(input [31:0] n,input invert);
  reg [31:0] a;
  begin a={4'd0,BASE}+n*16;
   pattern={a^32'h13579bdf,a^32'h2468ace0,a^32'h55aa00ff,a^32'haa55ff00};
   if(invert) pattern=~pattern;
  end
 endfunction
 wire engine_rst_n=rst_n && !failed;
 burst u_write(.clk(clk),.rst_n(engine_rst_n),.start(state==START_W),
  .start_ready(ws_ready),.base_addr(BASE),.beats(BEATS),
  .in_valid(state==WRITE),.in_ready(in_ready),.in_data(pattern(sent,phase)),
  .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
  .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
  .done(ws_done),.error(ws_error));
 fetch u_read(.clk(clk),.rst_n(engine_rst_n),.start(state==START_R),
  .start_ready(rs_ready),.base_addr(BASE),.beats(BEATS),
  .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
  .rvalid(rvalid),.rlast(rlast),.rdata(rdata),.out_valid(out_valid),
  .out_ready(state==READ),.out_data(out_data),.out_last(out_last),
  .done(rs_done),.error(rs_error));
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=IDLE;phase<=0;sent<=0;received<=0;ticks<=0;wait_ticks<=0;
   passed<=0;failed<=0;fail_code<=0;checked<=0;fail_addr<=0;expected<=0;observed<=0;
  end else if(state!=STOP) begin
   ticks<=ticks+1;
   if(ticks>=TIMEOUT-1) begin failed<=1;fail_code<=3;state<=STOP;end
   else if(ws_error || rs_error) begin failed<=1;fail_code<=2;state<=STOP;end
   else if(state!=IDLE && !init_done) begin failed<=1;fail_code<=4;state<=STOP;end
   else case(state)
    IDLE: if(init_done) begin ticks<=0;state<=START_W;end
    START_W: if(ws_ready) begin state<=WRITE;sent<=0;received<=0;end
    WRITE: begin
     if(in_ready) sent<=sent+1;
     if(ws_done) begin wait_ticks<=0;state<=WAIT_W;end
    end
    WAIT_W: if(wait_ticks>=WAIT_CYCLES) state<=START_R;
            else wait_ticks<=wait_ticks+1;
    START_R: if(rs_ready) state<=READ;
    READ: begin
     if(out_valid) begin
      if(out_data!==pattern(received,phase)) begin
       failed<=1;fail_code<=1;state<=STOP;
       fail_addr<=BASE+received*16;expected<=pattern(received,phase);observed<=out_data;
      end else begin checked<=checked+1;received<=received+1;end
     end
     if(rs_done) begin
      if(received!=BEATS) begin failed<=1;fail_code<=2;state<=STOP;end
      else if(!phase) begin phase<=1;state<=START_W;ticks<=0;end
      else begin passed<=1;state<=STOP;end
     end
    end
    default: begin failed<=1;fail_code<=2;state<=STOP;end
   endcase
  end
 end
endmodule
