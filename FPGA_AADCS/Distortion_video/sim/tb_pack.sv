`timescale 1ns/1ps

module tb_pack;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg in_valid = 0;
    wire in_ready;
    reg [15:0] in_pixel = 0;
    reg in_sof = 0, in_eof = 0;
    reg [31:0] in_frame_id = 0;
    wire out_valid;
    reg out_ready = 0;
    wire [127:0] out_data;
    wire out_sof, out_eof;
    wire [31:0] out_frame_id;
    wire frame_error;
    integer got = 0;
    integer i;
    reg [127:0] want;

    pack dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_ready(in_ready),
        .in_pixel(in_pixel), .in_sof(in_sof), .in_eof(in_eof),
        .in_frame_id(in_frame_id), .out_valid(out_valid),
        .out_ready(out_ready), .out_data(out_data),
        .out_sof(out_sof), .out_eof(out_eof),
        .out_frame_id(out_frame_id), .frame_error(frame_error)
    );

    function [127:0] beat;
        input [15:0] base;
        integer j;
        begin
            beat = 128'd0;
            for (j = 0; j < 8; j = j + 1)
                beat[j*16 +: 16] = base + j;
        end
    endfunction

    task send(input [15:0] pixel, input sof, input eof,
              input [31:0] fid);
        integer timeout;
        begin
            @(negedge clk);
            in_valid = 1;
            in_pixel = pixel;
            in_sof = sof;
            in_eof = eof;
            in_frame_id = fid;
            timeout = 0;
            do begin
                @(posedge clk);
                timeout = timeout + 1;
                if (timeout > 30) $fatal(1, "input handshake timeout");
            end while (!in_ready);
            @(negedge clk);
            in_valid = 0;
            in_sof = 0;
            in_eof = 0;
        end
    endtask

    always @(posedge clk) if (rst_n && out_valid && out_ready) begin
        want = got == 0 ? beat(16'h1000) : beat(16'h2000);
        if (out_data !== want || !out_sof || !out_eof ||
            out_frame_id !== (got == 0 ? 32'd7 : 32'd8))
            $fatal(1, "beat %0d data=%h sof=%b eof=%b fid=%0d",
                   got, out_data, out_sof, out_eof, out_frame_id);
        got = got + 1;
    end

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        for (i = 0; i < 8; i = i + 1)
            send(16'h1000 + i, i == 0, i == 7, 7);
        if (!out_valid || out_data !== beat(16'h1000))
            $fatal(1, "first beat not held while stalled");
        for (i = 0; i < 7; i = i + 1)
            send(16'h2000 + i, i == 0, 0, 8);
        if (in_ready !== 0 || out_data !== beat(16'h1000))
            $fatal(1, "backpressure did not protect pending beat");
        @(negedge clk); out_ready = 1;
        send(16'h2007, 0, 1, 8);
        repeat (4) @(negedge clk);
        if (got != 2 || frame_error)
            $fatal(1, "got=%0d frame_error=%b", got, frame_error);
        $display("PASS tb_pack: byte lanes, frame markers and backpressure");
        $finish;
    end
endmodule
