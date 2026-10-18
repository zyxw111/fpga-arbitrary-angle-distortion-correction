// All three sources share the same stream/DDR/DMA pipeline. Mode is held
// constant from reset release until the current frame and DMA have drained.
module demo_select #(
 parameter integer WIDTH=640,HEIGHT=400,H_TOTAL=800,V_TOTAL=450
)(input clk,input rst_n,input enable,input [1:0] mode,
 output valid,output [15:0] pixel,output [11:0] x,y,
 output sof,output sol,output [31:0] frame_id);
 wire [2:0] v,sf,sl;wire [47:0] p;wire [35:0] px,py;wire [95:0] fid;
 genvar i;
 generate for(i=0;i<3;i=i+1)begin:images
  demo #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL),.V_TOTAL(V_TOTAL),
   .GROUP(i==0?0:1),.VIEW(i==1?0:1)) image(
   .clk(clk),.rst_n(rst_n),.enable(enable && mode==i),
   .valid(v[i]),.pixel(p[i*16+:16]),.x(px[i*12+:12]),.y(py[i*12+:12]),
   .sof(sf[i]),.sol(sl[i]),.frame_id(fid[i*32+:32]));
 end endgenerate
 assign valid=v[mode];assign pixel=p[mode*16+:16];
 assign x=px[mode*12+:12];assign y=py[mode*12+:12];
 assign sof=sf[mode];assign sol=sl[mode];assign frame_id=fid[mode*32+:32];
endmodule
