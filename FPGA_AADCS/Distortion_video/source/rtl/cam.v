`timescale 1ns/1ps

// OV5640 J7 physical connector: 2 columns x 10 rows, numbered in the
// camera adapter schematic. Power and GND (pins 1, 2, 20) are not RTL ports.
// This module defines the signal interface only; no FPGA pin constraint or
// electrical level conversion is implied. See doc/摄像头2x10接线.md.
module cam #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080,
    // Keep high-Z with populated adapter Y1. Only enable after removing/disabling Y1.
    parameter integer DRIVE_XCLK = 0
)(
    // J7 left/odd column: 3 SCL, 5 VSYNC, 7 EX_RST, 9 D2,
    // 11 D4, 13 D6, 15 D7, 17 PWDN, 19 LED.
    inout  wire        cam_scl,
    input  wire        cam_vsync,
    output wire        cam_rst_n,
    input  wire [7:0]  cam_d,
    output wire        cam_pwdn,
    output wire        cam_led,

    // J7 right/even column: 4 SDA, 6 HREF, 8 D0, 10 D1,
    // 12 D3, 14 D5, 16 PCLK, 18 XCLK.
    inout  wire        cam_sda,
    input  wire        cam_href,
    input  wire        cam_pclk,
    output wire        cam_xclk,

    // Internal controls. SCCB pins are open-drain: 1=pull low, 0=release.
    input  wire        rst_n,
    input  wire        xclk_in,
    input  wire        rst_cmd_n,
    input  wire        pwdn_cmd,
    input  wire        led_cmd,
    input  wire        scl_pull_low,
    input  wire        sda_pull_low,
    output wire        scl_in,
    output wire        sda_in,

    // RGB565 stream in the cam_pclk domain.
    output wire        valid,
    output wire [15:0] pixel,
    output wire [11:0] x,
    output wire [11:0] y,
    output wire        sof,
    output wire        sol
);
    assign cam_xclk = DRIVE_XCLK ? xclk_in : 1'bz;
    assign cam_rst_n = rst_cmd_n;
    assign cam_pwdn = pwdn_cmd;
    assign cam_led = led_cmd;
    assign cam_scl = scl_pull_low ? 1'b0 : 1'bz;
    assign cam_sda = sda_pull_low ? 1'b0 : 1'bz;
    assign scl_in = cam_scl;
    assign sda_in = cam_sda;

    dvp #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)) u_dvp (
        .pclk(cam_pclk), .rst_n(rst_n),
        .vsync(cam_vsync), .href(cam_href), .data(cam_d),
        .valid(valid), .pixel(pixel), .x(x), .y(y),
        .sof(sof), .sol(sol)
    );
endmodule
