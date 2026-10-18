`timescale 1ns/1ps

// Single OV5640 SCCB/I2C register read: 16-bit register address, 8-bit data.
// 25 MHz / HALF_CYCLES=125 gives a conservative bus below 100 kHz.
// Open-drain outputs: 1 means pull low, 0 means release. No clock stretching.
module sccb #(
    parameter integer HALF_CYCLES = 125
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [15:0] reg_addr,
    input  wire        sda_in,
    output reg         scl_pull_low,
    output reg         sda_pull_low,
    output wire        busy,
    output reg         done,
    output reg         nack,
    output reg  [7:0]  data_out
);
    localparam [4:0] IDLE            = 5'd0,
                     START_HOLD      = 5'd1,
                     START_LOW       = 5'd2,
                     TX_SETUP        = 5'd3,
                     TX_HIGH         = 5'd4,
                     TX_LOW          = 5'd5,
                     ACK_SETUP       = 5'd6,
                     ACK_HIGH        = 5'd7,
                     ACK_LOW         = 5'd8,
                     RESTART_RELEASE = 5'd9,
                     RESTART_RAISE   = 5'd10,
                     RESTART_ASSERT  = 5'd11,
                     RESTART_LOW     = 5'd12,
                     RX_SETUP        = 5'd13,
                     RX_HIGH         = 5'd14,
                     RX_LOW          = 5'd15,
                     NACK_SETUP      = 5'd16,
                     NACK_HIGH       = 5'd17,
                     NACK_LOW        = 5'd18,
                     STOP_LOW        = 5'd19,
                     STOP_HIGH       = 5'd20,
                     STOP_RELEASE    = 5'd21;

    reg [4:0] state;
    reg [15:0] divider;
    reg [15:0] addr_latched;
    reg [7:0] tx_byte;
    reg [1:0] tx_index;
    reg [2:0] bit_index;
    wire step = (divider == HALF_CYCLES-1);
    assign busy = (state != IDLE);

    always @(*) begin
        scl_pull_low = 1'b0;
        sda_pull_low = 1'b0;
        case (state)
            START_HOLD, RESTART_ASSERT, STOP_HIGH:
                sda_pull_low = 1'b1;
            START_LOW, RESTART_LOW, STOP_LOW: begin
                scl_pull_low = 1'b1;
                sda_pull_low = 1'b1;
            end
            TX_SETUP, TX_LOW: begin
                scl_pull_low = 1'b1;
                sda_pull_low = ~tx_byte[bit_index];
            end
            TX_HIGH:
                sda_pull_low = ~tx_byte[bit_index];
            ACK_SETUP, ACK_LOW, RESTART_RELEASE,
            RX_SETUP, RX_LOW, NACK_SETUP, NACK_LOW:
                scl_pull_low = 1'b1;
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            divider <= 16'd0;
            addr_latched <= 16'd0;
            tx_byte <= 8'd0;
            tx_index <= 2'd0;
            bit_index <= 3'd7;
            done <= 1'b0;
            nack <= 1'b0;
            data_out <= 8'd0;
        end else begin
            done <= 1'b0;
            if (state == IDLE)
                divider <= 16'd0;
            else if (step)
                divider <= 16'd0;
            else
                divider <= divider + 16'd1;

            if (state == IDLE) begin
                if (start) begin
                    addr_latched <= reg_addr;
                    tx_byte <= 8'h78; // OV5640 SCCB 7-bit address 0x3c + W
                    tx_index <= 2'd0;
                    bit_index <= 3'd7;
                    nack <= 1'b0;
                    data_out <= 8'd0;
                    state <= START_HOLD;
                end
            end else if (step) begin
                case (state)
                    START_HOLD: state <= START_LOW;
                    START_LOW: state <= TX_SETUP;
                    TX_SETUP: state <= TX_HIGH;
                    TX_HIGH: state <= TX_LOW;
                    TX_LOW: begin
                        if (bit_index == 0)
                            state <= ACK_SETUP;
                        else begin
                            bit_index <= bit_index - 3'd1;
                            state <= TX_SETUP;
                        end
                    end
                    ACK_SETUP: state <= ACK_HIGH;
                    ACK_HIGH: begin
                        if (sda_in)
                            nack <= 1'b1;
                        state <= ACK_LOW;
                    end
                    ACK_LOW: begin
                        bit_index <= 3'd7;
                        if (tx_index == 0) begin
                            tx_index <= 2'd1;
                            tx_byte <= addr_latched[15:8];
                            state <= TX_SETUP;
                        end else if (tx_index == 1) begin
                            tx_index <= 2'd2;
                            tx_byte <= addr_latched[7:0];
                            state <= TX_SETUP;
                        end else if (tx_index == 2) begin
                            state <= RESTART_RELEASE;
                        end else begin
                            state <= RX_SETUP;
                        end
                    end
                    RESTART_RELEASE: state <= RESTART_RAISE;
                    RESTART_RAISE: state <= RESTART_ASSERT;
                    RESTART_ASSERT: state <= RESTART_LOW;
                    RESTART_LOW: begin
                        tx_byte <= 8'h79; // 7-bit address 0x3c + R
                        tx_index <= 2'd3;
                        bit_index <= 3'd7;
                        state <= TX_SETUP;
                    end
                    RX_SETUP: state <= RX_HIGH;
                    RX_HIGH: begin
                        data_out[bit_index] <= sda_in;
                        state <= RX_LOW;
                    end
                    RX_LOW: begin
                        if (bit_index == 0)
                            state <= NACK_SETUP;
                        else begin
                            bit_index <= bit_index - 3'd1;
                            state <= RX_SETUP;
                        end
                    end
                    NACK_SETUP: state <= NACK_HIGH;
                    NACK_HIGH: state <= NACK_LOW;
                    NACK_LOW: state <= STOP_LOW;
                    STOP_LOW: state <= STOP_HIGH;
                    STOP_HIGH: state <= STOP_RELEASE;
                    STOP_RELEASE: begin
                        state <= IDLE;
                        done <= 1'b1;
                    end
                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
