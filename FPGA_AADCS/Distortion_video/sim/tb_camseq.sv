`timescale 1ns/1ps

module tb_camseq;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg enable = 1;
    wire cam_rst_n, cam_pwdn, ready;

    camseq #(.POWER_CYCLES(3), .RESET_CYCLES(2),
             .SCCB_CYCLES(4)) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .cam_rst_n(cam_rst_n), .cam_pwdn(cam_pwdn), .ready(ready)
    );

    initial begin
        repeat (2) @(negedge clk);
        if (cam_rst_n !== 0 || cam_pwdn !== 1 || ready !== 0)
            $fatal(1, "Unsafe reset outputs");
        rst_n = 1;
        repeat (3) @(negedge clk);
        if (cam_pwdn !== 0 || cam_rst_n !== 0 || ready !== 0)
            $fatal(1, "PWDN release sequence failed");
        repeat (2) @(negedge clk);
        if (cam_rst_n !== 1 || ready !== 0)
            $fatal(1, "RESET release sequence failed");
        repeat (4) @(negedge clk);
        if (ready !== 1)
            $fatal(1, "SCCB wait failed");
        enable = 0;
        @(negedge clk);
        if (cam_rst_n !== 0 || cam_pwdn !== 1 || ready !== 0)
            $fatal(1, "Disable reset failed");
        $display("PASS tb_camseq: power/reset/SCCB wait sequence");
        $finish;
    end
endmodule
