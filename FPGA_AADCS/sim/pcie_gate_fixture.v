// Standalone synthesis boundary preserves the functional reset/source ports.
// Small counters shorten gate simulation; production defaults remain 18 bits.
module pcie_gate_fixture(
    input free_clk, key0_n, key1_n, dma_clk, core_rst_n, read_enable,
    output power_up_rst_n, dma_reset_n, ramp_mode,
    output [127:0] read_data
);
    pcie_reset_control #(.POR_BITS(4),.DEBOUNCE_BITS(3)) reset_control(
        .free_clk(free_clk),.key0_n(key0_n),.key1_n(key1_n),
        .dma_clk(dma_clk),.core_rst_n(core_rst_n),
        .power_up_rst_n(power_up_rst_n),.dma_reset_n(dma_reset_n),.ramp_mode(ramp_mode)
    );
    pcie_test_source source(.clk(dma_clk),.rst_n(dma_reset_n),
        .ramp_mode(ramp_mode),.read_enable(read_enable),.read_data(read_data));
endmodule
