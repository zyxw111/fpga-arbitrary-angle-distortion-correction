`timescale 1ns/1ps
module tb_distortion_coord_pipeline;
    parameter integer WIDTH = 64;
    parameter integer HEIGHT = 48;
    localparam integer PIXELS = WIDTH * HEIGHT;

    logic clk = 0;
    logic rst_n = 0;
    logic in_valid = 0;
    logic [11:0] in_x = 0, in_y = 0;
    logic out_valid;
    logic signed [31:0] map_x, map_y;
    logic signed [31:0] ref_x, ref_y;
    logic [31:0] params [0:9];
    logic signed [31:0] expected_x [0:PIXELS-1];
    logic signed [31:0] expected_y [0:PIXELS-1];
    integer accepted = 0;
    integer checked = 0;
    integer errors = 0;
    integer x, y;
    string case_name;
    string vector_set;
    string case_path;

    always #5 clk = ~clk;

    distortion_coord reference_u (
        .out_x(in_x), .out_y(in_y),
        .fx_q12(params[0]), .fy_q12(params[1]),
        .cx_q12(params[2]), .cy_q12(params[3]),
        .inv_fx_q30(params[4]), .inv_fy_q30(params[5]),
        .k1_q30(params[6]), .k2_q30(params[7]),
        .p1_q30(params[8]), .p2_q30(params[9]),
        .map_x_q12(ref_x), .map_y_q12(ref_y)
    );

    distortion_coord_pipeline dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .out_x(in_x), .out_y(in_y),
        .fx_q12(params[0]), .fy_q12(params[1]),
        .cx_q12(params[2]), .cy_q12(params[3]),
        .inv_fx_q30(params[4]), .inv_fy_q30(params[5]),
        .k1_q30(params[6]), .k2_q30(params[7]),
        .p1_q30(params[8]), .p2_q30(params[9]),
        .out_valid(out_valid), .map_x_q12(map_x), .map_y_q12(map_y)
    );

    always @(posedge clk) begin
        if (rst_n && in_valid) begin
            expected_x[accepted] <= ref_x;
            expected_y[accepted] <= ref_y;
            accepted <= accepted + 1;
        end
    end

    always @(negedge clk) begin
        if (rst_n && out_valid) begin
            if ((map_x !== expected_x[checked]) || (map_y !== expected_y[checked])) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("Mismatch %0d: rtl=(%0d,%0d) ref=(%0d,%0d)",
                             checked, map_x, map_y,
                             expected_x[checked], expected_y[checked]);
            end
            checked = checked + 1;
        end
    end

    initial begin
        if (!$value$plusargs("CASE=%s", case_name)) case_name = "fov_090";
        if (!$value$plusargs("VECTOR_SET=%s", vector_set)) vector_set = "basic_90_130";
        case_path = {"../02_RTL仿真/vectors/", vector_set, "/", case_name};
        $readmemh({case_path, "/params.hex"}, params);

        repeat (5) @(negedge clk);
        rst_n = 1;
        for (y = 0; y < HEIGHT; y = y + 1) begin
            for (x = 0; x < WIDTH; x = x + 1) begin
                @(negedge clk);
                in_valid = 1;
                in_x = x;
                in_y = y;
            end
        end
        @(negedge clk);
        in_valid = 0;

        wait (checked == PIXELS);
        if (errors == 0) begin
            $display("PASS PIPE %s: %0d coordinates matched", case_name, checked);
            $finish;
        end else begin
            $fatal(1, "FAIL PIPE %s: errors=%0d", case_name, errors);
        end
    end

    initial begin
        #20000000;
        $fatal(1, "Pipeline simulation timeout: checked=%0d", checked);
    end
endmodule
