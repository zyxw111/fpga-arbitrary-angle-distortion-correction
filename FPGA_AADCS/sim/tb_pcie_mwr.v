`timescale 1ns/1ps
// Exercises the actual vendor MWr packetizer and read FIFO with the new source.
// Checks received payload, packet sizes, repeated descriptors and TX stalls.
module tb_pcie_mwr;
    reg clk=0;
    always #4 clk=~clk;
    reg rst_n=0;
    reg ramp_mode=1;
    reg req=0;
    reg [9:0] length=0;
    reg [63:0] address=64'h10000000;
    wire ack, rd_en, busy, hold_tx, tlp_tx, start, last_data, source_read;
    wire [9:0] rd_length;
    wire [127:0] payload, source_data, tx_data;
    wire tx_valid, tx_last;
    reg ready=1;
    wire [11:0] source_address;
    integer cycle=0, received=0, packets=0, packet_words=0;
    integer expected_total=0, j;
    integer line_index, page_words;
    reg in_packet=0;
    reg [31:0] word_data;
    reg stalls=0;

    ips2l_pcie_dma_mwr_tx_ctrl tx(
        .clk(clk),.rst_n(rst_n),.i_cfg_pbus_num(8'h21),
        .i_cfg_pbus_dev_num(5'd0),.i_cfg_max_payload_size(3'd0),
        .i_user_define_data_flag(1'b0),.i_mwr32_req(req),.o_mwr32_req_ack(ack),
        .i_mwr64_req(1'b0),.o_mwr64_req_ack(),
        .i_req_length(length),.i_req_addr(address),.i_req_data(32'd0),
        .o_rd_en(rd_en),.o_rd_length(rd_length),.i_gen_tlp_start(start),
        .i_rd_data(payload),.i_last_data(last_data),.i_axis_slave2_trdy(ready),
        .o_axis_slave2_tvld(tx_valid),.o_axis_slave2_tdata(tx_data),
        .o_axis_slave2_tlast(tx_last),.o_axis_slave2_tuser(),
        .o_mwr_tx_busy(busy),.o_mwr_tx_hold(hold_tx),.o_mwr_tlp_tx(tlp_tx),
        .i_tx_restart(1'b0)
    );
    ips2l_pcie_dma_tx_mwr_rd_ctrl #(.ADDR_WIDTH(12)) reader(
        .clk(clk),.rst_n(rst_n),.i_rd_en(rd_en),.i_rd_length(rd_length),
        .i_mwr_tx_busy(busy),.i_mwr_tx_hold(hold_tx),.i_mwr_tlp_tx(tlp_tx),
        .o_gen_tlp_start(start),.o_rd_data(payload),.o_last_data(last_data),
        .o_bar_rd_clk_en(source_read),.o_bar_rd_addr(source_address),
        .i_bar_rd_data(source_data)
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

    function [31:0] expected_color_word;
        input integer index;
        integer within_frame,x,y;
        reg [15:0] lo,hi;
        begin
            within_frame=index%128000;
            case(within_frame)
                0:expected_color_word=32'hd5000001;
                1:expected_color_word=32'ha55a0000;
                2:expected_color_word=32'h5a000000;
                3:expected_color_word=32'h3568cafe;
                default:begin
                    x=(within_frame*2)%640;y=(within_frame*2)/640;
                    lo=color(x,y);hi=color(x+1,y);
                    expected_color_word={hi[7:0],hi[15:8],lo[7:0],lo[15:8]};
                end
            endcase
        end
    endfunction

    always @(negedge clk) begin
        cycle=cycle+1;
        // Long pause fills the prefetch FIFO; short pauses test AXIS holding.
        ready=!(stalls && ((cycle%500 < 170) || (cycle%7 == 0)));
    end
    always @(posedge clk) if (rst_n && tx_valid && ready) begin
        if (!in_packet) begin
            if (tx_data[31:24] !== 8'h40) $fatal(1,"not a MWr32 header: %h",tx_data);
            packet_words=tx_data[9:0];
            if (packet_words <= 0 || packet_words > 32)
                $fatal(1,"bad TLP length %0d",packet_words);
            in_packet=1;
            packets=packets+1;
        end else begin
            for(j=0;j<4 && packet_words>0;j=j+1) begin
                word_data=reverse_bytes(tx_data[j*32+:32]);
                if(ramp_mode && word_data !== received)
                    $fatal(1,"payload word %0d: got %h",received,word_data);
                if(!ramp_mode && word_data !== expected_color_word(received))
                    $fatal(1,"color word %0d: got %h expected %h",received,word_data,expected_color_word(received));
                received=received+1;
                packet_words=packet_words-1;
            end
            if(tx_last) begin
                if(packet_words != 0) $fatal(1,"early tlast");
                in_packet=0;
            end
        end
    end

    task descriptor;
        input integer words;
        begin
            @(negedge clk);length=words;req=1;
            wait(ack);@(posedge clk);@(negedge clk);req=0;
            wait(!busy);repeat(12) @(negedge clk);
            expected_total=expected_total+words;
            if(received != expected_total)
                $fatal(1,"descriptor count got %0d expected %0d",received,expected_total);
            address=address+words*4;
        end
    endtask
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        descriptor(32);
        descriptor(320);
        stalls=1;
        descriptor(512);
        descriptor(320);
        descriptor(1024);
        $display("PASS MWr payload: %0d words, %0d packets, repeated descriptors and backpressure",received,packets);
        rst_n=0;repeat(5) @(negedge clk);
        received=0;packets=0;in_packet=0;expected_total=0;address=64'h10000000;
        ramp_mode=0;rst_n=1;
        // Exactly the host viewer's 1280-byte rows; includes descriptor cuts
        // at 4 KiB boundaries without resetting the virtual frame cursor.
        for(line_index=0;line_index<800;line_index=line_index+1) begin
            if((address & 64'hfff)>2816) begin
                page_words=(4096-(address & 64'hfff))/4;
                descriptor(page_words);
                descriptor(320-page_words);
            end else descriptor(320);
        end
        if(received!=256000) $fatal(1,"full frame count %0d",received);
        $display("PASS color MWr: two complete frames, RGB565/header data, page-boundary splits and TX stalls");
        $finish;
    end
    initial begin #5000000;$fatal(1,"timeout");end
endmodule
