// One complete descriptor across DDR -> PCIe clocks, 16..4096 bytes.
// Ownership toggles, not unsynchronised valid pulses. Payload RAM and total
// remain immutable from publish until the read-side acknowledgement returns.
// Common reset MUST cancel both domains and all external in-flight requests.
module bridge (
    input wr_clk,input rd_clk,input rst_n,
    input start,output start_ready,input [12:0] bytes,
    input in_valid,output in_ready,input [127:0] in_data,
    output prepared,input launch,input rd_req,
    output reg [127:0] rd_data,output reg rd_valid,
    output reg rd_done,output reg wr_done,output error
);
    localparam IDLE=2'd0,FILL=2'd1,WAIT=2'd2,HALT=2'd3;
    reg [1:0] state;
    reg [127:0] buffer[0:255];
    reg [8:0] total;
    reg [7:0] wi,ri;
    reg publish,ack,running,wr_error,rd_error;
    reg [1:0] pub_sync /* synthesis syn_preserve=1 */;
    reg [1:0] ack_sync /* synthesis syn_preserve=1 */;
    reg [1:0] err_sync /* synthesis syn_preserve=1 */;
    reg [1:0] wr_reset /* synthesis syn_preserve=1 */;
    reg [1:0] rd_reset /* synthesis syn_preserve=1 */;
    wire wr_ok=wr_reset[1];
    wire rd_ok=rd_reset[1];
    assign start_ready=wr_ok && state==IDLE && !error;
    assign in_ready=wr_ok && state==FILL && !error;
    assign prepared=rd_ok && pub_sync[1]!=ack && !running && !rd_error;
    assign error=wr_error || err_sync[1];
    wire accept_read=rd_req && rd_ok && !rd_error &&
                     (running || (prepared && launch));
    always @(posedge wr_clk or negedge rst_n)begin
        if(!rst_n)begin wr_reset<=0;ack_sync<=0;err_sync<=0;end
        else begin wr_reset<={wr_reset[0],1'b1};ack_sync<={ack_sync[0],ack};
            err_sync<={err_sync[0],rd_error};end
    end
    always @(posedge rd_clk or negedge rst_n)begin
        if(!rst_n)begin rd_reset<=0;pub_sync<=0;end
        else begin rd_reset<={rd_reset[0],1'b1};pub_sync<={pub_sync[0],publish};end
    end
    always @(posedge wr_clk or negedge rst_n)begin
        if(!rst_n)begin state<=IDLE;total<=0;wi<=0;publish<=0;wr_error<=0;wr_done<=0;end
        else if(wr_ok)begin
            wr_done<=0;
            case(state)
                IDLE: if(start && start_ready)begin
                    if(bytes==0 || bytes>4096 || bytes[3:0]!=0)begin
                        wr_error<=1;state<=HALT;
                    end else begin total<=bytes[12:4];wi<=0;state<=FILL;end
                end
                FILL: if(in_valid && in_ready)begin
                    buffer[wi]<=in_data;
                    if({1'b0,wi}==total-1'b1)begin
                        publish<=!publish;wi<=0;state<=WAIT;
                    end else wi<=wi+1'b1;
                end
                WAIT: if(ack_sync[1]==publish)begin state<=IDLE;wr_done<=1;end
                default: state<=HALT;
            endcase
        end
    end
    always @(posedge rd_clk or negedge rst_n)begin
        if(!rst_n)begin ri<=0;ack<=0;running<=0;rd_error<=0;
            rd_data<=0;rd_valid<=0;rd_done<=0;end
        else if(rd_ok)begin
            rd_valid<=0;rd_done<=0;
            if(rd_req && !accept_read)rd_error<=1;
            if(prepared && launch)begin running<=1;ri<=0;end
            if(accept_read)begin
                rd_data<=buffer[ri];rd_valid<=1;
                if({1'b0,ri}==total-1'b1)begin
                    rd_done<=1;ack<=pub_sync[1];running<=0;ri<=0;
                end else begin ri<=ri+1'b1;running<=1;end
            end
        end
    end
endmodule
