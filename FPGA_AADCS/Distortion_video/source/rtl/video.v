// Memory-side video integration. Control/DDR use clk; DMA signals use dma_clk.
// It deliberately exposes a prepared/launch contract: a PCIe command adapter
// must not launch a descriptor until dma_prepared (in dma_clk domain).
// frame_done/segment_done indicate source responses, not host memory completion.
module video #(
    parameter integer FRAME_BEATS=259200,
    parameter [27:0] BASE0=28'h0000000,
    parameter [27:0] BASE1=28'h0400000
)(
    input clk,input dma_clk,input rst_n,
    input in_valid,output in_ready,input [127:0] in_data,
    input in_sof,input in_eof,input [31:0] in_id,input abort,
    output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
    output [127:0] wdata,output [15:0] wstrb,input wready,input wlast,
    output fence_req,input fence_ack,
    output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
    input rvalid,input rlast,input [127:0] rdata,
    output frame_valid,input frame_begin,output [31:0] frame_id,
    input segment_start,output segment_ready,input [12:0] segment_bytes,
    output dma_prepared,input dma_launch,input dma_read,
    output [127:0] dma_data,output dma_valid,output dma_done,output segment_done,
    output reg frame_done,
    output [31:0] good_frames,output [31:0] dropped_frames,
    output error
);
    localparam [31:0] FRAME_BYTES=FRAME_BEATS*16;
    reg active,pending,local_error;
    reg [31:0] cursor;
    reg [27:0] source_base;
    reg [12:0] length;
    wire slot,stored_valid,store_error,fetch_ready,fetch_error,fetch_done;
    wire supply_ready,supply_error,fetch_valid,supply_input_ready,fetch_last;
    wire [127:0] fetch_data;
    wire begin_take=frame_begin && frame_valid;
    wire segment_take=segment_start && segment_ready;
    wire legal=segment_bytes!=0 && segment_bytes<=4096 && segment_bytes[3:0]==0 &&
               {19'd0,segment_bytes}<=FRAME_BYTES-cursor;
    wire start_read=segment_take && legal;
    wire release_frame=segment_done && active && pending &&
                       cursor+{19'd0,length}==FRAME_BYTES;
    assign error=local_error || store_error || fetch_error || supply_error;
    assign frame_valid=stored_valid && !active && !error;
    assign segment_ready=active && !pending && fetch_ready && supply_ready && !error;
    store #(.FRAME_BEATS(FRAME_BEATS),.BASE0(BASE0),.BASE1(BASE1)) u_store(
        .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(in_ready),.in_data(in_data),
        .in_sof(in_sof),.in_eof(in_eof),.in_id(in_id),.abort(abort),
        .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
        .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
        .fence_req(fence_req),.fence_ack(fence_ack),
        .rd_valid(stored_valid),.rd_start(begin_take),.rd_slot(slot),.rd_id(frame_id),
        .rd_finish(release_frame),.good_frames(good_frames),.dropped_frames(dropped_frames),
        .error(store_error));
    fetch u_fetch(.clk(clk),.rst_n(rst_n),.start(start_read),.start_ready(fetch_ready),
        .base_addr(source_base+cursor[27:0]),.beats({23'd0,segment_bytes[12:4]}),
        .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
        .rvalid(rvalid),.rlast(rlast),.rdata(rdata),
        .out_valid(fetch_valid),.out_ready(supply_input_ready),.out_data(fetch_data),
        .out_last(fetch_last),.done(fetch_done),.error(fetch_error));
    bridge u_supply(.wr_clk(clk),.rd_clk(dma_clk),.rst_n(rst_n),.start(start_read),.start_ready(supply_ready),
        .bytes(segment_bytes),.in_valid(fetch_valid),.in_ready(supply_input_ready),
        .in_data(fetch_data),.prepared(dma_prepared),.launch(dma_launch),
        .rd_req(dma_read),.rd_data(dma_data),.rd_valid(dma_valid),
        .rd_done(dma_done),.wr_done(segment_done),.error(supply_error));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            active<=0;pending<=0;cursor<=0;source_base<=0;length<=0;
            local_error<=0;frame_done<=0;
        end else begin
            frame_done<=0;
            if(begin_take)begin active<=1;cursor<=0;source_base<=slot?BASE1:BASE0;end
            if(segment_take)begin
                if(!legal)local_error<=1;
                else begin pending<=1;length<=segment_bytes;end
            end
            if(segment_done && active && pending)begin
                pending<=0;cursor<=cursor+{19'd0,length};
                if(release_frame)begin active<=0;frame_done<=1;end
            end
        end
    end
endmodule
