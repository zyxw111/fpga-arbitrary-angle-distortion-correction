`timescale 1ns/1ps

module tb_sccb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg start = 0;
    reg [15:0] reg_addr = 0;
    reg force_nack = 0;
    wire scl_low, sda_low, busy, done, nack;
    wire [7:0] data_out;
    wire sda_in;
    reg [7:0] reply;
    integer completions = 0;
    integer starts = 0;

    sccb #(.HALF_CYCLES(2)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .reg_addr(reg_addr),
        .sda_in(sda_in), .scl_pull_low(scl_low),
        .sda_pull_low(sda_low), .busy(busy), .done(done),
        .nack(nack), .data_out(data_out)
    );

    // Mock OV5640: ACK writes and return chip-ID bytes. The pull-low
    // controls also verify that the master never drives a logic high.
    always @* begin
        case (reg_addr)
            16'h300a: reply = 8'h56;
            16'h300b: reply = 8'h40;
            default:  reply = 8'h00;
        endcase
    end
    assign sda_in = sda_low ? 1'b0 :
                    ((dut.state == 5'd6 || dut.state == 5'd7 ||
                      dut.state == 5'd8) ? force_nack :
                     ((dut.state == 5'd13 || dut.state == 5'd14 ||
                       dut.state == 5'd15) ? reply[dut.bit_index] : 1'b1));

    always @(posedge clk) begin
        if (rst_n && dut.state == 5'd1 && dut.divider == 0)
            starts <= starts + 1;
        if (done)
            completions <= completions + 1;
    end

    task read_reg(input [15:0] addr, input [7:0] expected,
                  input expected_nack);
        integer timeout;
        begin
            @(negedge clk);
            reg_addr = addr;
            start = 1;
            @(negedge clk);
            start = 0;
            timeout = 0;
            while (!done && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!done) $fatal(1, "SCCB timeout at %h", addr);
            if (data_out !== expected || nack !== expected_nack)
                $fatal(1, "SCCB %h: data=%h nack=%b", addr, data_out, nack);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1;
        read_reg(16'h300a, 8'h56, 1'b0);
        read_reg(16'h300b, 8'h40, 1'b0);
        force_nack = 1;
        read_reg(16'h300a, 8'h56, 1'b1);
        if (starts != 3) $fatal(1, "Expected 3 starts, got %0d", starts);
        $display("PASS tb_sccb: ID high/low and NACK detection");
        $finish;
    end
endmodule
