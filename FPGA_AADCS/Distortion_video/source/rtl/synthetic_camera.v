`timescale 1ns/1ps
// Free-running virtual OV5640: distorted chart -> LOW-byte-first RGB565 DVP.
// 25 MHz / (2*800*520) = 30.048 source frames/s at 640x400.
// No capture-enable/backpressure input: the consumer must select whole frames.
module synthetic_camera #(
    parameter integer WIDTH=640, HEIGHT=400,
    parameter integer H_TOTAL=WIDTH+160, V_TOTAL=HEIGHT+120
)(
    input wire clk, input wire rst_n,
    output wire vsync, output reg href, output reg [7:0] data,
    output reg [31:0] frame_id
);
    reg [12:0] h_count;
    reg [11:0] v_count;
    reg [8:0] sync_pipe;
    reg high_pending;
    reg [7:0] high_byte;
    wire active=(h_count<2*WIDTH && v_count<HEIGHT);
    wire sample=active && !h_count[0];
    wire raw_vsync=(v_count>=HEIGHT+1 && v_count<HEIGHT+3);
    wire chart_valid;
    wire [15:0] chart_pixel;
    wire [11:0] chart_x,chart_y;
    // The bottom-left 8x8 blocks encode frame_id[7:0], making live video
    // distinguishable from a frozen picture. The remaining chart is unchanged.
    wire [15:0] output_pixel=(chart_y>=HEIGHT-8 && chart_x<64) ?
        (frame_id[chart_x[5:3]] ? 16'hffe0 : 16'h001f) : chart_pixel;
    chart #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DISTORTED(1)) image(
        .clk(clk),.rst_n(rst_n),.in_valid(sample),
        .in_x(h_count[12:1]),.in_y(v_count),.out_valid(chart_valid),
        .pixel(chart_pixel),.out_x(chart_x),.out_y(chart_y));
    assign vsync=sync_pipe[8];
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            h_count<=0;v_count<=0;frame_id<=0;sync_pipe<=0;
            high_pending<=0;high_byte<=0;href<=0;data<=0;
        end else begin
            sync_pipe<={sync_pipe[7:0],raw_vsync};
            if(h_count==2*H_TOTAL-1) begin
                h_count<=0;
                if(v_count==V_TOTAL-1) begin v_count<=0;frame_id<=frame_id+1'b1;end
                else v_count<=v_count+1'b1;
            end else h_count<=h_count+1'b1;
            href<=chart_valid || high_pending;
            if(chart_valid) begin
                data<=output_pixel[7:0];high_byte<=output_pixel[15:8];high_pending<=1;
            end else if(high_pending) begin data<=high_byte;high_pending<=0;end
            else data<=0;
        end
    end
endmodule
