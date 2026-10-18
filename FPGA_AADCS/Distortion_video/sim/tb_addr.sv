`timescale 1ns/1ps

module tb_addr;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg in_valid = 0;
    reg signed [31:0] mx = 0, my = 0;
    wire out_valid;
    wire [31:0] a00, a01, a10, a11;
    wire [3:0] mask;
    wire [11:0] dx, dy;

    addr #(.WIDTH(4), .HEIGHT(3)) dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .map_x_q12(mx), .map_y_q12(my),
        .out_valid(out_valid), .a00(a00), .a01(a01),
        .a10(a10), .a11(a11), .mask(mask), .dx(dx), .dy(dy)
    );

    task check(input signed [31:0] x, input signed [31:0] y,
               input [3:0] m, input [31:0] q00,
               input [31:0] q01, input [31:0] q10,
               input [31:0] q11);
        begin
            @(negedge clk);
            in_valid = 1;
            mx = x; my = y;
            @(negedge clk);
            if (!out_valid || mask !== m || a00 !== q00 ||
                a01 !== q01 || a10 !== q10 || a11 !== q11 ||
                dx !== x[11:0] || dy !== y[11:0])
                $fatal(1, "addr x=%h y=%h mask=%b addr=%0d,%0d,%0d,%0d",
                       x, y, mask, a00, a01, a10, a11);
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        check(32'sh00001800, 32'sh00000800, 4'b1111, 1, 2, 5, 6);
        check(32'sh00003000, 32'sh00002000, 4'b0001, 11, 0, 0, 0);
        check(-32'sh00000800, 32'sh00001000, 4'b1010, 0, 4, 0, 8);
        check(32'sh00004000, 32'sh00000000, 4'b0000, 0, 0, 0, 0);
        $display("PASS tb_addr: interior, right/bottom edge, negative and outside");
        $finish;
    end
endmodule
