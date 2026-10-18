`timescale 1ns/1ps

// OV5640 power-on control in the 25 MHz board-clock domain.
// Delays: 5 ms before PWDN release, 1 ms before RESETB release,
// then 20 ms before SCCB access. Power rails must already be valid.
module camseq #(
    parameter integer POWER_CYCLES = 125000,
    parameter integer RESET_CYCLES = 25000,
    parameter integer SCCB_CYCLES  = 500000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    output reg  cam_rst_n,
    output reg  cam_pwdn,
    output reg  ready
);
    localparam [1:0] WAIT_POWER = 2'd0,
                     WAIT_RESET = 2'd1,
                     WAIT_SCCB  = 2'd2,
                     RUN        = 2'd3;
    reg [1:0] state;
    reg [31:0] count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT_POWER;
            count <= 32'd0;
            cam_rst_n <= 1'b0;
            cam_pwdn <= 1'b1;
            ready <= 1'b0;
        end else if (!enable) begin
            state <= WAIT_POWER;
            count <= 32'd0;
            cam_rst_n <= 1'b0;
            cam_pwdn <= 1'b1;
            ready <= 1'b0;
        end else begin
            case (state)
                WAIT_POWER: begin
                    if (count == POWER_CYCLES-1) begin
                        count <= 32'd0;
                        cam_pwdn <= 1'b0;
                        state <= WAIT_RESET;
                    end else count <= count + 32'd1;
                end
                WAIT_RESET: begin
                    if (count == RESET_CYCLES-1) begin
                        count <= 32'd0;
                        cam_rst_n <= 1'b1;
                        state <= WAIT_SCCB;
                    end else count <= count + 32'd1;
                end
                WAIT_SCCB: begin
                    if (count == SCCB_CYCLES-1) begin
                        count <= 32'd0;
                        ready <= 1'b1;
                        state <= RUN;
                    end else count <= count + 32'd1;
                end
                default: begin
                    ready <= 1'b1;
                end
            endcase
        end
    end
endmodule
