// DDR user-domain burst reader. No RREADY exists on the Pango DDR interface:
// reserve a whole burst before AR, absorb every return, then drain to consumer.
// One outstanding command, 1..16 beats, no 4 KiB crossing. Byte addresses.
module fetch #(parameter OUTSTANDING=1)(
    input clk, input rst_n,
    input start, output start_ready,
    input [27:0] base_addr, input [31:0] beats,
    output arvalid, input arready, output [27:0] araddr, output [3:0] arlen,
    input rvalid, input rlast, input [127:0] rdata,
    output out_valid, input out_ready, output [127:0] out_data,
    output out_last, output done, output error
);
    generate if(OUTSTANDING==1)begin:serial
        fetch_serial reader(.clk(clk),.rst_n(rst_n),.start(start),.start_ready(start_ready),
          .base_addr(base_addr),.beats(beats),.arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
          .rvalid(rvalid),.rlast(rlast),.rdata(rdata),.out_valid(out_valid),.out_ready(out_ready),
          .out_data(out_data),.out_last(out_last),.done(done),.error(error));
    end else begin:queued
        fetch_queue #(.OUTSTANDING(OUTSTANDING)) reader(.clk(clk),.rst_n(rst_n),.start(start),.start_ready(start_ready),
          .base_addr(base_addr),.beats(beats),.arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
          .rvalid(rvalid),.rlast(rlast),.rdata(rdata),.out_valid(out_valid),.out_ready(out_ready),
          .out_data(out_data),.out_last(out_last),.done(done),.error(error));
    end endgenerate
endmodule

