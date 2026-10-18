`timescale 1ns/1ps

// Ten-word camera/distortion parameter register bank.
// Write parameters only while the coordinate stream is idle.
module cfg (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               wr_en,
    input  wire [3:0]         wr_addr,
    input  wire signed [31:0] wr_data,
    output reg  signed [31:0] fx_q12,
    output reg  signed [31:0] fy_q12,
    output reg  signed [31:0] cx_q12,
    output reg  signed [31:0] cy_q12,
    output reg  signed [31:0] inv_fx_q30,
    output reg  signed [31:0] inv_fy_q30,
    output reg  signed [31:0] k1_q30,
    output reg  signed [31:0] k2_q30,
    output reg  signed [31:0] p1_q30,
    output reg  signed [31:0] p2_q30
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fx_q12     <= 32'sd0;
            fy_q12     <= 32'sd0;
            cx_q12     <= 32'sd0;
            cy_q12     <= 32'sd0;
            inv_fx_q30 <= 32'sd0;
            inv_fy_q30 <= 32'sd0;
            k1_q30     <= 32'sd0;
            k2_q30     <= 32'sd0;
            p1_q30     <= 32'sd0;
            p2_q30     <= 32'sd0;
        end else if (wr_en) begin
            case (wr_addr)
                4'd0: fx_q12     <= wr_data;
                4'd1: fy_q12     <= wr_data;
                4'd2: cx_q12     <= wr_data;
                4'd3: cy_q12     <= wr_data;
                4'd4: inv_fx_q30 <= wr_data;
                4'd5: inv_fy_q30 <= wr_data;
                4'd6: k1_q30     <= wr_data;
                4'd7: k2_q30     <= wr_data;
                4'd8: p1_q30     <= wr_data;
                4'd9: p2_q30     <= wr_data;
                default: ;
            endcase
        end
    end

endmodule
