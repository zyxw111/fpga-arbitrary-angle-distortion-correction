`timescale 1ns/1ps

module tb_dvp;
    reg pclk = 1'b0;
    always #5 pclk = ~pclk;

    reg rst_n = 1'b0;
    reg vsync = 1'b0;
    reg href = 1'b0;
    reg [7:0] data = 8'd0;
    wire valid;
    wire [15:0] pixel;
    wire [11:0] x, y;
    wire sof, sol;
    integer seen = 0;
    reg [15:0] expected;

    dvp #(.WIDTH(4), .HEIGHT(2)) dut (
        .pclk(pclk), .rst_n(rst_n), .vsync(vsync), .href(href),
        .data(data), .valid(valid), .pixel(pixel), .x(x), .y(y),
        .sof(sof), .sol(sol)
    );

    task send_byte(input [7:0] value);
        begin
            @(negedge pclk);
            href = 1'b1;
            data = value;
        end
    endtask

    task send_line(input integer line_no);
        integer col;
        reg [15:0] value;
        begin
            for (col = 0; col < 4; col = col + 1) begin
                value = 16'h1000 + line_no*4 + col;
                send_byte(value[15:8]);
                send_byte(value[7:0]);
            end
            if (line_no == 0)
                send_byte(8'haa); // Odd byte must be discarded at HREF fall.
            @(negedge pclk);
            href = 1'b0;
            data = 8'd0;
            repeat (2) @(negedge pclk);
        end
    endtask

    always @(posedge pclk) begin
        #1;
        if (valid) begin
            expected = 16'h1000 + seen;
            if (seen >= 8 || pixel !== expected ||
                x !== (seen % 4) || y !== (seen / 4) ||
                sof !== (seen == 0) || sol !== ((seen % 4) == 0)) begin
                $display("FAIL seen=%0d pixel=%h x=%0d y=%0d sof=%b sol=%b", seen, pixel, x, y, sof, sol);
                $fatal(1);
            end
            seen = seen + 1;
        end
    end

    initial begin
        repeat (3) @(negedge pclk);
        rst_n = 1'b1;
        vsync = 1'b1;
        repeat (2) @(negedge pclk);
        vsync = 1'b0;
        repeat (2) @(negedge pclk);
        send_line(0);
        send_line(1);
        repeat (3) @(negedge pclk);
        if (seen != 8)
            $fatal(1, "FAIL expected 8 pixels, got %0d", seen);
        $display("PASS tb_dvp: 8 pixels, SOF/SOL and odd-byte recovery");
        $finish;
    end
endmodule