module fetch_serial (
    input clk, input rst_n,
    input start, output start_ready,
    input [27:0] base_addr, input [31:0] beats,
    output arvalid, input arready, output [27:0] araddr,
    output [3:0] arlen,
    input rvalid, input rlast, input [127:0] rdata,
    output out_valid, input out_ready, output [127:0] out_data,
    output out_last, output reg done, output reg error
);
    localparam IDLE=3'd0, ADDR=3'd1, RECV=3'd2, SEND=3'd3, HALT=3'd4;
    reg [2:0] state;
    reg [127:0] buffer[0:15];
    reg [3:0] index;
    reg [27:0] cursor;
    reg [31:0] remaining;
    wire [8:0] page_beats = 9'd256 - {1'b0,cursor[11:4]};
    wire [4:0] capacity = (page_beats < 16) ? page_beats[4:0] : 5'd16;
    wire [4:0] chunk = (remaining < {27'd0,capacity}) ? remaining[4:0] : capacity;
    wire [36:0] limit = {9'd0,base_addr} + {1'b0,beats,4'b0};
    wire legal = (base_addr[3:0] == 0) && beats != 0 && limit <= 37'h010000000;
    assign start_ready = state == IDLE && !error;
    assign arvalid = state == ADDR;
    assign araddr = cursor;
    assign arlen = chunk[3:0] - 1'b1;
    assign out_valid = state == SEND;
    assign out_data = buffer[index];
    assign out_last = out_valid && remaining == {27'd0,chunk} &&
                      {1'b0,index} == chunk - 1'b1;
    // One physical write port. Keep both the immediate first return and the
    // later returns on the SAME indexed assignment: PDS 2022.2 inferred the
    // old separate buffer[0]/buffer[index] assignments with write address 0,
    // overwriting beat 0 on hardware although RTL simulation was correct.
    wire receive = rvalid && ((state == ADDR && arready) || state == RECV);
    always @(posedge clk)
        if (rst_n && receive) buffer[index] <= rdata;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; index <= 0; cursor <= 0; remaining <= 0;
            done <= 0; error <= 0;
        end else begin
            done <= 0;
            case(state)
                IDLE: if (rvalid) begin error <= 1; state <= HALT; end
                else if (start && start_ready) begin
                    if (!legal) begin error <= 1; state <= HALT; end
                    else begin cursor <= base_addr; remaining <= beats;
                        index <= 0; state <= ADDR; end
                end
                ADDR: begin
                    if (rvalid && !arready) begin error <= 1; state <= HALT; end
                    else if (arready) begin
                        // Some controllers can return beat 0 with AR acceptance.
                        if (rvalid) begin
                            if (rlast != (chunk == 1)) begin error <= 1; state <= HALT; end
                            else if (chunk == 1) begin index <= 0; state <= SEND; end
                            else begin index <= 1; state <= RECV; end
                        end else begin index <= 0; state <= RECV; end
                    end
                end
                RECV: if (rvalid) begin
                    if (rlast != ({1'b0,index} == chunk - 1'b1)) begin
                        error <= 1; state <= HALT;
                    end else if ({1'b0,index} == chunk - 1'b1) begin
                        index <= 0; state <= SEND;
                    end else index <= index + 1'b1;
                end
                SEND: if (rvalid) begin error <= 1; state <= HALT; end
                else if (out_ready) begin
                    if ({1'b0,index} == chunk - 1'b1) begin
                        index <= 0;
                        if (remaining == {27'd0,chunk}) begin done <= 1; state <= IDLE; end
                        else begin remaining <= remaining - {27'd0,chunk};
                            cursor <= cursor + {19'd0,chunk,4'd0}; state <= ADDR; end
                    end else index <= index + 1'b1;
                end
                default: state <= HALT;
            endcase
        end
    end
endmodule

// Reserve return storage before issuing AR: this native interface has no
// RREADY. ID=0 returns are ordered; burst lengths form an ordered tag FIFO.
// OUTSTANDING must be 2/4/8/16. Consumers can stall indefinitely, including
// when every reserved beat is still in flight. No descriptor ABI changes.
module fetch_queue #(parameter OUTSTANDING=8)(
    input clk,rst_n,start,output start_ready,
    input [27:0] base_addr,input [31:0] beats,
    output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
    input rvalid,rlast,input [127:0] rdata,
    output out_valid,input out_ready,output [127:0] out_data,
    output out_last,output reg done,error
);
    localparam QB=$clog2(OUTSTANDING),DEPTH=16*OUTSTANDING,PB=$clog2(DEPTH);
    reg active;reg [27:0] cursor;reg [31:0] issue_left,consume_left;
    reg [QB:0] pending;reg [QB-1:0] head,tail;
    reg [4:0] lengths[0:OUTSTANDING-1];reg [4:0] return_beat,head_length;
    reg [PB:0] reserved,filled;reg [PB-1:0] write_ptr,read_ptr;
    reg [127:0] buffer[0:DEPTH-1];
    // Equivalent 4-KiB boundary and min calculations, without a 32-bit
    // variable compare on the ARVALID -> wide counter-enable critical path.
    wire [4:0] capacity=cursor[11:8]==4'hf ?
                        5'd16-{1'b0,cursor[7:4]} : 5'd16;
    wire [4:0] chunk=(|issue_left[31:5]) ? capacity :
                     issue_left[4:0]<capacity ? issue_left[4:0] : capacity;
    wire [36:0] limit={9'd0,base_addr}+{1'b0,beats,4'b0};
    wire legal=base_addr[3:0]==0 && beats!=0 && limit<=37'h010000000;
    assign start_ready=!active && !error;
    assign arvalid=active && !error && issue_left!=0 && pending<OUTSTANDING && reserved+chunk<=DEPTH;
    assign araddr=cursor;assign arlen=chunk-1'b1;
    wire push=arvalid && arready;
    wire available=pending!=0 || push;
    wire receive=active && !error && rvalid && available;
    wire [4:0] response_length=pending!=0?head_length:chunk;
    wire [QB-1:0] next_head=head+1'b1;
    wire pop=receive && rlast;
    assign out_valid=active && !error && filled!=0;
    assign out_data=buffer[read_ptr];
    assign out_last=out_valid && consume_left==1;
    wire take=out_valid && out_ready;
    always @(posedge clk)if(receive)buffer[write_ptr]<=rdata;
    always @(posedge clk or negedge rst_n)
    if(!rst_n)begin
        active<=0;cursor<=0;issue_left<=0;consume_left<=0;pending<=0;
        head<=0;tail<=0;return_beat<=0;head_length<=0;reserved<=0;filled<=0;
        write_ptr<=0;read_ptr<=0;done<=0;error<=0;
    end else begin
        done<=0;
        if(start && start_ready)begin
            if(!legal)error<=1;
            else active<=1;
            // These private counters may load even for a rejected command:
            // active remains low and error permanently blocks all requests.
            // Keep the address-sum comparator off their wide clock enables.
            cursor<=base_addr;issue_left<=beats;consume_left<=beats;
            pending<=0;head<=0;tail<=0;return_beat<=0;head_length<=0;reserved<=0;filled<=0;write_ptr<=0;read_ptr<=0;
        end else begin
            if(rvalid && (!active || !available))error<=1;
            if(push)begin
                lengths[tail]<=chunk;tail<=tail+1'b1;
                cursor<=cursor+{19'd0,chunk,4'b0};issue_left<=issue_left-chunk;
            end
            // Keep the response tag in a FF. Forward an empty/replaced head
            // directly from AR; otherwise look ahead when RLAST advances it.
            if(push && (pending==0 || (pending==1 && pop)))head_length<=chunk;
            else if(pop && pending>1)head_length<=lengths[next_head];
            if(receive)begin
                if(rlast!=(return_beat==response_length-1'b1))error<=1;
                write_ptr<=write_ptr+1'b1;return_beat<=rlast?5'd0:return_beat+1'b1;
            end
            if(pop)head<=head+1'b1;
            case({push,pop})2'b10:pending<=pending+1'b1;2'b01:pending<=pending-1'b1;endcase
            case({receive,take})2'b10:filled<=filled+1'b1;2'b01:filled<=filled-1'b1;endcase
            if(push || take)reserved<=reserved+(push?chunk:5'd0)-(take?1'b1:1'b0);
            if(take)begin
                read_ptr<=read_ptr+1'b1;consume_left<=consume_left-1'b1;
                if(consume_left==1)begin active<=0;done<=1;end
            end
        end
    end
endmodule
