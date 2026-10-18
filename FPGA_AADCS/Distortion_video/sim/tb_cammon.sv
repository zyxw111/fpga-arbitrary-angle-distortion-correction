`timescale 1ns/1ps

module tb_cammon;
    reg pclk = 0;
    always #5 pclk = ~pclk;
    reg rst_n = 0;
    reg vsync = 0;
    reg href = 0;
    wire frame_toggle, last_bad;
    wire [11:0] last_lines;
    wire [31:0] good_frames, bad_frames;

    cammon #(.WIDTH(2), .HEIGHT(2)) dut (
        .pclk(pclk), .rst_n(rst_n), .vsync(vsync), .href(href),
        .frame_toggle(frame_toggle), .last_bad(last_bad),
        .last_lines(last_lines), .good_frames(good_frames),
        .bad_frames(bad_frames)
    );

    task pulse_vsync;
        begin
            @(negedge pclk); vsync = 1;
            @(negedge pclk); vsync = 0;
        end
    endtask
    task line(input integer bytes);
        integer i;
        begin
            @(negedge pclk); href = 1;
            for (i = 0; i < bytes; i = i + 1)
                @(negedge pclk);
            href = 0;
            @(negedge pclk);
        end
    endtask

    initial begin
        repeat (2) @(negedge pclk);
        rst_n = 1;
        pulse_vsync();
        line(4);
        line(4);
        pulse_vsync();
        if (good_frames !== 1 || bad_frames !== 0 || last_bad !== 0 ||
            last_lines !== 2)
            $fatal(1, "Expected good frame: good=%0d bad=%0d lines=%0d",
                   good_frames, bad_frames, last_lines);
        line(3);
        line(4);
        pulse_vsync();
        if (good_frames !== 1 || bad_frames !== 1 || last_bad !== 1)
            $fatal(1, "Expected bad frame: good=%0d bad=%0d",
                   good_frames, bad_frames);
        $display("PASS tb_cammon: exact and short-line frames");
        $finish;
    end
endmodule
