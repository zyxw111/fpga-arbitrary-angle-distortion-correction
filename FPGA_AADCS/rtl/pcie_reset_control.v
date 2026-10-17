// Configuration-time initialization is synthesized into FPGA FF INIT bits.
// The board's V4 oscillator runs even while the PCIe PHY clocks are stopped.
module pcie_reset_control #(
    parameter integer POR_BITS = 18,
    parameter integer DEBOUNCE_BITS = 18
)(
    input wire free_clk,
    input wire key0_n,
    input wire key1_n,
    input wire dma_clk,
    input wire core_rst_n,
    output reg power_up_rst_n = 1'b0,
    output wire dma_reset_n,
    output reg ramp_mode = 1'b0
);
    reg [POR_BITS-1:0] por_count = 0;
    always @(posedge free_clk or negedge key0_n) begin
        if (!key0_n) begin
            por_count <= 0;
            power_up_rst_n <= 0;
        end else if (!power_up_rst_n) begin
            por_count <= por_count + 1'b1;
            if (&por_count) power_up_rst_n <= 1;
        end
    end

    wire reset_async_n = power_up_rst_n && core_rst_n && key0_n;
    reg [2:0] reset_pipe = 0;
    always @(posedge dma_clk or negedge reset_async_n) begin
        if (!reset_async_n) reset_pipe <= 0;
        else reset_pipe <= {reset_pipe[1:0], 1'b1};
    end

    reg [1:0] key_pipe = 2'b11;
    reg [DEBOUNCE_BITS-1:0] key_count = 0;
    reg stream_run = 1'b0;
    // Both DMA FIFOs and source are restarted together on a stable mode change.
    // stream_run is a FF, never a combinational comparison used as async reset.
    always @(posedge dma_clk or negedge reset_pipe[2]) begin
        if (!reset_pipe[2]) begin
            key_pipe <= 2'b11;
            key_count <= 0;
            ramp_mode <= 0;
            stream_run <= 0;
        end else begin
            key_pipe <= {key_pipe[0], key1_n};
            stream_run <= 1;
            if ((~key_pipe[1]) == ramp_mode) key_count <= 0;
            else if (&key_count) begin
                key_count <= 0;
                ramp_mode <= ~key_pipe[1];
                stream_run <= 0;
            end else key_count <= key_count + 1'b1;
        end
    end
    assign dma_reset_n = stream_run;
endmodule
