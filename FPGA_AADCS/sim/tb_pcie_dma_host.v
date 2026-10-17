`timescale 1ns/1ps
// Host MMIO -> actual RX/controller/TX -> addressed, sentinel-filled host RAM.
// Only PCIe hard IP/PHY and unused BAR RAM are outside this RTL test boundary.
module tb_pcie_dma_host;
    reg clk=0;
    always #4 clk=~clk;
    reg rst_n=0, ramp_mode=1;
    reg rx_valid=0, rx_last=0;
    reg [127:0] rx_data=0;
    reg [3:0] rx_keep=0;
    reg [7:0] rx_user=0;
    wire rx_ready, tx_valid, tx_last, source_read, cross_page;
    wire [127:0] tx_data, source_data;
    reg ready=1;
    integer cycle=0, received=0, packets=0, packet_left=0;
    integer cursor=0, expected_total=0, line_index, page_words, j, k;
    integer desc_count=0, command_writes=0;
    reg [63:0] base=64'h7e8c8000, address=64'h7e8c8000, packet_addr;
    reg [31:0] memory [0:255999];
    reg [255999:0] covered=0;
    reg in_packet=0, stalls=1;

    ips2l_pcie_dma #(.ADDR_WIDTH(9)) dma(
        .clk(clk),.rst_n(rst_n),.i_cfg_pbus_num(8'h21),.i_cfg_pbus_dev_num(5'd0),
        .i_cfg_max_rd_req_size(3'd0),.i_cfg_max_payload_size(3'd0),
        .i_axis_master_tvld(rx_valid),.o_axis_master_trdy(rx_ready),
        .i_axis_master_tdata(rx_data),.i_axis_master_tkeep(rx_keep),
        .i_axis_master_tlast(rx_last),.i_axis_master_tuser(rx_user),
        .i_axis_slave0_trdy(1'b1),.i_axis_slave1_trdy(1'b1),
        .i_axis_slave2_trdy(ready),.o_axis_slave2_tvld(tx_valid),
        .o_axis_slave2_tdata(tx_data),.o_axis_slave2_tlast(tx_last),
        .i_cfg_ido_req_en(1'b0),.i_cfg_ido_cpl_en(1'b0),
        .i_xadm_ph_cdts(8'd0),.i_xadm_pd_cdts(12'd0),
        .i_xadm_nph_cdts(8'd0),.i_xadm_npd_cdts(12'd0),
        .i_xadm_cplh_cdts(8'd0),.i_xadm_cpld_cdts(12'd0),
        .i_apb_psel(1'b0),.i_apb_paddr(9'd0),.i_apb_pwdata(32'd0),
        .i_apb_pstrb(4'd0),.i_apb_pwrite(1'b0),.i_apb_penable(1'b0),
        .o_cross_4kb_boundary(cross_page),
        .o_dma_write_data_req(source_read),.i_dma_write_data(source_data)
    );
    pcie_test_source source(.clk(clk),.rst_n(rst_n),.ramp_mode(ramp_mode),
        .read_enable(source_read),.read_data(source_data));

    function [31:0] reverse_bytes;
        input [31:0] value;
        reverse_bytes={value[7:0],value[15:8],value[23:16],value[31:24]};
    endfunction
    function [15:0] color;
        input integer x,y;
        begin
            if(y>=300) color={x[4:0],x[5:0],x[4:0]};
            else case(x/80)
                0:color=16'hffff;1:color=16'hffe0;2:color=16'h07ff;
                3:color=16'h07e0;4:color=16'hf81f;5:color=16'hf800;
                6:color=16'h001f;default:color=16'h0000;
            endcase
        end
    endfunction
    function [31:0] expected_word;
        input integer index;
        integer w,x,y;
        reg [15:0] lo,hi;
        begin
            w=index%128000;
            if(ramp_mode) expected_word=index;
            else case(w)
                0:expected_word=32'hd5000001;1:expected_word=32'ha55a0000;
                2:expected_word=32'h5a000000;3:expected_word=32'h3568cafe;
                default:begin
                    x=(w*2)%640;y=(w*2)/640;lo=color(x,y);hi=color(x+1,y);
                    expected_word={hi[7:0],hi[15:8],lo[7:0],lo[15:8]};
                end
            endcase
        end
    endfunction
    always @(negedge clk) begin
        cycle=cycle+1;
        ready=!(stalls && ((cycle%500<170)||(cycle%7==0)));
    end
    // One register write per received TLP, even if the RX payload beat stalls.
    always @(posedge clk) if(rst_n && dma.bar1_wr_en && dma.bar1_wr_addr==9'h100)
        command_writes=command_writes+1;
    always @(posedge clk) if(rst_n && tx_valid && ready) begin
        if(!in_packet) begin
            if(tx_data[31:24]!==8'h40 && tx_data[31:24]!==8'h60)
                $fatal(1,"bad MWr header %h",tx_data);
            packet_left=tx_data[9:0];
            if(packet_left==0) packet_left=1024;
            if(packet_left>32) $fatal(1,"MPS exceeded");
            packet_addr=tx_data[31:24]==8'h60 ?
                {tx_data[95:64],tx_data[127:96]} : {32'd0,tx_data[95:64]};
            if(packet_addr<base || packet_addr+packet_left*4>base+1024000)
                $fatal(1,"address outside host buffer %h",packet_addr);
            cursor=(packet_addr-base)/4;
            packets=packets+1;in_packet=1;
        end else begin
            for(j=0;j<4 && packet_left>0;j=j+1) begin
                if(covered[cursor]) $fatal(1,"duplicate host word %0d",cursor);
                memory[cursor]=reverse_bytes(tx_data[j*32+:32]);
                if(memory[cursor]!==expected_word(cursor))
                    $fatal(1,"host word %0d got %h expected %h",cursor,memory[cursor],expected_word(cursor));
                covered[cursor]=1;cursor=cursor+1;
                received=received+1;packet_left=packet_left-1;
            end
            if(tx_last) begin
                if(packet_left!=0) $fatal(1,"early tlast");
                in_packet=0;
            end
        end
    end
    task mmio;
        input [31:0] offset,value;
        begin
            @(negedge clk);rx_valid=1;rx_last=0;rx_keep=4'hf;rx_user=8'h10;
            rx_data={32'd0,offset,32'h0000000f,32'h40000001};
            @(negedge clk);rx_valid=0;
            repeat(desc_count%4) @(negedge clk);
            @(negedge clk);rx_valid=1;rx_last=1;rx_keep=1;rx_data={96'd0,reverse_bytes(value)};
            @(negedge clk);rx_valid=0;rx_last=0;rx_keep=0;
            repeat(10) @(negedge clk);
        end
    endtask
    task descriptor;
        input integer words;
        integer timeout_cycles;
        begin
            mmio('h110,address[31:0]);
            mmio('h120,address[63:32]);
            mmio('h100,32'h01000000|((words-1)&1023)|
                 (address[63:32]!=0 ? 32'h00010000 : 0));
            desc_count=desc_count+1;expected_total=expected_total+words;
            timeout_cycles=0;
            while(received<expected_total && timeout_cycles<20000) begin
                @(negedge clk);timeout_cycles=timeout_cycles+1;
            end
            repeat(40) @(negedge clk);
            if(received!=expected_total || cross_page)
                $fatal(1,"descriptor %0d got %0d expected %0d cross=%b",desc_count,received,expected_total,cross_page);
            if(command_writes!=desc_count)
                $fatal(1,"MMIO commands repeated: %0d writes / %0d descriptors",command_writes,desc_count);
            address=address+words*4;
        end
    endtask
    task restart;
        begin
            rst_n=0;repeat(5) @(negedge clk);
            received=0;packets=0;in_packet=0;expected_total=0;
            desc_count=0;command_writes=0;covered=0;address=base;
            for(k=0;k<256000;k=k+1) memory[k]=32'haaaaaaaa;
            rst_n=1;repeat(5) @(negedge clk);
        end
    endtask
    initial begin
        restart;
        // Reproduce the report's eight 1280-byte requests, with page splits.
        for(line_index=0;line_index<8;line_index=line_index+1) begin
            page_words=(4096-(address&4095))/4;
            if(page_words<320) begin descriptor(page_words);descriptor(320-page_words);end
            else descriptor(320);
        end
        descriptor(512); // finish the current page
        descriptor(1024); // encoded length zero = 4096 bytes
        $display("PASS host ramp: %0d words, complete coverage, %0d MMIO commands",received,desc_count);
        base=64'h000000017e8c8000;ramp_mode=0;restart;
        for(line_index=0;line_index<800;line_index=line_index+1) begin
            page_words=(4096-(address&4095))/4;
            if(page_words<320) begin descriptor(page_words);descriptor(320-page_words);end
            else descriptor(320);
        end
        for(k=0;k<256000;k=k+1)
            if(!covered[k]) $fatal(1,"untouched host sentinel at %0d",k);
        $display("PASS host color: 2 frames, 64-bit addresses, no holes/duplicates, %0d descriptors, %0d TLPs",desc_count,packets);
        $finish;
    end
    initial begin #10000000;$fatal(1,"host timeout");end
endmodule
