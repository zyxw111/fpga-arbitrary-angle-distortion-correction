// GROUP=0: existing color bars, algorithm bypass.
// GROUP=1: synthetic distorted camera image; VIEW=0 raw, VIEW=1 corrected.
// Corrected output uses the project's actual warp/coord/addr/bilin modules.
// Procedural four-neighbour access is specific to the synthetic image and
// does not implement a random-read cache for physical camera frames.
module demo #(
 parameter integer WIDTH=1920,HEIGHT=1080,H_TOTAL=2200,V_TOTAL=1125,
 parameter integer GROUP=0,VIEW=1
)(input clk,input rst_n,input enable,
 output valid,output [15:0] pixel,output [11:0] x,y,
 output sof,output sol,output [31:0] frame_id);
 wire v,sf,sl;wire [15:0] p;wire [11:0] px,py;wire [31:0] fid;
 pat #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.H_TOTAL(H_TOTAL),.V_TOTAL(V_TOTAL)) raster(
 .clk(clk),.rst_n(rst_n),.enable(enable),.valid(v),.pixel(p),
 .x(px),.y(py),.sof(sf),.sol(sl),.frame_id(fid));
 generate if(GROUP==0) begin:bars
  // Bottom ramp lets the existing ARM signal-variety heuristic recognize bars.
  wire [15:0] ramp={px[4:0],px[5:0],px[4:0]};
  assign valid=v;assign pixel=(WIDTH>=128 && HEIGHT>=80 && py>=HEIGHT*3/4)?ramp:p;
  assign x=px;assign y=py;
  assign sof=sf;assign sol=sl;assign frame_id=fid;
 end else begin:synthetic
  wire active_rst=rst_n && enable;
  wire ov;wire [15:0] op;wire [11:0] ox,oy;
  reg [31:0] output_frame;
  if(VIEW==0)begin:raw
   chart #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) image(
    .clk(clk),.rst_n(active_rst),.in_valid(v),.in_x(px),.in_y(py),
    .out_valid(ov),.pixel(op),.out_x(ox),.out_y(oy));
  end else begin:corrected
   localparam integer FB=$clog2(WIDTH);
   wire rd;wire [31:0] a0,a1,a2,a3;
   wire [3:0] mask;wire [11:0] dx,dy,rx,ry;
   wire cv;wire [15:0] c0,c1,c2,c3;
   wire [11:0] ax0=a0%WIDTH,ay0=a0/WIDTH,ax1=a1%WIDTH,ay1=a1/WIDTH;
   wire [11:0] ax2=a2%WIDTH,ay2=a2/WIDTH,ax3=a3%WIDTH,ay3=a3/WIDTH;
   wire [11:0] unused_x,unused_y;
   reg [3:0] masks[0:7];
   reg [11:0] dxs[0:7],dys[0:7],xs[0:7],ys[0:7];
   integer i;
   warp #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) algorithm(
    .clk(clk),.rst_n(active_rst),.in_valid(v),.in_x(px),.in_y(py),
    .fx_q12(32'sd1 << (FB+12)),.fy_q12(32'sd1 << (FB+12)),
    .cx_q12((WIDTH/2)*4096),.cy_q12((HEIGHT/2)*4096),
    .inv_fx_q30(32'sd1 << (30-FB)),.inv_fy_q30(32'sd1 << (30-FB)),
    .k1_q30(-32'sd268435456),.k2_q30(32'sd0),.p1_q30(32'sd0),.p2_q30(32'sd0),
    .rd_valid(rd),.rd_a00(a0),.rd_a01(a1),.rd_a10(a2),.rd_a11(a3),
    .rd_mask(mask),.rd_dx(dx),.rd_dy(dy),.rd_x(rx),.rd_y(ry),
    .rsp_valid(cv),.rsp_p00(c0),.rsp_p01(c1),.rsp_p10(c2),.rsp_p11(c3),
    .rsp_mask(masks[7]),.rsp_dx(dxs[7]),.rsp_dy(dys[7]),.rsp_x(xs[7]),.rsp_y(ys[7]),
    .out_valid(ov),.out_pixel(op),.out_x(ox),.out_y(oy));
   chart #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) reader0(.clk(clk),.rst_n(active_rst),
    .in_valid(rd),.in_x(ax0),.in_y(ay0),
    .out_valid(cv),.pixel(c0),.out_x(unused_x),.out_y(unused_y));
   chart #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) reader1(.clk(clk),.rst_n(active_rst),
    .in_valid(rd),.in_x(ax1),.in_y(ay1),.pixel(c1));
   chart #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) reader2(.clk(clk),.rst_n(active_rst),
    .in_valid(rd),.in_x(ax2),.in_y(ay2),.pixel(c2));
   chart #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) reader3(.clk(clk),.rst_n(active_rst),
    .in_valid(rd),.in_x(ax3),.in_y(ay3),.pixel(c3));
   always @(posedge clk or negedge active_rst)begin
    if(!active_rst)for(i=0;i<8;i=i+1)begin
     masks[i]<=0;dxs[i]<=0;dys[i]<=0;xs[i]<=0;ys[i]<=0;
    end else begin
     masks[0]<=mask;dxs[0]<=dx;dys[0]<=dy;xs[0]<=rx;ys[0]<=ry;
     for(i=1;i<8;i=i+1)begin masks[i]<=masks[i-1];dxs[i]<=dxs[i-1];
      dys[i]<=dys[i-1];xs[i]<=xs[i-1];ys[i]<=ys[i-1];end
    end
   end
  end
  always @(posedge clk or negedge active_rst)
   if(!active_rst)output_frame<=0;
   else if(ov && ox==WIDTH-1 && oy==HEIGHT-1)output_frame<=output_frame+1'b1;
  assign valid=ov;assign pixel=op;assign x=ox;assign y=oy;
  assign sof=ov && ox==0 && oy==0;assign sol=ov && ox==0;
  assign frame_id=output_frame;
 end endgenerate
endmodule
