`timescale 1ns/1ps
module tb_pcie_reset;
    reg free_clk=0, dma_clk=0, dma_clock_enable=0;
    always #20 free_clk=~free_clk;
    always #4 if(dma_clock_enable) dma_clk=~dma_clk;
    // No external reset edge at power-on; core_rst_n starts high on purpose.
    reg key0_n=1, key1_n=1, core_rst_n=1;
    wire power_up_rst_n, dma_reset_n, ramp_mode;
    wire [127:0] read_data;
    reg read_enable=0;
`ifdef GATE_SIM
    GTP_GRS GRS_INST(.GRS_N(1'b1));
    pcie_gate_fixture dut(.*);
`else
    pcie_reset_control #(.POR_BITS(4),.DEBOUNCE_BITS(3)) dut(.*);
    pcie_test_source source(.clk(dma_clk),.rst_n(dma_reset_n),
        .ramp_mode(ramp_mode),.read_enable(read_enable),.read_data(read_data));
`endif
    integer resets=0;
    always @(negedge dma_reset_n) resets=resets+1;
    task first_word;
        input [127:0] expected;
        begin
            wait(dma_reset_n);@(negedge dma_clk);read_enable=1;
            @(negedge dma_clk);read_enable=0;
            if(read_data!==expected) $fatal(1,"restart data %h expected %h",read_data,expected);
        end
    endtask
    initial begin
        #1;if(power_up_rst_n!==0) $fatal(1,"missing autonomous POR");
        #500;if(power_up_rst_n!==0) $fatal(1,"POR too short");
        wait(power_up_rst_n);
        if(dma_reset_n===1) $fatal(1,"DMA released without clock");
        dma_clock_enable=1;
        first_word(128'h3568cafe5a000000a55a0000d5000001);
        // Bounce shorter than the debounce window must not restart the stream.
        @(negedge dma_clk);key1_n=0;repeat(3) @(negedge dma_clk);key1_n=1;
        repeat(15) @(negedge dma_clk);
        if(ramp_mode!==0 || !dma_reset_n) $fatal(1,"key bounce changed mode");
        key1_n=0;wait(ramp_mode);wait(!dma_reset_n);
        first_word(128'h00000003000000020000000100000000);
        key1_n=1;wait(!ramp_mode);wait(!dma_reset_n);
        first_word(128'h3568cafe5a000000a55a0000d5000001);
        // Reset asserts without a PCIe clock and waits for independent POR.
        @(negedge dma_clk);dma_clock_enable=0;key0_n=0;
        #1;if(dma_reset_n!==0 || power_up_rst_n!==0) $fatal(1,"KEY0 assertion");
        #80;key0_n=1;#500;
        if(power_up_rst_n!==0) $fatal(1,"KEY0 did not restart POR");
        wait(power_up_rst_n);dma_clock_enable=1;
        first_word(128'h3568cafe5a000000a55a0000d5000001);
        @(negedge dma_clk);core_rst_n=0;#1;
        if(dma_reset_n!==0) $fatal(1,"core reset assertion");
        core_rst_n=1;
        first_word(128'h3568cafe5a000000a55a0000d5000001);
        $display("PASS reset: no external startup pulse, stopped PCIe clock, KEY0, key bounce, mode/core restarts");
        $finish;
    end
    initial begin #100000;$fatal(1,"reset timeout");end
endmodule
