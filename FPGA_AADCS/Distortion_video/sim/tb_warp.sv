`timescale 1ns/1ps

module tb_warp;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg in_valid = 0;
    reg [11:0] in_x = 0, in_y = 0;
    wire rd_valid, out_valid;
    wire [31:0] a00, a01, a10, a11;
    wire [3:0] mask;
    wire [11:0] dx, dy, rd_x, rd_y, out_x, out_y;
    wire [15:0] out_pixel;
    reg rsp_valid = 0;
    reg [15:0] p00 = 0, p01 = 0, p10 = 0, p11 = 0;
    reg [3:0] rsp_mask = 0;
    reg [11:0] rsp_dx = 0, rsp_dy = 0, rsp_x = 0, rsp_y = 0;
    integer received = 0;
    integer requested = 0;
    integer x, y;

    function [15:0] image;
        input [31:0] addr;
        reg [4:0] red, blue;
        reg [5:0] green;
        begin
            red = addr % 4;
            green = addr / 4;
            blue = red;
            image = {red, green, blue};
        end
    endfunction

    warp #(.WIDTH(4), .HEIGHT(3)) dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .in_x(in_x), .in_y(in_y),
        .fx_q12(32'sd4096), .fy_q12(32'sd4096),
        .cx_q12(32'sd0), .cy_q12(32'sd0),
        .inv_fx_q30(32'sd1073741824),
        .inv_fy_q30(32'sd1073741824),
        .k1_q30(32'sd0), .k2_q30(32'sd0),
        .p1_q30(32'sd0), .p2_q30(32'sd0),
        .rd_valid(rd_valid), .rd_a00(a00), .rd_a01(a01),
        .rd_a10(a10), .rd_a11(a11), .rd_mask(mask),
        .rd_dx(dx), .rd_dy(dy), .rd_x(rd_x), .rd_y(rd_y),
        .rsp_valid(rsp_valid), .rsp_p00(p00), .rsp_p01(p01),
        .rsp_p10(p10), .rsp_p11(p11), .rsp_mask(rsp_mask),
        .rsp_dx(rsp_dx), .rsp_dy(rsp_dy),
        .rsp_x(rsp_x), .rsp_y(rsp_y),
        .out_valid(out_valid), .out_pixel(out_pixel),
        .out_x(out_x), .out_y(out_y)
    );

    // One-cycle, four-read behavioral frame store. The real DDR/tile-cache
    // implementation must meet this logical interface without using BRAM
    // proportional to a whole 1080p frame.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_valid <= 0;
            p00 <= 0; p01 <= 0; p10 <= 0; p11 <= 0;
            rsp_mask <= 0;
            rsp_dx <= 0; rsp_dy <= 0;
            rsp_x <= 0; rsp_y <= 0;
        end else begin
            rsp_valid <= rd_valid;
            p00 <= image(a00); p01 <= image(a01);
            p10 <= image(a10); p11 <= image(a11);
            rsp_mask <= mask;
            rsp_dx <= dx; rsp_dy <= dy;
            rsp_x <= rd_x; rsp_y <= rd_y;
        end
    end

    always @(posedge clk) if (rst_n) begin
        #1;
        if (rd_valid) begin
            if (rd_x !== (requested % 4) || rd_y !== (requested / 4))
                $fatal(1, "request tag mismatch #%0d at %0d,%0d",
                       requested, rd_x, rd_y);
            requested = requested + 1;
        end
        if (out_valid) begin
            if (out_x !== (received % 4) || out_y !== (received / 4) ||
                out_pixel !== image(received))
                $fatal(1, "warp mismatch #%0d: (%0d,%0d)=%h expected %h",
                       received, out_x, out_y, out_pixel, image(received));
            received = received + 1;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        for (y = 0; y < 3; y = y + 1)
            for (x = 0; x < 4; x = x + 1) begin
                @(negedge clk);
                in_valid = 1;
                in_x = x; in_y = y;
            end
        @(negedge clk); in_valid = 0;
        repeat (35) @(negedge clk);
        if (requested != 12 || received != 12)
            $fatal(1, "warp count requested=%0d received=%0d",
                   requested, received);
        $display("PASS tb_warp: 12 identity-mapped RGB565 pixels");
        $finish;
    end
endmodule
