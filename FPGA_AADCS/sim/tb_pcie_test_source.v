`timescale 1ns/1ps
module tb_pcie_test_source;
`ifdef GATE_SIM
    GTP_GRS GRS_INST(.GRS_N(1'b1));
`endif
    reg clk=0;
    always #4 clk=~clk;
    reg rst_n=0, read_enable=0, ramp_mode=0;
    wire [127:0] data;
    reg [127:0] previous;
    reg [15:0] pixel;
    integer frame, beat, i, x, y, cycles, dump;
    pcie_test_source dut(.clk(clk),.rst_n(rst_n),.ramp_mode(ramp_mode),
        .read_enable(read_enable),.read_data(data));

    function [15:0] expected_pixel;
        input integer px,py;
        begin
            if(py>=300) expected_pixel={px[4:0],px[5:0],px[4:0]};
            else case(px/80)
                0:expected_pixel=16'hffff;
                1:expected_pixel=16'hffe0;
                2:expected_pixel=16'h07ff;
                3:expected_pixel=16'h07e0;
                4:expected_pixel=16'hf81f;
                5:expected_pixel=16'hf800;
                6:expected_pixel=16'h001f;
                default:expected_pixel=16'h0000;
            endcase
        end
    endfunction
    initial begin
        dump=$fopen("FPGA_AADCS/sim/results/colorbars.hex","w");
        repeat(4) @(negedge clk);rst_n=1;
        for(frame=0;frame<2;frame=frame+1) begin
            for(beat=0;beat<32000;beat=beat+1) begin
                // Deterministic gaps represent host pacing and FIFO pressure.
                if(beat%17==0) begin
                    previous=data;read_enable=0;
                    repeat(3) @(negedge clk);
                    if(data !== previous) $fatal(1,"data changed during pause");
                end
                read_enable=1;@(negedge clk);read_enable=0;
                if(beat==0) begin
                    if(data !== 128'h3568cafe5a000000a55a0000d5000001)
                        $fatal(1,"bad frame header");
                end else begin
                    x=(beat%80)*8;y=beat/80;
                    for(i=0;i<8;i=i+1) begin
                        pixel=expected_pixel(x+i,y);
                        if(data[i*16+:16] !== {pixel[7:0],pixel[15:8]})
                            $fatal(1,"pixel mismatch frame %0d x%0d y%0d",frame,x+i,y);
                    end
                end
                if(frame==0) $fdisplay(dump,"%032h",data);
            end
        end
        $fclose(dump);
        rst_n=0;repeat(2) @(negedge clk);ramp_mode=1;rst_n=1;
        for(beat=0;beat<512;beat=beat+1) begin
            read_enable=1;@(negedge clk);read_enable=0;
            for(i=0;i<4;i=i+1)
                if(data[i*32+:32] !== beat*4+i) $fatal(1,"counter mismatch");
            repeat(beat%3) @(negedge clk);
        end
        $display("PASS source: two complete 640x400 frames, frame wrap, read pauses, RGB565 byte order and counter reset");
        $finish;
    end
    initial begin #5000000;$fatal(1,"source timeout");end
endmodule
