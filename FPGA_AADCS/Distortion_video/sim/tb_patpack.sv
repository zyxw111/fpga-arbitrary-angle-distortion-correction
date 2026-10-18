`timescale 1ns/1ps

module tb_patpack;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    wire valid, sof, sol;
    wire [15:0] pixel;
    wire [11:0] x, y;
    wire [31:0] frame_id;
    wire ready, beat_valid, beat_sof, beat_eof, frame_error;
    wire [127:0] beat_data;
    wire [31:0] beat_frame_id;
    integer beats = 0;
    integer i;
    reg [127:0] expected;

    pat #(.WIDTH(8), .HEIGHT(2), .H_TOTAL(10), .V_TOTAL(3)) u_pat (
        .clk(clk), .rst_n(rst_n), .enable(1'b1),
        .valid(valid), .pixel(pixel), .x(x), .y(y),
        .sof(sof), .sol(sol), .frame_id(frame_id)
    );
    pack u_pack (
        .clk(clk), .rst_n(rst_n),
        .in_valid(valid), .in_ready(ready),
        .in_pixel(pixel), .in_sof(valid && sof),
        .in_eof(valid && x == 7 && y == 1),
        .in_frame_id(frame_id), .out_valid(beat_valid),
        .out_ready(1'b1), .out_data(beat_data),
        .out_sof(beat_sof), .out_eof(beat_eof),
        .out_frame_id(beat_frame_id), .frame_error(frame_error)
    );

    initial begin
        expected = {16'h0000, 16'h001f, 16'hf800, 16'hf81f,
                    16'h07e0, 16'h07ff, 16'hffe0, 16'hffff};
        repeat (3) @(negedge clk);
        rst_n = 1;
    end

    always @(posedge clk) if (rst_n) begin
        if (valid && !ready)
            $fatal(1, "unexpected backpressure to free-running pattern");
        if (beat_valid) begin
            if (beat_data !== expected || beat_sof !== (beats % 2 == 0) ||
                beat_eof !== (beats % 2 == 1) ||
                beat_frame_id !== (beats / 2))
                $fatal(1, "pattern beat #%0d data=%h sof=%b eof=%b fid=%0d",
                       beats, beat_data, beat_sof, beat_eof, beat_frame_id);
            beats = beats + 1;
            if (beats == 4) begin
                if (frame_error) $fatal(1, "unexpected frame error");
                $display("PASS tb_patpack: 2 continuous frames, 4 ordered beats");
                $finish;
            end
        end
    end

    initial begin
        #2000;
        $fatal(1, "pattern-to-packer timeout; beats=%0d", beats);
    end
endmodule
