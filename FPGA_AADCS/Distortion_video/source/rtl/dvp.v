`timescale 1ns/1ps

// OV5640 8-bit DVP RGB565 unpacker. All outputs stay in the PCLK domain.
// VSYNC is active high by default; HREF marks the active bytes of a line.
// One output pixel is produced for each two input bytes, high byte first.
module dvp #(
    parameter integer WIDTH = 1920,
    parameter integer HEIGHT = 1080,
    parameter integer VSYNC_ACTIVE_HIGH = 1,
    parameter integer HIGH_BYTE_FIRST = 1
)(
    input  wire        pclk,
    input  wire        rst_n,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  data,
    output reg         valid,
    output reg  [15:0] pixel,
    output reg  [11:0] x,
    output reg  [11:0] y,
    output reg         sof,
    output reg         sol
);

    wire frame_sync = VSYNC_ACTIVE_HIGH ? vsync : ~vsync;
    reg href_d;
    reg byte_phase;
    reg [7:0] first_byte;
    reg [11:0] x_count;
    reg [11:0] y_count;
    reg frame_pending;

    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            href_d <= 1'b0;
            byte_phase <= 1'b0;
            first_byte <= 8'd0;
            x_count <= 12'd0;
            y_count <= 12'd0;
            frame_pending <= 1'b0;
            valid <= 1'b0;
            pixel <= 16'd0;
            x <= 12'd0;
            y <= 12'd0;
            sof <= 1'b0;
            sol <= 1'b0;
        end else begin
            href_d <= href;
            valid <= 1'b0;
            sof <= 1'b0;
            sol <= 1'b0;

            if (frame_sync) begin
                byte_phase <= 1'b0;
                x_count <= 12'd0;
                y_count <= 12'd0;
                frame_pending <= 1'b1;
            end else if (href) begin
                if (!byte_phase) begin
                    first_byte <= data;
                    byte_phase <= 1'b1;
                end else begin
                    byte_phase <= 1'b0;
                    if ((x_count < WIDTH) && (y_count < HEIGHT)) begin
                        valid <= 1'b1;
                        pixel <= HIGH_BYTE_FIRST ? {first_byte, data}
                                                 : {data, first_byte};
                        x <= x_count;
                        y <= y_count;
                        sol <= (x_count == 0);
                        sof <= frame_pending;
                        frame_pending <= 1'b0;
                    end
                    if (x_count < WIDTH)
                        x_count <= x_count + 12'd1;
                end
            end else if (href_d) begin
                // Discard an odd trailing byte; never splice adjacent lines.
                byte_phase <= 1'b0;
                x_count <= 12'd0;
                if (y_count < HEIGHT)
                    y_count <= y_count + 12'd1;
            end
        end
    end
endmodule
