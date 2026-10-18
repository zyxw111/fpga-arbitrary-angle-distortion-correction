`timescale 1ns/1ps

module tb_afifo;
    reg wr_clk = 0, rd_clk = 0;
    always #3.5 wr_clk = ~wr_clk;
    always #5.5 rd_clk = ~rd_clk;
    reg rst_n = 0;
    reg wr_valid = 0;
    wire wr_ready;
    reg [31:0] wr_data = 0;
    wire rd_valid;
    reg rd_ready = 0;
    wire [31:0] rd_data;
    integer sent = 0, received = 0, rd_cycles = 0;

    afifo #(.WIDTH(32), .ADDR_BITS(3)) dut (
        .wr_clk(wr_clk), .rd_clk(rd_clk), .rst_n(rst_n),
        .wr_valid(wr_valid), .wr_ready(wr_ready), .wr_data(wr_data),
        .rd_valid(rd_valid), .rd_ready(rd_ready), .rd_data(rd_data)
    );

    always @(negedge wr_clk) begin
        wr_valid = rst_n && (sent < 64);
        wr_data = 32'h90000000 + sent;
    end
    always @(posedge wr_clk) if (rst_n && wr_valid && wr_ready)
        sent <= sent + 1;

    always @(negedge rd_clk) begin
        rd_ready = rst_n && (rd_cycles > 25) && (rd_cycles % 5 != 0);
        rd_cycles = rd_cycles + 1;
    end
    always @(posedge rd_clk) if (rst_n && rd_valid && rd_ready) begin
        if (rd_data !== 32'h90000000 + received)
            $fatal(1, "async FIFO #%0d got %h", received, rd_data);
        received <= received + 1;
    end

    initial begin
        #30; rst_n = 1;
        wait (received == 64);
        #20;
        if (sent != 64) $fatal(1, "FIFO sent=%0d", sent);
        $display("PASS tb_afifo: 64 ordered words across unequal clocks and stalls");
        $finish;
    end
    initial begin
        #20000;
        $fatal(1, "FIFO timeout sent=%0d received=%0d", sent, received);
    end
endmodule
