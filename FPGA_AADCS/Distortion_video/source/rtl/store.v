// Framed 128-bit stream -> two owned DDR slots via prebuffered writes.
// Single DDR user clock. An external CDC supplies stream/abort controls.
// Bad/aborted frames are padded to finish issued writes, then discarded.
// fence_ack MUST establish DDR write visibility before frame publication.
// Never tie fence_ack to burst.done without a controller-specific guarantee.
module store #(
    parameter integer FRAME_BEATS=259200,
    parameter [27:0] BASE0=28'h0000000,
    parameter [27:0] BASE1=28'h0400000
)(
    input clk, input rst_n,
    input in_valid, output in_ready, input [127:0] in_data,
    input in_sof, input in_eof, input [31:0] in_id, input abort,
    output awvalid, input awready, output [27:0] awaddr,
    output [3:0] awlen, output [127:0] wdata, output [15:0] wstrb,
    input wready, input wlast,
    output fence_req, input fence_ack,
    output rd_valid, input rd_start, output rd_slot,
    output [31:0] rd_id, input rd_finish,
    output reg [31:0] good_frames, output reg [31:0] dropped_frames,
    output error
);
    localparam IDLE=3'd0, FIRST=3'd1, FEED=3'd2, WAIT=3'd3, FENCE=3'd4, RELEASE=3'd5;
    localparam [63:0] FRAME_BYTES=64'd16*FRAME_BEATS;
    localparam CONFIG_OK = FRAME_BEATS >= 16 && FRAME_BEATS % 16 == 0 &&
        BASE0[7:0] == 0 && BASE1[7:0] == 0 &&
        ({36'd0,BASE0}+FRAME_BYTES <= 64'h10000000) &&
        ({36'd0,BASE1}+FRAME_BYTES <= 64'h10000000) &&
        (({36'd0,BASE0}+FRAME_BYTES <= {36'd0,BASE1}) ||
         ({36'd0,BASE1}+FRAME_BYTES <= {36'd0,BASE0}));
    reg [2:0] state;
    reg [127:0] first_data;
    reg [31:0] frame_id, count;
    reg bad, pad;
    wire wr_ready,wr_slot,frame_error,burst_ready,burst_done,burst_error;
    wire take_frame = CONFIG_OK && !error && state == IDLE &&
                      in_valid && in_sof && wr_ready && burst_ready && !abort;
    wire push_ready;
    wire push_valid = state == FIRST || (state == FEED && (pad || in_valid));
    wire [127:0] push_data = state == FIRST ? first_data : (pad ? 128'd0 : in_data);
    assign error = !CONFIG_OK || frame_error || burst_error;
    assign in_ready = CONFIG_OK && !error &&
                      (state == IDLE || (state == FEED && !pad && push_ready));
    assign fence_req = state == FENCE && !error;
    frame u_frame (
        .clk(clk),.rst_n(rst_n),.wr_start(take_frame),.wr_ready(wr_ready),.wr_slot(wr_slot),
        .wr_finish(state == RELEASE),.wr_good(!bad && !abort),.wr_id(frame_id),
        .rd_valid(rd_valid),.rd_start(rd_start),.rd_slot(rd_slot),.rd_id(rd_id),
        .rd_finish(rd_finish),.error(frame_error)
    );
    burst u_burst (
        .clk(clk),.rst_n(rst_n),.start(take_frame),.start_ready(burst_ready),
        .base_addr(wr_slot ? BASE1 : BASE0),.beats(FRAME_BEATS),
        .in_valid(push_valid),.in_ready(push_ready),.in_data(push_data),
        .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
        .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
        .done(burst_done),.error(burst_error)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; first_data <= 0; frame_id <= 0; count <= 0;
            bad <= 0; pad <= 0; good_frames <= 0; dropped_frames <= 0;
        end else begin
            if (abort && state != IDLE) begin bad <= 1; pad <= 1; end
            case(state)
                IDLE: if (in_valid && in_ready && in_sof) begin
                    if (take_frame) begin
                        first_data <= in_data; frame_id <= in_id;
                        bad <= in_eof; pad <= in_eof; count <= 0; state <= FIRST;
                    end else dropped_frames <= dropped_frames + 1'b1;
                end
                FIRST: if (push_ready) begin count <= 1; state <= FEED; end
                FEED: if (push_valid && push_ready) begin
                    count <= count + 1'b1;
                    if (!pad) begin
                        if (in_sof || in_id != frame_id ||
                            in_eof != (count == FRAME_BEATS-1)) bad <= 1;
                        if (in_eof && count != FRAME_BEATS-1) pad <= 1;
                    end
                    if (count == FRAME_BEATS-1) state <= WAIT;
                end
                WAIT: if (burst_done) state <= FENCE;
                FENCE: if (fence_ack && !error) state <= RELEASE;
                RELEASE: begin
                    if (bad || abort) dropped_frames <= dropped_frames + 1'b1;
                    else good_frames <= good_frames + 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
