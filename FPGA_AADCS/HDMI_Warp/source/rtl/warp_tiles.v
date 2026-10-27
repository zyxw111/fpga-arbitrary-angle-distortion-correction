// Double-buffered 32x8 output tiles. XY maps are precomputed in DDR; source
// bounding rectangles are burst-loaded into four parity-banked scratch RAMs.
// One bilinear output pixel per clock while the next tile is being loaded.
module warp_tiles #(parameter [27:0] LUT_BASE=28'h2000000)(
 input clk,rst_n,start,input [15:0] width,height,
 input [27:0] source_base,output_base,
 output ready,output reg done,output reg [7:0] error,output reg [31:0] checksum,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,rlast,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,wlast);
 // Register DDR returns before cache control. Native same-cycle first data
 // becomes valid in L_DATA on the following cycle, including RLAST.
 reg [127:0] read_data_q;reg read_valid_q,read_last_q;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin read_data_q<=0;read_valid_q<=0;read_last_q<=0;end
 else begin
  read_valid_q<=rvalid;read_last_q<=rlast;
  if(rvalid)read_data_q<=rdata;
 end
 reg running;
 reg [127:0] maps[0:255];
 reg [127:0] bank0[0:4095],bank1[0:4095],bank2[0:4095],bank3[0:4095];
 reg [1:0] published,ack;
 reg [15:0] tile_x[0:1],tile_y[0:1],box_word[0:1],box_y[0:1];
 localparam L_IDLE=0,L_WAIT=1,L_MAP_START=2,L_MAP=3,L_DRAIN=4,L_BOX=5,L_ROW=6,
            L_SOURCE_START=7,L_SOURCE=8,L_PUBLISH=9,L_DONE=10;
 reg [3:0] ls;reg lb,is_map;
 reg [15:0] lx,ly,xmin,xmax,ymin,ymax,word_start,word_span;
 reg any_pixel;reg [31:0] tile_number;
 reg [27:0] job_base,job_stride,row_base_bytes;
 reg [8:0] job_words;reg [7:0] job_rows;
 wire receive,fetch_ready,fetch_done;wire [7:0] fetch_error,fetch_row,fetch_column;
 wire [127:0] fetch_data;
 tile_fetch reader(.clk(clk),.rst_n(rst_n),.start((ls==L_MAP_START || ls==L_SOURCE_START) && fetch_ready),
  .ready(fetch_ready),.base(job_base),.stride(job_stride),.words(job_words),.rows(job_rows),
  .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
  .rdata(read_data_q),.rvalid(read_valid_q),.rlast(read_last_q),
  .valid(receive),.data(fetch_data),.row(fetch_row),.column(fetch_column),.done(fetch_done),.error(fetch_error));
 wire signed [31:0] xx0=$signed(fetch_data[31:0])>>>12, yy0=$signed(fetch_data[63:32])>>>12;
 wire signed [31:0] xx1=$signed(fetch_data[95:64])>>>12, yy1=$signed(fetch_data[127:96])>>>12;
 wire ok0=xx0>=-1 && xx0<$signed({1'b0,width}) && yy0>=-1 && yy0<$signed({1'b0,height});
 wire ok1=xx1>=-1 && xx1<$signed({1'b0,width}) && yy1>=-1 && yy1<$signed({1'b0,height});
 wire [15:0] xlo0=xx0<0?16'd0:xx0[15:0],xlo1=xx1<0?16'd0:xx1[15:0];
 wire [15:0] ylo0=yy0<0?16'd0:yy0[15:0],ylo1=yy1<0?16'd0:yy1[15:0];
 wire [15:0] xhi0=xx0+1>=width?width-1:xx0+1,xhi1=xx1+1>=width?width-1:xx1+1;
 wire [15:0] yhi0=yy0+1>=height?height-1:yy0+1,yhi1=yy1+1>=height?height-1:yy1+1;
 wire [15:0] low_x=!ok0?xlo1:!ok1?xlo0:(xlo0<xlo1?xlo0:xlo1);
 wire [15:0] low_y=!ok0?ylo1:!ok1?ylo0:(ylo0<ylo1?ylo0:ylo1);
 wire [15:0] high_x=!ok0?xhi1:!ok1?xhi0:(xhi0>xhi1?xhi0:xhi1);
 wire [15:0] high_y=!ok0?yhi1:!ok1?yhi0:(yhi0>yhi1?yhi0:yhi1);
 wire [1:0] write_bank={fetch_row[0],fetch_column[0]};
 wire [11:0] write_index={lb,fetch_row[6:1],fetch_column[5:1]};
 always @(posedge clk)begin
  if(receive && is_map)maps[{lb,fetch_column[6:0]}]<=fetch_data;
  if(receive && !is_map)case(write_bank)
   0:bank0[write_index]<=fetch_data;1:bank1[write_index]<=fetch_data;
   2:bank2[write_index]<=fetch_data;3:bank3[write_index]<=fetch_data;
  endcase
 end
 reg pair_valid;reg [15:0] pair_low_x,pair_low_y,pair_high_x,pair_high_y;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin pair_valid<=0;pair_low_x<=0;pair_low_y<=0;pair_high_x<=0;pair_high_y<=0;end
 else begin
  pair_valid<=receive && is_map && (ok0 || ok1);
  pair_low_x<=low_x;pair_low_y<=low_y;pair_high_x<=high_x;pair_high_y<=high_y;
 end
 reg [7:0] load_error;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  ls<=L_IDLE;lb<=0;lx<=0;ly<=0;tile_number<=0;published<=0;load_error<=0;
  xmin<=0;xmax<=0;ymin<=0;ymax<=0;any_pixel<=0;word_start<=0;word_span<=0;is_map<=0;
  job_base<=0;job_stride<=0;job_words<=0;job_rows<=0;row_base_bytes<=0;
  tile_x[0]<=0;tile_x[1]<=0;tile_y[0]<=0;tile_y[1]<=0;
  box_word[0]<=0;box_word[1]<=0;box_y[0]<=0;box_y[1]<=0;
 end else begin
  if(fetch_error!=0)begin load_error<=fetch_error;ls<=L_DONE;end
  else if(start && ready)begin ls<=L_WAIT;lb<=0;lx<=0;ly<=0;tile_number<=0;published<=0;load_error<=0;end
  else case(ls)
   L_WAIT:if(published[lb]==ack[lb])begin
    xmin<=16'hffff;ymin<=16'hffff;xmax<=0;ymax<=0;any_pixel<=0;
    tile_x[lb]<=lx;tile_y[lb]<=ly;
    job_base<=LUT_BASE+(tile_number<<11);job_words<=128;job_rows<=1;job_stride<=0;
    is_map<=1;ls<=L_MAP_START;
   end
   L_MAP_START:if(fetch_ready)ls<=L_MAP;
   L_MAP:if(fetch_done)ls<=L_DRAIN;
   L_DRAIN:ls<=L_BOX;
   L_BOX:begin
    box_word[lb]<=xmin>>3;box_y[lb]<=ymin;
    word_start<=xmin>>3;word_span<=(xmax>>3)-(xmin>>3)+1;
    row_base_bytes<=ymin*width*2;job_rows<=ymax-ymin+1;
    if(!any_pixel)ls<=L_PUBLISH;
    else if((xmax>>3)-(xmin>>3)>=64 || ymax-ymin>=128)begin load_error<=8'h31;ls<=L_DONE;end
    else ls<=L_ROW;
   end
   L_ROW:begin
    job_base<=source_base+row_base_bytes+(word_start<<4);job_words<=word_span;
    job_stride<={11'd0,width,1'b0};is_map<=0;ls<=L_SOURCE_START;
   end
   L_SOURCE_START:if(fetch_ready)ls<=L_SOURCE;
   L_SOURCE:if(fetch_done)ls<=L_PUBLISH;
   L_PUBLISH:begin
    published[lb]<=!published[lb];lb<=!lb;tile_number<=tile_number+1'b1;
    if(lx+32>=width)begin lx<=0;ly<=ly+8;if(ly+8>=height)ls<=L_DONE;else ls<=L_WAIT;end
    else begin lx<=lx+32;ls<=L_WAIT;end
   end
   L_DONE:if(!running)ls<=L_IDLE;
  endcase
  if(pair_valid)begin
   any_pixel<=1;
   if(pair_low_x<xmin)xmin<=pair_low_x;if(pair_low_y<ymin)ymin<=pair_low_y;
   if(pair_high_x>xmax)xmax<=pair_high_x;if(pair_high_y>ymax)ymax<=pair_high_y;
  end
 end

 localparam R_IDLE=0,R_WAIT=1,R_SCAN=2,R_DRAIN=3,R_AW=4,R_W=5;
 reg [2:0] rs;reg rb;
 reg [8:0] issue_count,result_count,pixel_total;
 reg [2:0] output_row;reg [1:0] output_word;
 reg [127:0] output_words[0:31];reg [111:0] partial;
 reg [127:0] coord_q;reg coord_lane,v1,v2,v3,v4;
 wire [63:0] coord=coord_lane?coord_q[127:64]:coord_q[63:0];
 wire signed [31:0] sx=$signed(coord[31:0])>>>12,sy=$signed(coord[63:32])>>>12;
 wire [15:0] local_y=sy-box_y[rb],local_word=(sx>>>3)-box_word[rb];
 wire [15:0] next_word=((sx+1)>>>3)-box_word[rb];
 wire [15:0] next_y=local_y+1'b1;
 wire [3:0] sample_mask={sx>=-1 && sx<$signed({1'b0,width})-1 && sy>=-1 && sy<$signed({1'b0,height})-1,
  sx>=0 && sx<$signed({1'b0,width}) && sy>=-1 && sy<$signed({1'b0,height})-1,
  sx>=-1 && sx<$signed({1'b0,width})-1 && sy>=0 && sy<$signed({1'b0,height}),
  sx>=0 && sx<$signed({1'b0,width}) && sy>=0 && sy<$signed({1'b0,height})};
 wire [7:0] selectors={{next_y[0],next_word[0]},{next_y[0],local_word[0]},
                       {local_y[0],next_word[0]},{local_y[0],local_word[0]}};
 wire [47:0] indices={{rb,next_y[6:1],next_word[5:1]},{rb,next_y[6:1],local_word[5:1]},
                     {rb,local_y[6:1],next_word[5:1]},{rb,local_y[6:1],local_word[5:1]}};
 reg [11:0] address0,address1,address2,address3;
 integer j,k;
 always @*begin
  address0=0;address1=0;address2=0;address3=0;
  for(j=0;j<4;j=j+1)if(sample_mask[j])case(selectors[j*2+:2])
   0:address0=indices[j*12+:12];1:address1=indices[j*12+:12];
   2:address2=indices[j*12+:12];3:address3=indices[j*12+:12];
  endcase
 end
 reg [11:0] ram_address0,ram_address1,ram_address2,ram_address3;
 reg [127:0] data0,data1,data2,data3;
 reg [7:0] selectors_q,selectors_d;reg [3:0] mask_q,mask_d;
 reg [2:0] lane0,lane1,lane0_d,lane1_d;reg [11:0] dx_q,dy_q,dx_d,dy_d,dx_s3,dy_s3;
 reg [15:0] samples[0:3];
 function [127:0] select_data;
 input [1:0] n;
 begin case(n)0:select_data=data0;1:select_data=data1;2:select_data=data2;3:select_data=data3;endcase end
 endfunction
 wire interp_valid;wire [15:0] interp_pixel;
 bilin interpolate(.clk(clk),.rst_n(rst_n),.in_valid(v4),
  .p00(samples[0]),.p01(samples[1]),.p10(samples[2]),.p11(samples[3]),
  .dx(dx_s3),.dy(dy_s3),.out_valid(interp_valid),.pixel(interp_pixel));
 always @(posedge clk)begin
  coord_q<=maps[{rb,issue_count[7:1]}];
  ram_address0<=address0;ram_address1<=address1;ram_address2<=address2;ram_address3<=address3;
  data0<=bank0[ram_address0];data1<=bank1[ram_address1];data2<=bank2[ram_address2];data3<=bank3[ram_address3];
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  coord_lane<=0;v1<=0;v2<=0;v3<=0;v4<=0;selectors_d<=0;mask_d<=0;lane0_d<=0;lane1_d<=0;dx_d<=0;dy_d<=0;selectors_q<=0;mask_q<=0;lane0<=0;lane1<=0;
  dx_q<=0;dy_q<=0;dx_s3<=0;dy_s3<=0;
  for(k=0;k<4;k=k+1)samples[k]<=0;
 end else begin
  coord_lane<=issue_count[0];v1<=rs==R_SCAN;v2<=v1;v3<=v2;v4<=v3;
  selectors_q<=selectors;mask_q<=sample_mask;lane0<=sx[2:0];lane1<=sx[2:0]+1'b1;
  dx_q<=coord[11:0];dy_q<=coord[43:32];dx_d<=dx_q;dy_d<=dy_q;dx_s3<=dx_d;dy_s3<=dy_d;
  selectors_d<=selectors_q;mask_d<=mask_q;lane0_d<=lane0;lane1_d<=lane1;
  for(k=0;k<4;k=k+1)samples[k]<=mask_d[k]?(select_data(selectors_d[k*2+:2])>>(16*(k[0]?lane1_d:lane0_d))):128'd0;
 end
 assign ready=!running && ls==L_IDLE && rs==R_IDLE && error==0;
 assign awvalid=rs==R_AW;
 assign awaddr=output_base+(tile_y[rb]+output_row)*width*2+tile_x[rb]*2;
 assign awlen=3;
 assign wdata=output_words[{output_row,output_word}];
 assign wstrb=(rs==R_AW || rs==R_W)?16'hffff:16'h0000;
 function [31:0] mix;
 input [127:0] d;
 begin mix=d[31:0]^{d[62:32],d[63]}^{d[92:64],d[95:93]}^{d[120:96],d[127:121]};end
 endfunction
 // The CAM2 checksum is linear. Rotate each word by its final raster position
 // so tile-order writes produce exactly the existing scan-order checksum.
 wire [127:0] complete_word={interp_pixel,partial};
 wire [31:0] hash_word=mix(complete_word);
 // Only the position modulo 32 affects the rotation. Width is a multiple
 // of 32, so width/8 is exact and the full raster product is unnecessary.
 wire [4:0] stride_mod=width[7:3];
 wire [4:0] total_mod=stride_mod*height[4:0];
 wire [4:0] row_mod=tile_y[rb][4:0]+result_count[7:5];
 wire [4:0] raster_mod=row_mod*stride_mod+tile_x[rb][7:3]+result_count[4:3];
 wire [4:0] rotate_amount=(total_mod-5'd1-raster_mod)*5'd5;
 reg hash_valid;reg [31:0] hash_word_q;reg [4:0] rotate_q;
 wire [31:0] hash_term=(hash_word_q<<rotate_q)|(hash_word_q>>(32-rotate_q));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin hash_valid<=0;hash_word_q<=0;rotate_q<=0;end
 else begin
  hash_valid<=interp_valid && result_count[2:0]==7;
  if(interp_valid && result_count[2:0]==7)begin hash_word_q<=hash_word;rotate_q<=rotate_amount;end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  running<=0;done<=0;error<=0;checksum<=0;rs<=R_IDLE;rb<=0;ack<=0;
  issue_count<=0;result_count<=0;pixel_total<=0;output_row<=0;output_word<=0;partial<=0;
 end else begin
  done<=0;
  if(hash_valid)checksum<=checksum^hash_term;
  if(load_error!=0)error<=load_error;
  if(start && ready)begin running<=1;rs<=R_WAIT;rb<=0;ack<=0;checksum<=0;end
  else case(rs)
   R_WAIT:if(published[rb]!=ack[rb])begin
    issue_count<=0;result_count<=0;partial<=0;
    pixel_total<=((tile_y[rb]+8<=height)?9'd256:((height-tile_y[rb])<<5));rs<=R_SCAN;
   end
   R_SCAN:begin issue_count<=issue_count+1'b1;if(issue_count+1==pixel_total)rs<=R_DRAIN;end
   R_DRAIN:if(interp_valid && result_count+1==pixel_total)begin output_row<=0;output_word<=0;rs<=R_AW;end
   R_AW:if(awready)begin
    output_word<=wready?1:0;rs<=R_W;
    if(wready && wlast)error<=8'h33;
   end
   R_W:if(wready)begin
    if(wlast!=(output_word==3))error<=8'h34;
    if(output_word==3)begin
     output_word<=0;
     if({output_row,5'd0}+32==pixel_total)begin
      ack[rb]<=published[rb];rb<=!rb;
      if(tile_x[rb]+32>=width && tile_y[rb]+8>=height)begin rs<=R_IDLE;running<=0;done<=1;end
      else rs<=R_WAIT;
     end else begin output_row<=output_row+1'b1;rs<=R_AW;end
    end else output_word<=output_word+1'b1;
   end
  endcase
  if(interp_valid)begin
   if(result_count[2:0]!=7)partial[result_count[2:0]*16+:16]<=interp_pixel;
   result_count<=result_count+1'b1;
   if(result_count[2:0]==7)begin output_words[result_count[7:3]]<=complete_word;end
  end
 end
endmodule
