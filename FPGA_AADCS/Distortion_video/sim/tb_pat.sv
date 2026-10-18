`timescale 1ns/1ps

module tb_pat;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;
    reg enable = 1'b0;
    wire valid, sof, sol;
    wire [15:0] pixel;
    wire [11:0] x, y;
    wire [31:0] frame_id;
    integer cycles = 0;
    integer pixels = 0;
    integer frames = 0;

    pat #(.WIDTH(8), .HEIGHT(4), .H_TOTAL(10), .V_TOTAL(6)) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable),
        .valid(valid), .pixel(pixel), .x(x), .y(y),
        .sof(sof), .sol(sol), .frame_id(frame_id)
    );

    always @(posedge clk) begin
        #1;
        if (enable) begin
            if (valid) begin
                if (x >= 8 || y >= 4 ||
                    sof !== ((x == 0) && (y == 0)) ||
                    sol !== (x == 0))
                    $fatal(1, "Bad active pixel: x=%0d y=%0d sof=%b sol=%b", x, y, sof, sol);
                pixels = pixels + 1;
                if (sof) begin
                    if (frame_id !== frames)
                        $fatal(1, "Wrong frame ID %0d, expected %0d", frame_id, frames);
                    frames = frames + 1;
                end
            end
            cycles = cycles + 1;
            if (cycles == 120) begin
                if (pixels != 64 || frames != 2)
                    $fatal(1, "Expected 64 pixels/2 frames, got %0d/%0d", pixels, frames);
                $display("PASS tb_pat: 2 frames, 64 active pixels, 120 total cycles");
                $finish;
            end
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);
        enable = 1'b1;
    end
endmodule
