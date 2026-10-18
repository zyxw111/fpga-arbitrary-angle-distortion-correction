`timescale 1ns/1ps

module tb_split;
    reg clk = 0;
    reg rst_n = 0;
    reg start = 0;
    reg [63:0] base_addr = 0;
    reg [31:0] total_bytes = 0;
    reg cmd_ready = 0;
    wire start_ready, cmd_valid, cmd_last, done, error;
    wire [63:0] cmd_addr;
    wire [12:0] cmd_bytes;
    wire [9:0] cmd_len_dw_m1;

    always #4 clk = ~clk;

    split dut (
        .clk(clk), .rst_n(rst_n), .start(start), .start_ready(start_ready),
        .base_addr(base_addr), .total_bytes(total_bytes),
        .cmd_valid(cmd_valid), .cmd_ready(cmd_ready), .cmd_addr(cmd_addr),
        .cmd_bytes(cmd_bytes), .cmd_len_dw_m1(cmd_len_dw_m1),
        .cmd_last(cmd_last), .done(done), .error(error)
    );

    task run_case;
        input [63:0] address;
        input [31:0] size;
        input integer expected_commands;
        reg [63:0] expected_addr;
        reg [31:0] left;
        reg [12:0] boundary;
        reg [12:0] expected_bytes;
        integer commands;
        integer cycles;
        begin
            @(negedge clk);
            if (!start_ready) $fatal(1, "planner not idle");
            base_addr = address;
            total_bytes = size;
            start = 1;
            @(negedge clk);
            start = 0;
            expected_addr = address;
            left = size;
            commands = 0;
            cycles = 0;
            while (left != 0) begin
                cycles = cycles + 1;
                if (cycles > 5000) $fatal(1, "planner timeout");
                cmd_ready = (cycles % 4 != 0);
                @(posedge clk);
                if (cmd_valid) begin
                    boundary = 13'd4096 - {1'b0, expected_addr[11:0]};
                    expected_bytes = (left > boundary) ? boundary : left[12:0];
                    if (cmd_addr !== expected_addr || cmd_bytes !== expected_bytes)
                        $fatal(1, "address/length mismatch cmd %0d", commands);
                    if (cmd_bytes == 0 || cmd_bytes > 4096 ||
                        (cmd_addr[11:0] + cmd_bytes > 4096))
                        $fatal(1, "4 KiB boundary violation");
                    if (cmd_len_dw_m1 !== (cmd_bytes / 4 - 1))
                        $fatal(1, "DWORD command encoding mismatch");
                    if (cmd_last !== (left == expected_bytes))
                        $fatal(1, "last flag mismatch");
                    if (cmd_ready) begin
                        expected_addr = expected_addr + expected_bytes;
                        left = left - expected_bytes;
                        commands = commands + 1;
                    end
                end
                #1;
                if (left == 0 && !done) $fatal(1, "missing completion pulse");
                @(negedge clk);
            end
            cmd_ready = 0;
            if (commands != expected_commands)
                $fatal(1, "expected %0d commands, got %0d", expected_commands, commands);
            if (!start_ready || error) $fatal(1, "bad final state");
        end
    endtask

    task invalid_case;
        input [63:0] address;
        input [31:0] size;
        begin
            @(negedge clk);
            base_addr = address;
            total_bytes = size;
            start = 1;
            @(posedge clk);
            #1;
            if (!error || cmd_valid || !start_ready)
                $fatal(1, "invalid request accepted");
            @(negedge clk);
            start = 0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        run_case(64'h0000_0001_2340_0000, 32'd4147200, 1013);
        run_case(64'h0000_0001_2340_0ff0, 32'd4096, 2);
        run_case(64'h0000_0000_0000_0010, 32'd16, 1);
        invalid_case(64'h1003, 32'd16);
        invalid_case(64'h1000, 32'd17);
        invalid_case(64'h1000, 32'd0);
        invalid_case(64'hffff_ffff_ffff_f000, 32'd8192);
        $display("tb_split PASS");
        $finish;
    end
endmodule
