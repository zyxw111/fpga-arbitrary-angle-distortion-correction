`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:Meyesemi 
// Engineer: Will
// 
// Create Date: 2023-01-29 20:31  
// Design Name:  
// Module Name: 
// Project Name: 
// Target Devices: Pango
// Tool Versions: 
// Description: 
//      
// Dependencies: 
// 
// Revision:
// Revision 1.0 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`define UD #1
module ms7200_ctl(
    input               clk,
    input               rstn,
                        
    output reg          init_over,
    output        [7:0] device_id,
    output reg          iic_trig ,
    output reg          w_r      ,
    output reg   [15:0] addr     ,
    output reg   [ 7:0] data_in  ,
    input               busy     ,
    input        [ 7:0] data_out ,
    input wire [2:0]    profile_select,
    output wire         edid_written,
    output wire [6:0]    debug_state,
    output wire [8:0]    debug_index,
    output wire [31:0]   debug_frequency,
    input               byte_over 
);
    assign device_id = 8'h56;
function [7:0] get_edid;
input [2:0] profile; input [7:0] offset;
begin case (profile)
3'd0: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h00;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h00;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h20;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'h02;
8'h37: get_edid=8'h3a;
8'h38: get_edid=8'h80;
8'h39: get_edid=8'h18;
8'h3a: get_edid=8'h71;
8'h3b: get_edid=8'h38;
8'h3c: get_edid=8'h2d;
8'h3d: get_edid=8'h40;
8'h3e: get_edid=8'h58;
8'h3f: get_edid=8'h2c;
8'h40: get_edid=8'h45;
8'h41: get_edid=8'h00;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h1e;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h30;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h30;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'h4d;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h13;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h46;
8'h85: get_edid=8'h90;
8'h86: get_edid=8'h01;
8'h87: get_edid=8'h13;
8'h88: get_edid=8'h04;
8'h89: get_edid=8'h22;
8'h8a: get_edid=8'h1f;
8'h8b: get_edid=8'h67;
8'h8c: get_edid=8'h03;
8'h8d: get_edid=8'h0c;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h10;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h1e;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h15;
default: get_edid=8'h00;
endcase end
3'd1: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h01;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h01;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h20;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'hd6;
8'h37: get_edid=8'h09;
8'h38: get_edid=8'h80;
8'h39: get_edid=8'ha0;
8'h3a: get_edid=8'h20;
8'h3b: get_edid=8'he0;
8'h3c: get_edid=8'h2d;
8'h3d: get_edid=8'h10;
8'h3e: get_edid=8'h10;
8'h3f: get_edid=8'h60;
8'h40: get_edid=8'ha2;
8'h41: get_edid=8'h00;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h18;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h31;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h31;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'hb4;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h0e;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h41;
8'h85: get_edid=8'h81;
8'h86: get_edid=8'h67;
8'h87: get_edid=8'h03;
8'h88: get_edid=8'h0c;
8'h89: get_edid=8'h00;
8'h8a: get_edid=8'h10;
8'h8b: get_edid=8'h00;
8'h8c: get_edid=8'h00;
8'h8d: get_edid=8'h1e;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h00;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h00;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h87;
default: get_edid=8'h00;
endcase end
3'd2: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h02;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h02;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h00;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'h01;
8'h37: get_edid=8'h1d;
8'h38: get_edid=8'h00;
8'h39: get_edid=8'hbc;
8'h3a: get_edid=8'h52;
8'h3b: get_edid=8'hd0;
8'h3c: get_edid=8'h1e;
8'h3d: get_edid=8'h20;
8'h3e: get_edid=8'hb8;
8'h3f: get_edid=8'h28;
8'h40: get_edid=8'h55;
8'h41: get_edid=8'h40;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h1e;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h32;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h32;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'h69;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h0e;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h41;
8'h85: get_edid=8'h93;
8'h86: get_edid=8'h67;
8'h87: get_edid=8'h03;
8'h88: get_edid=8'h0c;
8'h89: get_edid=8'h00;
8'h8a: get_edid=8'h10;
8'h8b: get_edid=8'h00;
8'h8c: get_edid=8'h00;
8'h8d: get_edid=8'h1e;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h00;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h00;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h75;
default: get_edid=8'h00;
endcase end
3'd3: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h03;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h03;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h00;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'h01;
8'h37: get_edid=8'h1d;
8'h38: get_edid=8'h00;
8'h39: get_edid=8'h72;
8'h3a: get_edid=8'h51;
8'h3b: get_edid=8'hd0;
8'h3c: get_edid=8'h1e;
8'h3d: get_edid=8'h20;
8'h3e: get_edid=8'h6e;
8'h3f: get_edid=8'h28;
8'h40: get_edid=8'h55;
8'h41: get_edid=8'h00;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h1e;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h33;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h33;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'h3a;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h0e;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h41;
8'h85: get_edid=8'h84;
8'h86: get_edid=8'h67;
8'h87: get_edid=8'h03;
8'h88: get_edid=8'h0c;
8'h89: get_edid=8'h00;
8'h8a: get_edid=8'h10;
8'h8b: get_edid=8'h00;
8'h8c: get_edid=8'h00;
8'h8d: get_edid=8'h1e;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h00;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h00;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h84;
default: get_edid=8'h00;
endcase end
3'd4: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h04;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h04;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h00;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'h01;
8'h37: get_edid=8'h1d;
8'h38: get_edid=8'h80;
8'h39: get_edid=8'h18;
8'h3a: get_edid=8'h71;
8'h3b: get_edid=8'h38;
8'h3c: get_edid=8'h2d;
8'h3d: get_edid=8'h40;
8'h3e: get_edid=8'h58;
8'h3f: get_edid=8'h2c;
8'h40: get_edid=8'h45;
8'h41: get_edid=8'h00;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h1e;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h34;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h34;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'h7b;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h0e;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h41;
8'h85: get_edid=8'ha2;
8'h86: get_edid=8'h67;
8'h87: get_edid=8'h03;
8'h88: get_edid=8'h0c;
8'h89: get_edid=8'h00;
8'h8a: get_edid=8'h10;
8'h8b: get_edid=8'h00;
8'h8c: get_edid=8'h00;
8'h8d: get_edid=8'h1e;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h00;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h00;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h66;
default: get_edid=8'h00;
endcase end
3'd5: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h05;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h05;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h00;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'h02;
8'h37: get_edid=8'h3a;
8'h38: get_edid=8'h80;
8'h39: get_edid=8'hd0;
8'h3a: get_edid=8'h72;
8'h3b: get_edid=8'h38;
8'h3c: get_edid=8'h2d;
8'h3d: get_edid=8'h40;
8'h3e: get_edid=8'h10;
8'h3f: get_edid=8'h2c;
8'h40: get_edid=8'h45;
8'h41: get_edid=8'h80;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h1e;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h35;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h35;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'h68;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h0e;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h41;
8'h85: get_edid=8'h9f;
8'h86: get_edid=8'h67;
8'h87: get_edid=8'h03;
8'h88: get_edid=8'h0c;
8'h89: get_edid=8'h00;
8'h8a: get_edid=8'h10;
8'h8b: get_edid=8'h00;
8'h8c: get_edid=8'h00;
8'h8d: get_edid=8'h1e;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h00;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h00;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h69;
default: get_edid=8'h00;
endcase end
3'd6: begin case (offset)
8'h00: get_edid=8'h00;
8'h01: get_edid=8'hff;
8'h02: get_edid=8'hff;
8'h03: get_edid=8'hff;
8'h04: get_edid=8'hff;
8'h05: get_edid=8'hff;
8'h06: get_edid=8'hff;
8'h07: get_edid=8'h00;
8'h08: get_edid=8'h1a;
8'h09: get_edid=8'h07;
8'h0a: get_edid=8'h06;
8'h0b: get_edid=8'h20;
8'h0c: get_edid=8'h06;
8'h0d: get_edid=8'h02;
8'h0e: get_edid=8'h00;
8'h0f: get_edid=8'h00;
8'h10: get_edid=8'h01;
8'h11: get_edid=8'h24;
8'h12: get_edid=8'h01;
8'h13: get_edid=8'h03;
8'h14: get_edid=8'h80;
8'h15: get_edid=8'h34;
8'h16: get_edid=8'h1d;
8'h17: get_edid=8'h78;
8'h18: get_edid=8'h0a;
8'h19: get_edid=8'hee;
8'h1a: get_edid=8'h91;
8'h1b: get_edid=8'ha3;
8'h1c: get_edid=8'h54;
8'h1d: get_edid=8'h4c;
8'h1e: get_edid=8'h99;
8'h1f: get_edid=8'h26;
8'h20: get_edid=8'h0f;
8'h21: get_edid=8'h50;
8'h22: get_edid=8'h54;
8'h23: get_edid=8'h00;
8'h24: get_edid=8'h00;
8'h25: get_edid=8'h00;
8'h26: get_edid=8'h01;
8'h27: get_edid=8'h01;
8'h28: get_edid=8'h01;
8'h29: get_edid=8'h01;
8'h2a: get_edid=8'h01;
8'h2b: get_edid=8'h01;
8'h2c: get_edid=8'h01;
8'h2d: get_edid=8'h01;
8'h2e: get_edid=8'h01;
8'h2f: get_edid=8'h01;
8'h30: get_edid=8'h01;
8'h31: get_edid=8'h01;
8'h32: get_edid=8'h01;
8'h33: get_edid=8'h01;
8'h34: get_edid=8'h01;
8'h35: get_edid=8'h01;
8'h36: get_edid=8'h02;
8'h37: get_edid=8'h3a;
8'h38: get_edid=8'h80;
8'h39: get_edid=8'h18;
8'h3a: get_edid=8'h71;
8'h3b: get_edid=8'h38;
8'h3c: get_edid=8'h2d;
8'h3d: get_edid=8'h40;
8'h3e: get_edid=8'h58;
8'h3f: get_edid=8'h2c;
8'h40: get_edid=8'h45;
8'h41: get_edid=8'h00;
8'h42: get_edid=8'h00;
8'h43: get_edid=8'h00;
8'h44: get_edid=8'h00;
8'h45: get_edid=8'h00;
8'h46: get_edid=8'h00;
8'h47: get_edid=8'h1e;
8'h48: get_edid=8'h00;
8'h49: get_edid=8'h00;
8'h4a: get_edid=8'h00;
8'h4b: get_edid=8'hfc;
8'h4c: get_edid=8'h00;
8'h4d: get_edid=8'h46;
8'h4e: get_edid=8'h50;
8'h4f: get_edid=8'h47;
8'h50: get_edid=8'h41;
8'h51: get_edid=8'h20;
8'h52: get_edid=8'h56;
8'h53: get_edid=8'h32;
8'h54: get_edid=8'h20;
8'h55: get_edid=8'h50;
8'h56: get_edid=8'h36;
8'h57: get_edid=8'h0a;
8'h58: get_edid=8'h20;
8'h59: get_edid=8'h20;
8'h5a: get_edid=8'h00;
8'h5b: get_edid=8'h00;
8'h5c: get_edid=8'h00;
8'h5d: get_edid=8'hff;
8'h5e: get_edid=8'h00;
8'h5f: get_edid=8'h48;
8'h60: get_edid=8'h44;
8'h61: get_edid=8'h4d;
8'h62: get_edid=8'h49;
8'h63: get_edid=8'h4b;
8'h64: get_edid=8'h2d;
8'h65: get_edid=8'h56;
8'h66: get_edid=8'h31;
8'h67: get_edid=8'h31;
8'h68: get_edid=8'h2d;
8'h69: get_edid=8'h50;
8'h6a: get_edid=8'h36;
8'h6b: get_edid=8'h0a;
8'h6c: get_edid=8'h00;
8'h6d: get_edid=8'h00;
8'h6e: get_edid=8'h00;
8'h6f: get_edid=8'h10;
8'h70: get_edid=8'h00;
8'h71: get_edid=8'h00;
8'h72: get_edid=8'h00;
8'h73: get_edid=8'h00;
8'h74: get_edid=8'h00;
8'h75: get_edid=8'h00;
8'h76: get_edid=8'h00;
8'h77: get_edid=8'h00;
8'h78: get_edid=8'h00;
8'h79: get_edid=8'h00;
8'h7a: get_edid=8'h00;
8'h7b: get_edid=8'h00;
8'h7c: get_edid=8'h00;
8'h7d: get_edid=8'h00;
8'h7e: get_edid=8'h01;
8'h7f: get_edid=8'h55;
8'h80: get_edid=8'h02;
8'h81: get_edid=8'h03;
8'h82: get_edid=8'h0e;
8'h83: get_edid=8'h00;
8'h84: get_edid=8'h41;
8'h85: get_edid=8'h90;
8'h86: get_edid=8'h67;
8'h87: get_edid=8'h03;
8'h88: get_edid=8'h0c;
8'h89: get_edid=8'h00;
8'h8a: get_edid=8'h10;
8'h8b: get_edid=8'h00;
8'h8c: get_edid=8'h00;
8'h8d: get_edid=8'h1e;
8'h8e: get_edid=8'h00;
8'h8f: get_edid=8'h00;
8'h90: get_edid=8'h00;
8'h91: get_edid=8'h00;
8'h92: get_edid=8'h00;
8'h93: get_edid=8'h00;
8'h94: get_edid=8'h00;
8'h95: get_edid=8'h00;
8'h96: get_edid=8'h00;
8'h97: get_edid=8'h00;
8'h98: get_edid=8'h00;
8'h99: get_edid=8'h00;
8'h9a: get_edid=8'h00;
8'h9b: get_edid=8'h00;
8'h9c: get_edid=8'h00;
8'h9d: get_edid=8'h00;
8'h9e: get_edid=8'h00;
8'h9f: get_edid=8'h00;
8'ha0: get_edid=8'h00;
8'ha1: get_edid=8'h00;
8'ha2: get_edid=8'h00;
8'ha3: get_edid=8'h00;
8'ha4: get_edid=8'h00;
8'ha5: get_edid=8'h00;
8'ha6: get_edid=8'h00;
8'ha7: get_edid=8'h00;
8'ha8: get_edid=8'h00;
8'ha9: get_edid=8'h00;
8'haa: get_edid=8'h00;
8'hab: get_edid=8'h00;
8'hac: get_edid=8'h00;
8'had: get_edid=8'h00;
8'hae: get_edid=8'h00;
8'haf: get_edid=8'h00;
8'hb0: get_edid=8'h00;
8'hb1: get_edid=8'h00;
8'hb2: get_edid=8'h00;
8'hb3: get_edid=8'h00;
8'hb4: get_edid=8'h00;
8'hb5: get_edid=8'h00;
8'hb6: get_edid=8'h00;
8'hb7: get_edid=8'h00;
8'hb8: get_edid=8'h00;
8'hb9: get_edid=8'h00;
8'hba: get_edid=8'h00;
8'hbb: get_edid=8'h00;
8'hbc: get_edid=8'h00;
8'hbd: get_edid=8'h00;
8'hbe: get_edid=8'h00;
8'hbf: get_edid=8'h00;
8'hc0: get_edid=8'h00;
8'hc1: get_edid=8'h00;
8'hc2: get_edid=8'h00;
8'hc3: get_edid=8'h00;
8'hc4: get_edid=8'h00;
8'hc5: get_edid=8'h00;
8'hc6: get_edid=8'h00;
8'hc7: get_edid=8'h00;
8'hc8: get_edid=8'h00;
8'hc9: get_edid=8'h00;
8'hca: get_edid=8'h00;
8'hcb: get_edid=8'h00;
8'hcc: get_edid=8'h00;
8'hcd: get_edid=8'h00;
8'hce: get_edid=8'h00;
8'hcf: get_edid=8'h00;
8'hd0: get_edid=8'h00;
8'hd1: get_edid=8'h00;
8'hd2: get_edid=8'h00;
8'hd3: get_edid=8'h00;
8'hd4: get_edid=8'h00;
8'hd5: get_edid=8'h00;
8'hd6: get_edid=8'h00;
8'hd7: get_edid=8'h00;
8'hd8: get_edid=8'h00;
8'hd9: get_edid=8'h00;
8'hda: get_edid=8'h00;
8'hdb: get_edid=8'h00;
8'hdc: get_edid=8'h00;
8'hdd: get_edid=8'h00;
8'hde: get_edid=8'h00;
8'hdf: get_edid=8'h00;
8'he0: get_edid=8'h00;
8'he1: get_edid=8'h00;
8'he2: get_edid=8'h00;
8'he3: get_edid=8'h00;
8'he4: get_edid=8'h00;
8'he5: get_edid=8'h00;
8'he6: get_edid=8'h00;
8'he7: get_edid=8'h00;
8'he8: get_edid=8'h00;
8'he9: get_edid=8'h00;
8'hea: get_edid=8'h00;
8'heb: get_edid=8'h00;
8'hec: get_edid=8'h00;
8'hed: get_edid=8'h00;
8'hee: get_edid=8'h00;
8'hef: get_edid=8'h00;
8'hf0: get_edid=8'h00;
8'hf1: get_edid=8'h00;
8'hf2: get_edid=8'h00;
8'hf3: get_edid=8'h00;
8'hf4: get_edid=8'h00;
8'hf5: get_edid=8'h00;
8'hf6: get_edid=8'h00;
8'hf7: get_edid=8'h00;
8'hf8: get_edid=8'h00;
8'hf9: get_edid=8'h00;
8'hfa: get_edid=8'h00;
8'hfb: get_edid=8'h00;
8'hfc: get_edid=8'h00;
8'hfd: get_edid=8'h00;
8'hfe: get_edid=8'h00;
8'hff: get_edid=8'h78;
default: get_edid=8'h00;
endcase end
default: get_edid=8'h00;
endcase end endfunction
function [23:0] cmd_data;
input [9:0] index;
    begin
        case(index)
            9'd0   : cmd_data = {16'h0204, 8'h02};
            9'd1   : cmd_data = {16'h0205, 8'h40};
            9'd2   : cmd_data = {16'h0004, 8'h01};
            9'd3   : cmd_data = {16'h0009, 8'h26};
            9'd4   : cmd_data = {16'h102E, 8'h01};
            9'd5   : cmd_data = {16'h1025, 8'hB0};
            9'd6   : cmd_data = {16'h102D, 8'h83};
            9'd7   : cmd_data = {16'h1000, 8'h20};
            9'd8   : cmd_data = {16'h100F, 8'h04};
            9'd9   : cmd_data = {16'h0003, 8'hC3};
            9'd10  : cmd_data = {16'h103B, 8'h02};
            9'd11  : cmd_data = {16'h00E1, 8'h00};
            9'd12  : cmd_data = {16'h00A8, 8'h08};
            9'd13  : cmd_data = {16'h000A, 8'h00};
            9'd14  : cmd_data = {16'h0016, 8'h02};
            9'd15  : cmd_data = {16'h00E2, 8'h01};
            9'd16  : cmd_data = {16'h00C2, 8'h14};
            9'd17  : cmd_data = {16'h102D, 8'hC7};
            9'd18  : cmd_data = {16'h1005, 8'h04};
            9'd19  : cmd_data = {16'h1003, 8'h14};
            9'd20  : cmd_data = {16'h1004, 8'h01};
            9'd21  : cmd_data = {16'h1000, 8'h60};
            9'd22  : cmd_data = {16'h1020, 8'h13};
            9'd23  : cmd_data = {16'h1021, 8'h04};
            9'd24  : cmd_data = {16'h1022, 8'h04};
            9'd25  : cmd_data = {16'h1023, 8'h0C};
            9'd26  : cmd_data = {16'h102B, 8'h33};
            9'd27  : cmd_data = {16'h102C, 8'h33};
            9'd28  : cmd_data = {16'h00F0, 8'h10};
            9'd29  : cmd_data = {16'h000C, 8'h80};
            9'd30  : cmd_data = {16'h0D00, get_edid(profile_select,8'h00)};
            9'd31  : cmd_data = {16'h0D01, get_edid(profile_select,8'h01)};
            9'd32  : cmd_data = {16'h0D02, get_edid(profile_select,8'h02)};
            9'd33  : cmd_data = {16'h0D03, get_edid(profile_select,8'h03)};
            9'd34  : cmd_data = {16'h0D04, get_edid(profile_select,8'h04)};
            9'd35  : cmd_data = {16'h0D05, get_edid(profile_select,8'h05)};
            9'd36  : cmd_data = {16'h0D06, get_edid(profile_select,8'h06)};
            9'd37  : cmd_data = {16'h0D07, get_edid(profile_select,8'h07)};
            9'd38  : cmd_data = {16'h0D00, get_edid(profile_select,8'h00)};
            9'd39  : cmd_data = {16'h0D01, get_edid(profile_select,8'h01)};
            9'd40  : cmd_data = {16'h0D02, get_edid(profile_select,8'h02)};
            9'd41  : cmd_data = {16'h0D03, get_edid(profile_select,8'h03)};
            9'd42  : cmd_data = {16'h0D04, get_edid(profile_select,8'h04)};
            9'd43  : cmd_data = {16'h0D05, get_edid(profile_select,8'h05)};
            9'd44  : cmd_data = {16'h0D06, get_edid(profile_select,8'h06)};
            9'd45  : cmd_data = {16'h0D07, get_edid(profile_select,8'h07)};
            9'd46  : cmd_data = {16'h0D08, get_edid(profile_select,8'h08)};
            9'd47  : cmd_data = {16'h0D09, get_edid(profile_select,8'h09)};
            9'd48  : cmd_data = {16'h0D0A, get_edid(profile_select,8'h0a)};
            9'd49  : cmd_data = {16'h0D0B, get_edid(profile_select,8'h0b)};
            9'd50  : cmd_data = {16'h0D0C, get_edid(profile_select,8'h0c)};
            9'd51  : cmd_data = {16'h0D0D, get_edid(profile_select,8'h0d)};
            9'd52  : cmd_data = {16'h0D0E, get_edid(profile_select,8'h0e)};
            9'd53  : cmd_data = {16'h0D0F, get_edid(profile_select,8'h0f)};
            9'd54  : cmd_data = {16'h0D10, get_edid(profile_select,8'h10)};
            9'd55  : cmd_data = {16'h0D11, get_edid(profile_select,8'h11)};
            9'd56  : cmd_data = {16'h0D12, get_edid(profile_select,8'h12)};
            9'd57  : cmd_data = {16'h0D13, get_edid(profile_select,8'h13)};
            9'd58  : cmd_data = {16'h0D14, get_edid(profile_select,8'h14)};
            9'd59  : cmd_data = {16'h0D15, get_edid(profile_select,8'h15)};
            9'd60  : cmd_data = {16'h0D16, get_edid(profile_select,8'h16)};
            9'd61  : cmd_data = {16'h0D17, get_edid(profile_select,8'h17)};
            9'd62  : cmd_data = {16'h0D18, get_edid(profile_select,8'h18)};
            9'd63  : cmd_data = {16'h0D19, get_edid(profile_select,8'h19)};
            9'd64  : cmd_data = {16'h0D1A, get_edid(profile_select,8'h1a)};
            9'd65  : cmd_data = {16'h0D1B, get_edid(profile_select,8'h1b)};
            9'd66  : cmd_data = {16'h0D1C, get_edid(profile_select,8'h1c)};
            9'd67  : cmd_data = {16'h0D1D, get_edid(profile_select,8'h1d)};
            9'd68  : cmd_data = {16'h0D1E, get_edid(profile_select,8'h1e)};
            9'd69  : cmd_data = {16'h0D1F, get_edid(profile_select,8'h1f)};
            9'd70  : cmd_data = {16'h0D20, get_edid(profile_select,8'h20)};
            9'd71  : cmd_data = {16'h0D21, get_edid(profile_select,8'h21)};
            9'd72  : cmd_data = {16'h0D22, get_edid(profile_select,8'h22)};
            9'd73  : cmd_data = {16'h0D23, get_edid(profile_select,8'h23)};
            9'd74  : cmd_data = {16'h0D24, get_edid(profile_select,8'h24)};
            9'd75  : cmd_data = {16'h0D25, get_edid(profile_select,8'h25)};
            9'd76  : cmd_data = {16'h0D26, get_edid(profile_select,8'h26)};
            9'd77  : cmd_data = {16'h0D27, get_edid(profile_select,8'h27)};
            9'd78  : cmd_data = {16'h0D28, get_edid(profile_select,8'h28)};
            9'd79  : cmd_data = {16'h0D29, get_edid(profile_select,8'h29)};
            9'd80  : cmd_data = {16'h0D2A, get_edid(profile_select,8'h2a)};
            9'd81  : cmd_data = {16'h0D2B, get_edid(profile_select,8'h2b)};
            9'd82  : cmd_data = {16'h0D2C, get_edid(profile_select,8'h2c)};
            9'd83  : cmd_data = {16'h0D2D, get_edid(profile_select,8'h2d)};
            9'd84  : cmd_data = {16'h0D2E, get_edid(profile_select,8'h2e)};
            9'd85  : cmd_data = {16'h0D2F, get_edid(profile_select,8'h2f)};
            9'd86  : cmd_data = {16'h0D30, get_edid(profile_select,8'h30)};
            9'd87  : cmd_data = {16'h0D31, get_edid(profile_select,8'h31)};
            9'd88  : cmd_data = {16'h0D32, get_edid(profile_select,8'h32)};
            9'd89  : cmd_data = {16'h0D33, get_edid(profile_select,8'h33)};
            9'd90  : cmd_data = {16'h0D34, get_edid(profile_select,8'h34)};
            9'd91  : cmd_data = {16'h0D35, get_edid(profile_select,8'h35)};
            9'd92  : cmd_data = {16'h0D36, get_edid(profile_select,8'h36)};
            9'd93  : cmd_data = {16'h0D37, get_edid(profile_select,8'h37)};
            9'd94  : cmd_data = {16'h0D38, get_edid(profile_select,8'h38)};
            9'd95  : cmd_data = {16'h0D39, get_edid(profile_select,8'h39)};
            9'd96  : cmd_data = {16'h0D3A, get_edid(profile_select,8'h3a)};
            9'd97  : cmd_data = {16'h0D3B, get_edid(profile_select,8'h3b)};
            9'd98  : cmd_data = {16'h0D3C, get_edid(profile_select,8'h3c)};
            9'd99  : cmd_data = {16'h0D3D, get_edid(profile_select,8'h3d)};
            9'd100 : cmd_data = {16'h0D3E, get_edid(profile_select,8'h3e)};
            9'd101 : cmd_data = {16'h0D3F, get_edid(profile_select,8'h3f)};
            9'd102 : cmd_data = {16'h0D40, get_edid(profile_select,8'h40)};
            9'd103 : cmd_data = {16'h0D41, get_edid(profile_select,8'h41)};
            9'd104 : cmd_data = {16'h0D42, get_edid(profile_select,8'h42)};
            9'd105 : cmd_data = {16'h0D43, get_edid(profile_select,8'h43)};
            9'd106 : cmd_data = {16'h0D44, get_edid(profile_select,8'h44)};
            9'd107 : cmd_data = {16'h0D45, get_edid(profile_select,8'h45)};
            9'd108 : cmd_data = {16'h0D46, get_edid(profile_select,8'h46)};
            9'd109 : cmd_data = {16'h0D47, get_edid(profile_select,8'h47)};
            9'd110 : cmd_data = {16'h0D48, get_edid(profile_select,8'h48)};
            9'd111 : cmd_data = {16'h0D49, get_edid(profile_select,8'h49)};
            9'd112 : cmd_data = {16'h0D4A, get_edid(profile_select,8'h4a)};
            9'd113 : cmd_data = {16'h0D4B, get_edid(profile_select,8'h4b)};
            9'd114 : cmd_data = {16'h0D4C, get_edid(profile_select,8'h4c)};
            9'd115 : cmd_data = {16'h0D4D, get_edid(profile_select,8'h4d)};
            9'd116 : cmd_data = {16'h0D4E, get_edid(profile_select,8'h4e)};
            9'd117 : cmd_data = {16'h0D4F, get_edid(profile_select,8'h4f)};
            9'd118 : cmd_data = {16'h0D50, get_edid(profile_select,8'h50)};
            9'd119 : cmd_data = {16'h0D51, get_edid(profile_select,8'h51)};
            9'd120 : cmd_data = {16'h0D52, get_edid(profile_select,8'h52)};
            9'd121 : cmd_data = {16'h0D53, get_edid(profile_select,8'h53)};
            9'd122 : cmd_data = {16'h0D54, get_edid(profile_select,8'h54)};
            9'd123 : cmd_data = {16'h0D55, get_edid(profile_select,8'h55)};
            9'd124 : cmd_data = {16'h0D56, get_edid(profile_select,8'h56)};
            9'd125 : cmd_data = {16'h0D57, get_edid(profile_select,8'h57)};
            9'd126 : cmd_data = {16'h0D58, get_edid(profile_select,8'h58)};
            9'd127 : cmd_data = {16'h0D59, get_edid(profile_select,8'h59)};
            9'd128 : cmd_data = {16'h0D5A, get_edid(profile_select,8'h5a)};
            9'd129 : cmd_data = {16'h0D5B, get_edid(profile_select,8'h5b)};
            9'd130 : cmd_data = {16'h0D5C, get_edid(profile_select,8'h5c)};
            9'd131 : cmd_data = {16'h0D5D, get_edid(profile_select,8'h5d)};
            9'd132 : cmd_data = {16'h0D5E, get_edid(profile_select,8'h5e)};
            9'd133 : cmd_data = {16'h0D5F, get_edid(profile_select,8'h5f)};
            9'd134 : cmd_data = {16'h0D60, get_edid(profile_select,8'h60)};
            9'd135 : cmd_data = {16'h0D61, get_edid(profile_select,8'h61)};
            9'd136 : cmd_data = {16'h0D62, get_edid(profile_select,8'h62)};
            9'd137 : cmd_data = {16'h0D63, get_edid(profile_select,8'h63)};
            9'd138 : cmd_data = {16'h0D64, get_edid(profile_select,8'h64)};
            9'd139 : cmd_data = {16'h0D65, get_edid(profile_select,8'h65)};
            9'd140 : cmd_data = {16'h0D66, get_edid(profile_select,8'h66)};
            9'd141 : cmd_data = {16'h0D67, get_edid(profile_select,8'h67)};
            9'd142 : cmd_data = {16'h0D68, get_edid(profile_select,8'h68)};
            9'd143 : cmd_data = {16'h0D69, get_edid(profile_select,8'h69)};
            9'd144 : cmd_data = {16'h0D6A, get_edid(profile_select,8'h6a)};
            9'd145 : cmd_data = {16'h0D6B, get_edid(profile_select,8'h6b)};
            9'd146 : cmd_data = {16'h0D6C, get_edid(profile_select,8'h6c)};
            9'd147 : cmd_data = {16'h0D6D, get_edid(profile_select,8'h6d)};
            9'd148 : cmd_data = {16'h0D6E, get_edid(profile_select,8'h6e)};
            9'd149 : cmd_data = {16'h0D6F, get_edid(profile_select,8'h6f)};
            9'd150 : cmd_data = {16'h0D70, get_edid(profile_select,8'h70)};
            9'd151 : cmd_data = {16'h0D71, get_edid(profile_select,8'h71)};
            9'd152 : cmd_data = {16'h0D72, get_edid(profile_select,8'h72)};
            9'd153 : cmd_data = {16'h0D73, get_edid(profile_select,8'h73)};
            9'd154 : cmd_data = {16'h0D74, get_edid(profile_select,8'h74)};
            9'd155 : cmd_data = {16'h0D75, get_edid(profile_select,8'h75)};
            9'd156 : cmd_data = {16'h0D76, get_edid(profile_select,8'h76)};
            9'd157 : cmd_data = {16'h0D77, get_edid(profile_select,8'h77)};
            9'd158 : cmd_data = {16'h0D78, get_edid(profile_select,8'h78)};
            9'd159 : cmd_data = {16'h0D79, get_edid(profile_select,8'h79)};
            9'd160 : cmd_data = {16'h0D7A, get_edid(profile_select,8'h7a)};
            9'd161 : cmd_data = {16'h0D7B, get_edid(profile_select,8'h7b)};
            9'd162 : cmd_data = {16'h0D7C, get_edid(profile_select,8'h7c)};
            9'd163 : cmd_data = {16'h0D7D, get_edid(profile_select,8'h7d)};
            9'd164 : cmd_data = {16'h0D7E, get_edid(profile_select,8'h7e)};
            9'd165 : cmd_data = {16'h0D7F, get_edid(profile_select,8'h7f)};
            9'd166 : cmd_data = {16'h0D80, get_edid(profile_select,8'h80)};
            9'd167 : cmd_data = {16'h0D81, get_edid(profile_select,8'h81)};
            9'd168 : cmd_data = {16'h0D82, get_edid(profile_select,8'h82)};
            9'd169 : cmd_data = {16'h0D83, get_edid(profile_select,8'h83)};
            9'd170 : cmd_data = {16'h0D84, get_edid(profile_select,8'h84)};
            9'd171 : cmd_data = {16'h0D85, get_edid(profile_select,8'h85)};
            9'd172 : cmd_data = {16'h0D86, get_edid(profile_select,8'h86)};
            9'd173 : cmd_data = {16'h0D87, get_edid(profile_select,8'h87)};
            9'd174 : cmd_data = {16'h0D88, get_edid(profile_select,8'h88)};
            9'd175 : cmd_data = {16'h0D89, get_edid(profile_select,8'h89)};
            9'd176 : cmd_data = {16'h0D8A, get_edid(profile_select,8'h8a)};
            9'd177 : cmd_data = {16'h0D8B, get_edid(profile_select,8'h8b)};
            9'd178 : cmd_data = {16'h0D8C, get_edid(profile_select,8'h8c)};
            9'd179 : cmd_data = {16'h0D8D, get_edid(profile_select,8'h8d)};
            9'd180 : cmd_data = {16'h0D8E, get_edid(profile_select,8'h8e)};
            9'd181 : cmd_data = {16'h0D8F, get_edid(profile_select,8'h8f)};
            9'd182 : cmd_data = {16'h0D90, get_edid(profile_select,8'h90)};
            9'd183 : cmd_data = {16'h0D91, get_edid(profile_select,8'h91)};
            9'd184 : cmd_data = {16'h0D92, get_edid(profile_select,8'h92)};
            9'd185 : cmd_data = {16'h0D93, get_edid(profile_select,8'h93)};
            9'd186 : cmd_data = {16'h0D94, get_edid(profile_select,8'h94)};
            9'd187 : cmd_data = {16'h0D95, get_edid(profile_select,8'h95)};
            9'd188 : cmd_data = {16'h0D96, get_edid(profile_select,8'h96)};
            9'd189 : cmd_data = {16'h0D97, get_edid(profile_select,8'h97)};
            9'd190 : cmd_data = {16'h0D98, get_edid(profile_select,8'h98)};
            9'd191 : cmd_data = {16'h0D99, get_edid(profile_select,8'h99)};
            9'd192 : cmd_data = {16'h0D9A, get_edid(profile_select,8'h9a)};
            9'd193 : cmd_data = {16'h0D9B, get_edid(profile_select,8'h9b)};
            9'd194 : cmd_data = {16'h0D9C, get_edid(profile_select,8'h9c)};
            9'd195 : cmd_data = {16'h0D9D, get_edid(profile_select,8'h9d)};
            9'd196 : cmd_data = {16'h0D9E, get_edid(profile_select,8'h9e)};
            9'd197 : cmd_data = {16'h0D9F, get_edid(profile_select,8'h9f)};
            9'd198 : cmd_data = {16'h0DA0, get_edid(profile_select,8'ha0)};
            9'd199 : cmd_data = {16'h0DA1, get_edid(profile_select,8'ha1)};
            9'd200 : cmd_data = {16'h0DA2, get_edid(profile_select,8'ha2)};
            9'd201 : cmd_data = {16'h0DA3, get_edid(profile_select,8'ha3)};
            9'd202 : cmd_data = {16'h0DA4, get_edid(profile_select,8'ha4)};
            9'd203 : cmd_data = {16'h0DA5, get_edid(profile_select,8'ha5)};
            9'd204 : cmd_data = {16'h0DA6, get_edid(profile_select,8'ha6)};
            9'd205 : cmd_data = {16'h0DA7, get_edid(profile_select,8'ha7)};
            9'd206 : cmd_data = {16'h0DA8, get_edid(profile_select,8'ha8)};
            9'd207 : cmd_data = {16'h0DA9, get_edid(profile_select,8'ha9)};
            9'd208 : cmd_data = {16'h0DAA, get_edid(profile_select,8'haa)};
            9'd209 : cmd_data = {16'h0DAB, get_edid(profile_select,8'hab)};
            9'd210 : cmd_data = {16'h0DAC, get_edid(profile_select,8'hac)};
            9'd211 : cmd_data = {16'h0DAD, get_edid(profile_select,8'had)};
            9'd212 : cmd_data = {16'h0DAE, get_edid(profile_select,8'hae)};
            9'd213 : cmd_data = {16'h0DAF, get_edid(profile_select,8'haf)};
            9'd214 : cmd_data = {16'h0DB0, get_edid(profile_select,8'hb0)};
            9'd215 : cmd_data = {16'h0DB1, get_edid(profile_select,8'hb1)};
            9'd216 : cmd_data = {16'h0DB2, get_edid(profile_select,8'hb2)};
            9'd217 : cmd_data = {16'h0DB3, get_edid(profile_select,8'hb3)};
            9'd218 : cmd_data = {16'h0DB4, get_edid(profile_select,8'hb4)};
            9'd219 : cmd_data = {16'h0DB5, get_edid(profile_select,8'hb5)};
            9'd220 : cmd_data = {16'h0DB6, get_edid(profile_select,8'hb6)};
            9'd221 : cmd_data = {16'h0DB7, get_edid(profile_select,8'hb7)};
            9'd222 : cmd_data = {16'h0DB8, get_edid(profile_select,8'hb8)};
            9'd223 : cmd_data = {16'h0DB9, get_edid(profile_select,8'hb9)};
            9'd224 : cmd_data = {16'h0DBA, get_edid(profile_select,8'hba)};
            9'd225 : cmd_data = {16'h0DBB, get_edid(profile_select,8'hbb)};
            9'd226 : cmd_data = {16'h0DBC, get_edid(profile_select,8'hbc)};
            9'd227 : cmd_data = {16'h0DBD, get_edid(profile_select,8'hbd)};
            9'd228 : cmd_data = {16'h0DBE, get_edid(profile_select,8'hbe)};
            9'd229 : cmd_data = {16'h0DBF, get_edid(profile_select,8'hbf)};
            9'd230 : cmd_data = {16'h0DC0, get_edid(profile_select,8'hc0)};
            9'd231 : cmd_data = {16'h0DC1, get_edid(profile_select,8'hc1)};
            9'd232 : cmd_data = {16'h0DC2, get_edid(profile_select,8'hc2)};
            9'd233 : cmd_data = {16'h0DC3, get_edid(profile_select,8'hc3)};
            9'd234 : cmd_data = {16'h0DC4, get_edid(profile_select,8'hc4)};
            9'd235 : cmd_data = {16'h0DC5, get_edid(profile_select,8'hc5)};
            9'd236 : cmd_data = {16'h0DC6, get_edid(profile_select,8'hc6)};
            9'd237 : cmd_data = {16'h0DC7, get_edid(profile_select,8'hc7)};
            9'd238 : cmd_data = {16'h0DC8, get_edid(profile_select,8'hc8)};
            9'd239 : cmd_data = {16'h0DC9, get_edid(profile_select,8'hc9)};
            9'd240 : cmd_data = {16'h0DCA, get_edid(profile_select,8'hca)};
            9'd241 : cmd_data = {16'h0DCB, get_edid(profile_select,8'hcb)};
            9'd242 : cmd_data = {16'h0DCC, get_edid(profile_select,8'hcc)};
            9'd243 : cmd_data = {16'h0DCD, get_edid(profile_select,8'hcd)};
            9'd244 : cmd_data = {16'h0DCE, get_edid(profile_select,8'hce)};
            9'd245 : cmd_data = {16'h0DCF, get_edid(profile_select,8'hcf)};
            9'd246 : cmd_data = {16'h0DD0, get_edid(profile_select,8'hd0)};
            9'd247 : cmd_data = {16'h0DD1, get_edid(profile_select,8'hd1)};
            9'd248 : cmd_data = {16'h0DD2, get_edid(profile_select,8'hd2)};
            9'd249 : cmd_data = {16'h0DD3, get_edid(profile_select,8'hd3)};
            9'd250 : cmd_data = {16'h0DD4, get_edid(profile_select,8'hd4)};
            9'd251 : cmd_data = {16'h0DD5, get_edid(profile_select,8'hd5)};
            9'd252 : cmd_data = {16'h0DD6, get_edid(profile_select,8'hd6)};
            9'd253 : cmd_data = {16'h0DD7, get_edid(profile_select,8'hd7)};
            9'd254 : cmd_data = {16'h0DD8, get_edid(profile_select,8'hd8)};
            9'd255 : cmd_data = {16'h0DD9, get_edid(profile_select,8'hd9)};
            9'd256 : cmd_data = {16'h0DDA, get_edid(profile_select,8'hda)};
            9'd257 : cmd_data = {16'h0DDB, get_edid(profile_select,8'hdb)};
            9'd258 : cmd_data = {16'h0DDC, get_edid(profile_select,8'hdc)};
            9'd259 : cmd_data = {16'h0DDD, get_edid(profile_select,8'hdd)};
            9'd260 : cmd_data = {16'h0DDE, get_edid(profile_select,8'hde)};
            9'd261 : cmd_data = {16'h0DDF, get_edid(profile_select,8'hdf)};
            9'd262 : cmd_data = {16'h0DE0, get_edid(profile_select,8'he0)};
            9'd263 : cmd_data = {16'h0DE1, get_edid(profile_select,8'he1)};
            9'd264 : cmd_data = {16'h0DE2, get_edid(profile_select,8'he2)};
            9'd265 : cmd_data = {16'h0DE3, get_edid(profile_select,8'he3)};
            9'd266 : cmd_data = {16'h0DE4, get_edid(profile_select,8'he4)};
            9'd267 : cmd_data = {16'h0DE5, get_edid(profile_select,8'he5)};
            9'd268 : cmd_data = {16'h0DE6, get_edid(profile_select,8'he6)};
            9'd269 : cmd_data = {16'h0DE7, get_edid(profile_select,8'he7)};
            9'd270 : cmd_data = {16'h0DE8, get_edid(profile_select,8'he8)};
            9'd271 : cmd_data = {16'h0DE9, get_edid(profile_select,8'he9)};
            9'd272 : cmd_data = {16'h0DEA, get_edid(profile_select,8'hea)};
            9'd273 : cmd_data = {16'h0DEB, get_edid(profile_select,8'heb)};
            9'd274 : cmd_data = {16'h0DEC, get_edid(profile_select,8'hec)};
            9'd275 : cmd_data = {16'h0DED, get_edid(profile_select,8'hed)};
            9'd276 : cmd_data = {16'h0DEE, get_edid(profile_select,8'hee)};
            9'd277 : cmd_data = {16'h0DEF, get_edid(profile_select,8'hef)};
            9'd278 : cmd_data = {16'h0DF0, get_edid(profile_select,8'hf0)};
            9'd279 : cmd_data = {16'h0DF1, get_edid(profile_select,8'hf1)};
            9'd280 : cmd_data = {16'h0DF2, get_edid(profile_select,8'hf2)};
            9'd281 : cmd_data = {16'h0DF3, get_edid(profile_select,8'hf3)};
            9'd282 : cmd_data = {16'h0DF4, get_edid(profile_select,8'hf4)};
            9'd283 : cmd_data = {16'h0DF5, get_edid(profile_select,8'hf5)};
            9'd284 : cmd_data = {16'h0DF6, get_edid(profile_select,8'hf6)};
            9'd285 : cmd_data = {16'h0DF7, get_edid(profile_select,8'hf7)};
            9'd286 : cmd_data = {16'h0DF8, get_edid(profile_select,8'hf8)};
            9'd287 : cmd_data = {16'h0DF9, get_edid(profile_select,8'hf9)};
            9'd288 : cmd_data = {16'h0DFA, get_edid(profile_select,8'hfa)};
            9'd289 : cmd_data = {16'h0DFB, get_edid(profile_select,8'hfb)};
            9'd290 : cmd_data = {16'h0DFC, get_edid(profile_select,8'hfc)};
            9'd291 : cmd_data = {16'h0DFD, get_edid(profile_select,8'hfd)};
            9'd292 : cmd_data = {16'h0DFE, get_edid(profile_select,8'hfe)};
            9'd293 : cmd_data = {16'h0DFF, get_edid(profile_select,8'hff)};
            9'd294 : cmd_data = {16'h000C, 8'h00};
            9'd295 : cmd_data = {16'h000A, 8'h04};
            9'd296 : cmd_data = {16'h2000, 8'h0F};
            9'd297 : cmd_data = {16'h2001, 8'h00};
            9'd298 : cmd_data = {16'h2002, 8'h00};
            9'd299 : cmd_data = {16'h2003, 8'h01}; 
            
            9'd300 : cmd_data = {16'h209C, 8'h00};
            9'd301 : cmd_data = {16'h209D, 8'h00};
            9'd302 : cmd_data = {16'h209E, 8'h00};
            9'd303 : cmd_data = {16'h209F, 8'h00};
             
            9'd304 : cmd_data = {16'h1010, 8'h01};
            9'd305 : cmd_data = {16'h1024, 8'h00};
            9'd306 : cmd_data = {16'h0200, 8'h00};
            9'd307 : cmd_data = {16'h1024, 8'h70};
            9'd308 : cmd_data = {16'h0200, 8'h07};
            9'd309 : cmd_data = {16'h0215, 8'h01};
            9'd310 : cmd_data = {16'h0215, 8'h00};
            default: cmd_data=24'd0;
       endcase 
    end
endfunction
    //===========================================================================
    //  MS7210 driver control FSM
    //===========================================================================
    parameter    IDLE   = 7'b000_0001;
    parameter    CONECT = 7'b000_0010;
    parameter    INIT   = 7'b000_0100;
    parameter    WAIT   = 7'b000_1000;
    parameter    STA_RD = 7'b001_0000;
    parameter    SETING = 7'b010_0000;
    parameter    RD_BAK = 7'b100_0000;
    reg [ 6:0]   state/*synthesis PAP_MARK_DEBUG="true"*/;
    reg [ 6:0]   state_n;
    reg [ 8:0]   dri_cnt;
    reg [23:0]   delay_cnt;
    reg [ 8:0]   cmd_index/*synthesis PAP_MARK_DEBUG="true"*/;
    reg [31:0]   freq_rec/*synthesis PAP_MARK_DEBUG="true"*/;
    reg [31:0]   freq_rec_1d/*synthesis PAP_MARK_DEBUG="true"*/;
    reg [31:0]   freq_rec_2d/*synthesis PAP_MARK_DEBUG="true"*/;

    reg          busy_1d;
    wire         busy_falling;
    reg edid_done;
    assign edid_written=edid_done;
    assign debug_state=state;
    assign debug_index=cmd_index;
    assign debug_frequency=freq_rec;
    always @(posedge clk)
      if(!rstn)edid_done<=0;
      else if(state==INIT && dri_cnt==299 && busy_falling)edid_done<=1;
    
    assign busy_falling = ((~busy) & busy_1d);
    always @(posedge clk)
    begin
        busy_1d <= busy;
        
//        if(state_n ==STA_RD && dri_cnt == 9'd3 && byte_over)
//        begin
            freq_rec_1d <= freq_rec;
//        end
        
        if(state_n ==STA_RD && dri_cnt == 9'd2 && busy_falling)
        begin
            freq_rec_2d <= freq_rec_1d;
        end
    end
    
    reg [1:0] last_receiver_status;
    always @(posedge clk)
      if(!rstn)last_receiver_status<=2'b00;
      else if(state == STA_RD && dri_cnt == 9'd2 && busy_falling)
        last_receiver_status<=data_out[1:0];
    reg freq_ensure/*synthesis PAP_MARK_DEBUG="true"*/;
//    assign freq_ensure = (freq_rec_1d[17:16]==2'b00) && (freq_rec[17:16] == 2'b10);
    
    always @(posedge clk)
    begin
    	if(!rstn)
    	    freq_ensure <= 1'b0;
    	else if(state_n == SETING)
    	    freq_ensure <= 1'b0;
    	else if(state == STA_RD && dri_cnt == 9'd2 && busy_falling && data_out[1] && (!init_over || !last_receiver_status[1] || (!data_out[0] && last_receiver_status[0])))
    	    freq_ensure <= 1'b1;
        else
            freq_ensure <= freq_ensure;
    end
    //===========================================================================
    //  MS7210 driver control FSM    First Step
    always @(posedge clk)
    begin
        if(!rstn)
            state <= IDLE;
        else
            state <= state_n;
    end
    
    //===========================================================================
    //  MS7210 driver control FSM    Second Step
    always @(*)
    begin
        state_n = state;
        case(state)
            IDLE     : begin   //000_0001
                state_n = CONECT;
            end
            CONECT   : begin   //000_0010
                if(dri_cnt == 5'd1 && busy_falling && data_out == 8'h5A)//)//
                    state_n = INIT;
                else
                    state_n = state;
            end
            INIT     : begin   //000_0100
                if(dri_cnt == 9'd299 && busy_falling)
                    state_n = STA_RD;//WAIT;
                else
                    state_n = state;
            end
            WAIT     : begin   //000_1000
                if(delay_cnt == 24'h989680)//)//
                    state_n = STA_RD;//RD_BAK;//SETING;//
                else
                    state_n = state;
            end
            STA_RD   : begin   //001_0000
                if(dri_cnt == 9'd3 && busy_falling && freq_ensure)//freq_rec[15:0] > 16'h5000)
                    state_n = SETING;//WAIT;//
                else
                    state_n = state;
            end
            SETING   : begin   //010_0000
                if(dri_cnt == 5'd6 && busy_falling)
                    state_n = STA_RD;
                else
                    state_n = state;
            end
            RD_BAK     : begin   //100_0000
                if(dri_cnt == 9'd299 && busy_falling)
                    state_n = WAIT;
                else
                    state_n = state;
            end
            default  : begin
                state_n = IDLE;
            end
        endcase
    end
    
    //===========================================================================
    //  MS7210 driver control FSM    Third Step
    always @(posedge clk)
    begin
        if(!rstn)
            dri_cnt <= 5'd0;
        else
        begin
            case(state)
                IDLE     ,
                WAIT     : dri_cnt <= 5'd0;
                CONECT   : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == 5'd1)
                            dri_cnt <= 5'd0;
                        else
                            dri_cnt <= dri_cnt + 5'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                INIT     : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == 9'd299)
                            dri_cnt <= 5'd0;
                        else
                            dri_cnt <= dri_cnt + 5'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                STA_RD   : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == 5'd3)
                            dri_cnt <= 5'd0;
                        else
                            dri_cnt <= dri_cnt + 5'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                SETING   : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == 5'd6)
                            dri_cnt <= 5'd0;
                        else
                            dri_cnt <= dri_cnt + 5'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                RD_BAK   : begin
                    if(busy_falling)
                    begin
                        if(dri_cnt == 9'd299)
                            dri_cnt <= 5'd0;
                        else
                            dri_cnt <= dri_cnt + 5'd1;
                    end
                    else
                        dri_cnt <= dri_cnt;
                end
                default  : dri_cnt <= 5'd0;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(state == WAIT)
        begin
            if(delay_cnt == 24'h989680)//)//
                delay_cnt <= 22'd0;
            else
                delay_cnt <= delay_cnt + 22'd1;
        end
        else
            delay_cnt <= 22'd0;
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            iic_trig <= 1'd0;
        else
        begin
            case(state)
                IDLE     : iic_trig <= 1'b1;
                WAIT     : iic_trig <= (delay_cnt == 24'h989680);//);//
                CONECT   ,
                INIT     ,
                SETING   ,
                RD_BAK   ,
                STA_RD   : iic_trig <= busy_falling;
                default  : iic_trig <= 1'd0;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            w_r <= 1'd1;
        else
        begin
            case(state)
                IDLE     : w_r <= 1'b1;
                CONECT   : begin
                    if(dri_cnt == 5'd0 && busy_falling)
                        w_r <= 1'b0;
                    else if(dri_cnt == 5'd1 && busy_falling)
                        w_r <= 1'b1;
                    else
                        w_r <= w_r;
                end
                INIT     : begin
                    if(dri_cnt == 9'd299 && busy_falling)
                        w_r <= 1'b0;
                    else
                        w_r <= w_r;
                end
                STA_RD   : begin
                    if(dri_cnt == 9'd3 && busy_falling && freq_ensure)//freq_rec[15:0] > 16'h5000)
                        w_r <= 1'b1;
                    else
                        w_r <= w_r;
                end
                RD_BAK   ,
                WAIT     : w_r <= w_r;
                SETING   : begin
                    if(dri_cnt == 5'd6 && busy_falling)
                        w_r <= 1'b0;
                    else
                        w_r <= w_r;
                end
                default  : w_r <= 1'b1;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            cmd_index <= 6'd0;
        else
        begin
            case(state)
                IDLE     : cmd_index <= 6'd0;
                CONECT   : cmd_index <= 6'd0;
                INIT     : begin
                    if(byte_over)
                    begin
//                    	if(dri_cnt == 9'd299)
//                    	    cmd_index <= cmd_index - 4'd6;
//                    	else
                            cmd_index <= cmd_index + 1'b1;
                    end
                    else
                        cmd_index <= cmd_index;
                end
                WAIT     : cmd_index <= cmd_index;
                RD_BAK   :begin
//                    if(byte_over)
//                        cmd_index <= cmd_index + 1'b1;
//                    else
                        cmd_index <= cmd_index;
                end
                SETING   ,
                STA_RD   : begin
//                	if(byte_over)
//                	begin
//                		if(dri_cnt == 9'd3 && freq_rec[15:0] == 0)
//                		    cmd_index <= cmd_index - 3'd3;
//                		else
//                            cmd_index <= cmd_index + 1'b1;
//                    end
//                    else
                        cmd_index <= cmd_index;
                end
                default  : cmd_index <= 6'd0;
            endcase
        end
    end
    
    always @(posedge clk)
    begin
        if(!rstn)
            freq_rec <= 31'd0;
        else
        begin
            case(state)
                IDLE     ,
                INIT     ,
                WAIT     ,
                RD_BAK   ,
                CONECT   : freq_rec <= freq_rec;
                STA_RD   : begin
                	if(byte_over)
                	begin
                		case(dri_cnt)
                			9'd0    : freq_rec <= {freq_rec[31:8],data_out};
                			9'd1    : freq_rec <= {freq_rec[31:16],data_out,freq_rec[7:0]};
                			9'd2    : freq_rec <= {freq_rec[31:24],data_out,freq_rec[15:0]};
                			9'd3    : freq_rec <= {data_out,freq_rec[23:0]};
                			default : freq_rec <= freq_rec;
                	    endcase
                	end
                	else
                	    freq_rec <= freq_rec;
                end
                SETING   : freq_rec <= freq_rec;
                default  : freq_rec <= 6'd0;
            endcase
        end
    end
    
    reg [23:0] cmd_iic;
    always@(posedge clk)
	begin
		if(~rstn)
			cmd_iic <= 0;
		else if(state == IDLE)
			cmd_iic <= 24'd0;
        else //if(state == WAIT || state == SETING)
            cmd_iic <= cmd_data(cmd_index);
	end
    
    always @(posedge clk)
    begin
        if(!rstn)
        begin
            addr    <= 16'd0;
            data_in <= 8'd0;
        end
        else
        begin
            case(state)
                IDLE     : begin
                    addr    <= 16'h0003;
                    data_in <= 8'h5A;
                end
                CONECT   : begin
                    if(dri_cnt == 5'd1 && busy_falling && data_out == 8'h5A)
                    begin
                        addr    <= cmd_iic[23:8];
                        data_in <= cmd_iic[ 7:0];
                    end
                    else
                    begin
                        addr    <= addr;
                        data_in <= data_in;
                    end
                end
                INIT     ,
                WAIT     ,
                RD_BAK   :begin
                	addr    <= cmd_iic[23:8];
                    data_in <= cmd_iic[ 7:0];
                end
                STA_RD   :begin
                	case(dri_cnt)
                		9'd0   : begin
                			addr    <= 16'h209C;
                            data_in <= 8'h00;
                		end
                		9'd1   : begin
                			addr    <= 16'h209D;
                            data_in <= 8'h00;
                		end
                		9'd2   : begin
                			addr    <= 16'h209E;
                            data_in <= 8'h00;
                		end
                		9'd3   : begin
                			addr    <= 16'h209F;
                            data_in <= 8'h00;
                		end
                		default: begin
                			addr    <= 0;
                            data_in <= 0;
                		end
                    endcase
                end
                SETING   : begin
                	case(dri_cnt)
                		9'd0   : begin
                			addr    <= 16'h1010;
                            data_in <= 8'h01;
                		end
                		9'd1   : begin
                			addr    <= 16'h1024;
                            data_in <= 8'h00;
                		end
                		9'd2   : begin
                			addr    <= 16'h0200;
                            data_in <= 8'h0;
                		end
                		9'd3   : begin
                			addr    <= 16'h1024;
                            data_in <= 8'h70;
                		end
                		9'd4   : begin
                			addr    <= 16'h0200;
                            data_in <= 8'h07;
                		end
                		9'd5   : begin
                			addr    <= 16'h0215;
                            data_in <= 8'h01;
                		end
                		9'd6   : begin
                			addr    <= 16'h0215;
                            data_in <= 8'h00;
                		end
                		default: begin
                			addr    <= 16'h0215;
                            data_in <= 8'h00;
                		end
                    endcase
                end
                default  : begin
                    addr    <= 0;
                    data_in <= 0;
                end
            endcase
        end
    end

    always @(posedge clk)
    begin
    	if(!rstn)
    	    init_over <= 1'b0;
    	else if(state == SETING && dri_cnt == 5'd6 && busy_falling)
    	    init_over <= 1'b1;
    	else
    	    init_over <= init_over;
    end

endmodule
