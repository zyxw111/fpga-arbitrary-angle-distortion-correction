// Split a contiguous host DMA buffer into 4 KiB-safe, DWORD-sized commands.
// This is only a command planner; it does not launch PCIe TLPs or move data.
module split (
    input             clk,
    input             rst_n,
    input             start,
    output            start_ready,
    input      [63:0] base_addr,
    input      [31:0] total_bytes,
    output            cmd_valid,
    input             cmd_ready,
    output     [63:0] cmd_addr,
    output     [12:0] cmd_bytes,
    output     [9:0]  cmd_len_dw_m1,
    output            cmd_last,
    output reg        done,
    output reg        error
);
    reg active;
    reg [63:0] cursor;
    reg [31:0] remain;

    wire [12:0] boundary_bytes = 13'd4096 - {1'b0, cursor[11:0]};
    wire [12:0] next_bytes =
        (remain > {19'd0, boundary_bytes}) ? boundary_bytes : remain[12:0];
    wire [64:0] end_addr = {1'b0, base_addr} + {33'd0, total_bytes} - 65'd1;
    wire request_ok = (base_addr[3:0] == 4'd0) &&
                      (total_bytes[3:0] == 4'd0) &&
                      (total_bytes != 32'd0) && !end_addr[64];

    assign start_ready = !active;
    assign cmd_valid = active;
    assign cmd_addr = cursor;
    assign cmd_bytes = next_bytes;
    assign cmd_len_dw_m1 = (next_bytes[12:2] - 11'd1);
    assign cmd_last = active && (remain == {19'd0, next_bytes});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active <= 1'b0;
            cursor <= 64'd0;
            remain <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
        end else begin
            done <= 1'b0;
            error <= 1'b0;
            if (start && !active) begin
                if (request_ok) begin
                    cursor <= base_addr;
                    remain <= total_bytes;
                    active <= 1'b1;
                end else begin
                    error <= 1'b1;
                end
            end else if (active && cmd_ready) begin
                if (cmd_last) begin
                    active <= 1'b0;
                    remain <= 32'd0;
                    done <= 1'b1;
                end else begin
                    cursor <= cursor + {51'd0, next_bytes};
                    remain <= remain - {19'd0, next_bytes};
                end
            end
        end
    end
endmodule
