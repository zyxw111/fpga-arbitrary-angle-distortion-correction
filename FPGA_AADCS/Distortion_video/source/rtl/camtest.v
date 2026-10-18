`timescale 1ns/1ps

// Alternative bring-up top, NOT the production video top.
// The 25 MHz board oscillator is wired to FPGA ball V4; this file only
// reads OV5640 chip ID (0x5640) and watches raw DVP frame timing.
// No 1080p30 register table or PDS pin constraints are included yet.
module camtest #(
    parameter integer POWER_CYCLES = 125000,
    parameter integer RESET_CYCLES = 25000,
    parameter integer SCCB_CYCLES  = 500000,
    parameter integer HALF_CYCLES  = 125,
    // Adapter Y1 normally supplies 24MHz. Do not drive its output from FPGA.
    parameter integer DRIVE_XCLK = 0
)(
    input  wire       clk25,
    input  wire       rst_n,
    inout  wire       cam_scl,
    inout  wire       cam_sda,
    input  wire       cam_vsync,
    input  wire       cam_href,
    input  wire       cam_pclk,
    input  wire [7:0] cam_d,
    output wire       cam_rst_n,
    output wire       cam_pwdn,
    output wire       cam_xclk,
    output wire       cam_led,
    output wire       led_id,
    output wire       led_frame,
    output wire       led_error
);
    wire seq_rst_n, seq_pwdn, seq_ready;
    wire scl_in, sda_in;
    wire pix_valid, pix_sof, pix_sol;
    wire [15:0] pix_data;
    wire [11:0] pix_x, pix_y;
    wire scl_low, sda_low, sccb_busy, sccb_done, sccb_nack;
    wire [7:0] sccb_data;
    reg sccb_start;
    reg [15:0] sccb_addr;
    reg [7:0] id_hi, id_lo;
    reg id_nack, id_done, id_ok;
    reg [2:0] state;
    wire frame_toggle, frame_bad;
    wire [11:0] last_lines;
    wire [31:0] good_frames, bad_frames;
    reg frame_sync1, frame_sync2, bad_sync1, bad_sync2;

    localparam [2:0] WAIT_POWER = 3'd0,
                     START_HI   = 3'd1,
                     WAIT_HI    = 3'd2,
                     WAIT_LO    = 3'd3,
                     FINISHED   = 3'd4;

    camseq #(
        .POWER_CYCLES(POWER_CYCLES),
        .RESET_CYCLES(RESET_CYCLES),
        .SCCB_CYCLES(SCCB_CYCLES)
    ) u_seq (
        .clk(clk25), .rst_n(rst_n), .enable(1'b1),
        .cam_rst_n(seq_rst_n), .cam_pwdn(seq_pwdn), .ready(seq_ready)
    );

    cam #(.DRIVE_XCLK(DRIVE_XCLK)) u_cam (
        .cam_scl(cam_scl), .cam_sda(cam_sda),
        .cam_vsync(cam_vsync), .cam_href(cam_href),
        .cam_pclk(cam_pclk), .cam_d(cam_d),
        .cam_rst_n(cam_rst_n), .cam_pwdn(cam_pwdn),
        .cam_led(cam_led), .cam_xclk(cam_xclk),
        .rst_n(rst_n & seq_ready), .xclk_in(clk25),
        .rst_cmd_n(seq_rst_n), .pwdn_cmd(seq_pwdn), .led_cmd(1'b0),
        .scl_pull_low(scl_low), .sda_pull_low(sda_low),
        .scl_in(scl_in), .sda_in(sda_in),
        .valid(pix_valid), .pixel(pix_data), .x(pix_x), .y(pix_y),
        .sof(pix_sof), .sol(pix_sol)
    );

    sccb #(.HALF_CYCLES(HALF_CYCLES)) u_sccb (
        .clk(clk25), .rst_n(rst_n & seq_ready),
        .start(sccb_start), .reg_addr(sccb_addr), .sda_in(sda_in),
        .scl_pull_low(scl_low), .sda_pull_low(sda_low),
        .busy(sccb_busy), .done(sccb_done), .nack(sccb_nack),
        .data_out(sccb_data)
    );

    always @(posedge clk25 or negedge rst_n) begin
        if (!rst_n) begin
            state <= WAIT_POWER;
            sccb_start <= 1'b0;
            sccb_addr <= 16'd0;
            id_hi <= 8'd0;
            id_lo <= 8'd0;
            id_nack <= 1'b0;
            id_done <= 1'b0;
            id_ok <= 1'b0;
        end else begin
            sccb_start <= 1'b0;
            case (state)
                WAIT_POWER: if (seq_ready) state <= START_HI;
                START_HI: begin
                    sccb_addr <= 16'h300a;
                    sccb_start <= 1'b1;
                    state <= WAIT_HI;
                end
                WAIT_HI: if (sccb_done) begin
                    id_hi <= sccb_data;
                    id_nack <= sccb_nack;
                    sccb_addr <= 16'h300b;
                    sccb_start <= 1'b1;
                    state <= WAIT_LO;
                end
                WAIT_LO: if (sccb_done) begin
                    id_lo <= sccb_data;
                    id_ok <= !id_nack && !sccb_nack &&
                             (id_hi == 8'h56) && (sccb_data == 8'h40);
                    id_done <= 1'b1;
                    state <= FINISHED;
                end
                default: ;
            endcase
        end
    end

    cammon u_mon (
        .pclk(cam_pclk), .rst_n(rst_n),
        .vsync(cam_vsync), .href(cam_href),
        .frame_toggle(frame_toggle), .last_bad(frame_bad),
        .last_lines(last_lines),
        .good_frames(good_frames), .bad_frames(bad_frames)
    );

    // Status only crosses to the board-clock domain through synchronizers.
    always @(posedge clk25 or negedge rst_n) begin
        if (!rst_n) begin
            frame_sync1 <= 1'b0;
            frame_sync2 <= 1'b0;
            bad_sync1 <= 1'b0;
            bad_sync2 <= 1'b0;
        end else begin
            frame_sync1 <= frame_toggle;
            frame_sync2 <= frame_sync1;
            bad_sync1 <= frame_bad;
            bad_sync2 <= bad_sync1;
        end
    end
    assign led_id = id_ok;
    assign led_frame = frame_sync2;
    assign led_error = id_done && (!id_ok || bad_sync2);
endmodule
