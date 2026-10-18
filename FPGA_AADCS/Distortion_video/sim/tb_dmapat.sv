`timescale 1ns/1ps

module tb_dmapat;
    reg clk = 0;
    reg rst_n = 0;
    reg rd_en = 0;
    reg [11:0] rd_addr = 0;
    wire [127:0] rd_data;

    always #4 clk = ~clk;

    dmapat dut (
        .clk(clk), .rst_n(rst_n), .rd_en(rd_en),
        .rd_addr(rd_addr), .rd_data(rd_data)
    );

    function [127:0] expected;
        input [11:0] address;
        reg [31:0] word_addr;
        begin
            word_addr = {20'd0, address};
            expected = {
                32'hD4A5_0000 ^ word_addr,
                32'hB3C6_0000 ^ word_addr,
                32'hE2F7_0000 ^ word_addr,
                32'hA1B8_0000 ^ word_addr
            };
        end
    endfunction

    task read_check;
        input [11:0] address;
        begin
            @(negedge clk);
            rd_en = 1;
            rd_addr = address;
            @(posedge clk);
            #1;
            if (rd_data !== expected(address))
                $fatal(1, "DMA pattern mismatch at %h: %h", address, rd_data);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        read_check(12'h000);
        read_check(12'h001);
        read_check(12'h0ff);
        read_check(12'hfff);
        @(negedge clk);
        rd_en = 0;
        rd_addr = 12'h123;
        @(posedge clk);
        #1;
        if (rd_data !== expected(12'hfff))
            $fatal(1, "DMA data changed without read enable");
        $display("tb_dmapat PASS");
        $finish;
    end
endmodule
