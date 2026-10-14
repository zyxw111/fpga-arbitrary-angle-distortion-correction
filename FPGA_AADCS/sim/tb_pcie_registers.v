`timescale 1ns/1ps
module tb_pcie_registers;
    reg clk=0;
    always #4 clk=~clk;
    reg rst_n=0, wr_en=0, ack32=0, ack64=0;
    reg [11:0] wr_addr=0;
    reg [127:0] wr_data=0;
    reg [15:0] wr_be=16'hffff;
    wire req32,req64,cross_page;
    wire [9:0] length;
    wire [63:0] host_address;
    ips2l_pcie_dma_controller #(.ADDR_WIDTH(12)) dut(
        .clk(clk),.rst_n(rst_n),.i_bar1_wr_en(wr_en),.i_bar1_wr_addr(wr_addr),
        .i_bar1_wr_data(wr_data),.i_bar1_wr_byte_en(wr_be),
        .i_apb_psel(1'b0),.i_apb_paddr(9'd0),.i_apb_pwdata(32'd0),
        .i_apb_pstrb(4'd0),.i_apb_pwrite(1'b0),.i_apb_penable(1'b0),
        .o_apb_prdy(),.o_apb_prdata(),.o_user_define_data_flag(),
        .o_mwr32_req(req32),.i_mwr32_req_ack(ack32),
        .o_mwr64_req(req64),.i_mwr64_req_ack(ack64),
        .o_mrd32_req(),.i_mrd32_req_ack(1'b0),
        .o_mrd64_req(),.i_mrd64_req_ack(1'b0),
        .o_req_length(length),.o_req_addr(host_address),.o_req_data(),
        .i_dma_check_result(64'd0),.o_tx_restart(),.o_cross_4kb_boundary(cross_page)
    );
    task write_register;
        input [11:0] address;
        input [31:0] data;
        begin
            @(negedge clk);wr_addr=address;wr_data={96'd0,data};wr_en=1;
            @(negedge clk);wr_en=0;
            repeat(6) @(negedge clk);
        end
    endtask
    task reset;
        begin rst_n=0;repeat(3) @(negedge clk);rst_n=1;end
    endtask
    initial begin
        reset;
        write_register(12'h120,32'h12345678);
        if(dut.dma_cmd_h_addr_vld!==0) $fatal(1,"high address strobe stuck");
        write_register(12'h110,32'h10000000);
        write_register(12'h100,32'h0101001f);
        if(!req64 || req32 || host_address!==64'h1234567810000000 || length!==32)
            $fatal(1,"64-bit address/length mismatch");
        ack64=1;repeat(2) @(negedge clk);ack64=0;
        repeat(4) @(negedge clk);
        reset;
        write_register(12'h110,32'h10000000);
        write_register(12'h100,32'h010003ff);
        if(!req32 || length!==0 || cross_page) $fatal(1,"4096-byte descriptor encoding");
        reset;
        write_register(12'h110,32'h10000ff0);
        write_register(12'h100,32'h0100000f);
        if(req32 || !cross_page) $fatal(1,"cross-page request was not rejected");
        reset;
        wr_be=16'h00ff;
        write_register(12'h110,32'h10000000);
        write_register(12'h100,32'h0100001f);
        if(req32 || req64) $fatal(1,"partial register write was accepted");
        $display("PASS registers: 32/64-bit addresses, high-address pulse, 4KiB encoding, crossing rejection and byte enables");
        $finish;
    end
    initial begin #100000;$fatal(1,"register timeout");end
endmodule
