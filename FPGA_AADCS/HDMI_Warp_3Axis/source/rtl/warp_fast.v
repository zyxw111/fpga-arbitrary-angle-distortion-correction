// Exact two-pixel Brown/bilinear engine. The original table engine remains an
// independent fallback in hdmi_live. Native DDR protocol and frame ABI match.
module warp_fast #(parameter CACHE_NATIVE_TDP=1,COORD_PIPELINE=1,SAMPLE_PIPELINE=0,BORDER_MIRROR=0)(
 input clk,rst_n,start,input [15:0] width,height,input [543:0] config_bank,input [287:0] projection_h,
 input [27:0] source_base,output_base,
 output ready,output reg done,output reg [7:0] error,output reg [31:0] checksum,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,rlast,
 output awvalid,input awready,output [27:0] awaddr,output [3:0] awlen,
 output [127:0] wdata,output [15:0] wstrb,input wready,wlast,
 output [255:0] tile_perf);
 reg running;reg [1:0] published,ack,map_generated;reg lb,rb,gb;
 reg [15:0] tile_x[0:1],tile_y[0:1],box_word[0:1],box_y[0:1];
 reg [127:0] maps[0:255];
 wire [43:0] read_address0,read_address1;
 wire [511:0] cache_data0[0:1],cache_data1[0:1];
 localparam L_IDLE=0,L_WAIT=1,L_BOX=5,L_SOURCE_START=6,L_SOURCE=7,L_PUBLISH=8,L_DONE=9,L_BASE=10;
 localparam G_IDLE=0,G_WAIT=1,G_GEN=2,G_DRAIN=3,G_FLUSH=4,G_PUBLISH=5,G_DONE=6;
 reg [2:0] gs;
 reg [3:0] ls;reg [15:0] lx,ly,xmin,xmax,ymin,ymax;
 reg any_pixel;reg [6:0] gen_index,map_count;
 reg [15:0] map_xmin[0:1],map_xmax[0:1],map_ymin[0:1],map_ymax[0:1];reg [1:0] map_any,box_rejected;
 wire map_valid0,map_valid1;wire signed [31:0] mx0,my0,mx1,my1;
 wire signed [31:0] raw_mx0,raw_my0,raw_mx1,raw_my1;
 // Reflect complete Q12 coordinates before BOTH bounds reduction and maps RAM.
 // One reflection covers [-L,2L]. Deeper excursions clamp after reflection;
 // this bounded hardware policy avoids a divider/modulo and extra frame RAM.
 function signed [31:0] mirror_q12;
  input signed [31:0] value;
  input [15:0] size;
  reg signed [32:0] limit_q,folded;
  begin
   limit_q=($signed({1'b0,size})-33'sd1)<<<12;
   folded={value[31],value};
   if(size<=1)mirror_q12=0;
   else begin
    if(folded<0)folded=-folded;
    else if(folded>limit_q)folded=(limit_q<<<1)-folded;
    if(folded<0)folded=0;
    if(folded>limit_q)folded=limit_q;
    mirror_q12=folded[31:0];
   end
  end
 endfunction
 wire raw_valid0,raw_valid1,raw_usable0,raw_usable1;
 generate if(BORDER_MIRROR)begin:mirror_pipe
  // Two stages isolate reflection/clamp from bbox reduction; valid follows data.
  reg v1,v2,u10,u11,u20,u21;
  reg signed [32:0] folded_x0,folded_y0,folded_x1,folded_y1;
  reg signed [32:0] limit_x_q,limit_y_q;
  reg signed [31:0] x0_q,y0_q,x1_q,y1_q;
  wire signed [32:0] limit_x=($signed({1'b0,width})-33'sd1)<<<12;
  wire signed [32:0] limit_y=($signed({1'b0,height})-33'sd1)<<<12;
  function signed [32:0] fold_once;
   input signed [31:0] value;input signed [32:0] lim;
   reg signed [32:0] wide;
   begin
    wide={value[31],value};
    fold_once=wide<0?-wide:wide>lim?(lim<<<1)-wide:wide;
   end
  endfunction
  function signed [31:0] clamp_fold;
   input signed [32:0] value,lim;
   begin clamp_fold=lim<=0?0:value<0?0:value>lim?lim[31:0]:value[31:0];end
  endfunction
  always @(posedge clk or negedge rst_n)
   if(!rst_n)begin
    v1<=0;v2<=0;u10<=0;u11<=0;u20<=0;u21<=0;folded_x0<=0;folded_y0<=0;folded_x1<=0;folded_y1<=0;
    limit_x_q<=0;limit_y_q<=0;x0_q<=0;y0_q<=0;x1_q<=0;y1_q<=0;
   end else begin
    v1<=raw_valid0;v2<=v1;u10<=raw_usable0;u11<=raw_usable1;u20<=u10;u21<=u11;
    limit_x_q<=limit_x;limit_y_q<=limit_y;
    folded_x0<=fold_once(raw_mx0,limit_x);folded_y0<=fold_once(raw_my0,limit_y);
    folded_x1<=fold_once(raw_mx1,limit_x);folded_y1<=fold_once(raw_my1,limit_y);
    x0_q<=clamp_fold(folded_x0,limit_x_q);y0_q<=clamp_fold(folded_y0,limit_y_q);
    x1_q<=clamp_fold(folded_x1,limit_x_q);y1_q<=clamp_fold(folded_y1,limit_y_q);
   end
  assign mx0=u20?x0_q:32'sh80000000;assign my0=u20?y0_q:32'sh80000000;assign mx1=u21?x1_q:32'sh80000000;assign my1=u21?y1_q:32'sh80000000;
  assign map_valid0=v2;assign map_valid1=v2;
 end else begin:mirror_bypass
  assign mx0=raw_usable0?raw_mx0:32'sh80000000;assign my0=raw_usable0?raw_my0:32'sh80000000;assign mx1=raw_usable1?raw_mx1:32'sh80000000;assign my1=raw_usable1?raw_my1:32'sh80000000;
  assign map_valid0=raw_valid0;assign map_valid1=raw_valid1;
 end endgenerate
 wire [11:0] gx=lx+{7'd0,gen_index[3:0],1'b0};
 wire [11:0] gy=ly+{9'd0,gen_index[6:4]};
 hdmi_map_h3d_pipe mapper0(.clk(clk),.rst_n(rst_n),.in_valid(gs==G_GEN),.config_bank(config_bank),.projection_h(projection_h),.x(gx),.y(gy),.out_valid(raw_valid0),.out_usable(raw_usable0),.map_x(raw_mx0),.map_y(raw_my0));
 hdmi_map_h3d_pipe mapper1(.clk(clk),.rst_n(rst_n),.in_valid(gs==G_GEN),.config_bank(config_bank),.projection_h(projection_h),.x(gx+12'd1),.y(gy),.out_valid(raw_valid1),.out_usable(raw_usable1),.map_x(raw_mx1),.map_y(raw_my1));
 wire signed [31:0] xx0=mx0>>>12,yy0=my0>>>12,xx1=mx1>>>12,yy1=my1>>>12;
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
 reg pair_valid;reg [15:0] pair_low_x,pair_low_y,pair_high_x,pair_high_y;
 reg [27:0] job_base,job_stride,job_row_offset,job_x_offset;reg [8:0] job_words;reg [7:0] job_rows;
 reg [127:0] read_data_q;reg read_valid_q,read_last_q;
 wire fetch_ready,fetch_done,receive;wire [7:0] fetch_error,fetch_row,fetch_column;wire [127:0] fetch_data;
 tile_fetch reader(.clk(clk),.rst_n(rst_n),.start(ls==L_SOURCE_START && fetch_ready),.ready(fetch_ready),
  .base(job_base),.stride(job_stride),.words(job_words),.rows(job_rows),
  .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
  .rdata(read_data_q),.rvalid(read_valid_q),.rlast(read_last_q),
  .valid(receive),.data(fetch_data),.row(fetch_row),.column(fetch_column),.done(fetch_done),.error(fetch_error));
 wire [1:0] write_bank={fetch_row[0],fetch_column[0]};
 wire [10:0] write_index={fetch_row[6:1],fetch_column[5:1]};
 reg [7:0] cache_write_enable;
 reg [10:0] cache_write_index;
 reg [127:0] cache_write_data;
 genvar b,k;
 generate for(b=0;b<2;b=b+1)begin:tile_cache
  for(k=0;k<4;k=k+1)begin:parity
   // Separate physical RAM for the two tile owners: the loading owner uses
   // port A for writes, while the rendering owner uses both ports for reads.
   warp_dual_cache #(.NATIVE_TDP(CACHE_NATIVE_TDP)) memory(.clk(clk),.we(cache_write_enable[b*4+k]),
    .wa(cache_write_index),.wd(cache_write_data),.re(running && rb==b),
    .ra0(read_address0[k*11+:11]),.ra1(read_address1[k*11+:11]),
    .rd0(cache_data0[b][k*128+:128]),.rd1(cache_data1[b][k*128+:128]));
  end
 end endgenerate
 reg [7:0] load_error;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin read_data_q<=0;read_valid_q<=0;read_last_q<=0;
  cache_write_enable<=0;cache_write_index<=0;cache_write_data<=0;
  pair_valid<=0;pair_low_x<=0;pair_low_y<=0;pair_high_x<=0;pair_high_y<=0;end
 else begin
  read_data_q<=rdata;read_valid_q<=rvalid;read_last_q<=rlast;
  // Break the ARREADY -> immediate-return ownership -> RAM address mux path.
  // L_SOURCE -> L_PUBLISH already leaves two cycles to drain this write stage.
  cache_write_enable<=receive?(8'b1<<{lb,write_bank}):8'd0;
  cache_write_index<=write_index;cache_write_data<=fetch_data;
  pair_valid<=map_valid0 && (ok0 || ok1);
  pair_low_x<=low_x;pair_low_y<=low_y;pair_high_x<=high_x;pair_high_y<=high_y;
 end
 always @(posedge clk)if(map_valid0)maps[{gb,map_count}]<={my1,mx1,my0,mx0};
 // The map producer, source prefetcher and renderer own independent stages.
 // A map slot is reusable only after the renderer ACK, so generating the next
 // map can overlap the previous tile's native DDR return without extra RAM.
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  gs<=G_IDLE;gb<=0;lx<=0;ly<=0;map_generated<=0;gen_index<=0;map_count<=0;
  xmin<=0;ymin<=0;xmax<=0;ymax<=0;any_pixel<=0;map_any<=0;
  map_xmin[0]<=0;map_xmin[1]<=0;map_xmax[0]<=0;map_xmax[1]<=0;
  map_ymin[0]<=0;map_ymin[1]<=0;map_ymax[0]<=0;map_ymax[1]<=0;
  tile_x[0]<=0;tile_x[1]<=0;tile_y[0]<=0;tile_y[1]<=0;
 end else begin
  if(load_error!=0)gs<=G_DONE;
  else if(start && ready)begin gs<=G_WAIT;gb<=0;lx<=0;ly<=0;map_generated<=0;end
  else case(gs)
   G_WAIT:if(map_generated[gb]==ack[gb])begin
    xmin<=16'hffff;ymin<=16'hffff;xmax<=0;ymax<=0;any_pixel<=0;gen_index<=0;map_count<=0;
    tile_x[gb]<=lx;tile_y[gb]<=ly;gs<=G_GEN;
   end
   G_GEN:begin gen_index<=gen_index+1'b1;if(gen_index==127)gs<=G_DRAIN;end
   G_DRAIN:if(map_valid0 && map_count==127)gs<=G_FLUSH;
   G_FLUSH:gs<=G_PUBLISH;
   G_PUBLISH:begin
    map_xmin[gb]<=xmin;map_xmax[gb]<=xmax;map_ymin[gb]<=ymin;map_ymax[gb]<=ymax;map_any[gb]<=any_pixel;
    map_generated[gb]<=!map_generated[gb];gb<=!gb;
    if(lx+32>=width)begin lx<=0;ly<=ly+8;if(ly+8>=height)gs<=G_DONE;else gs<=G_WAIT;end
    else begin lx<=lx+32;gs<=G_WAIT;end
   end
   G_DONE:if(!running)gs<=G_IDLE;
  endcase
  if(map_valid0)map_count<=map_count+1'b1;
  if(pair_valid)begin
   any_pixel<=1;
   if(pair_low_x<xmin)xmin<=pair_low_x;if(pair_low_y<ymin)ymin<=pair_low_y;
   if(pair_high_x>xmax)xmax<=pair_high_x;if(pair_high_y>ymax)ymax<=pair_high_y;
  end
 end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  ls<=L_IDLE;lb<=0;published<=0;load_error<=0;job_base<=0;job_stride<=0;job_row_offset<=0;job_x_offset<=0;job_words<=0;job_rows<=0;
  box_rejected<=0;box_word[0]<=0;box_word[1]<=0;box_y[0]<=0;box_y[1]<=0;
 end else begin
  if(fetch_error!=0)begin load_error<=fetch_error;ls<=L_DONE;end
  else if(start && ready)begin ls<=L_WAIT;lb<=0;published<=0;load_error<=0;end
  else case(ls)
   L_WAIT:if(map_generated[lb]!=published[lb])ls<=L_BOX;
   L_BOX:begin
    box_rejected[lb]<=0;
    box_word[lb]<=map_xmin[lb]>>3;box_y[lb]<=map_ymin[lb];
    job_row_offset<=map_ymin[lb]*width*2;job_x_offset<=((map_xmin[lb]>>3)<<4);
    job_stride<={11'd0,width,1'b0};job_words<=(map_xmax[lb]>>3)-(map_xmin[lb]>>3)+1;job_rows<=map_ymax[lb]-map_ymin[lb]+1;
    if(!map_any[lb])ls<=L_PUBLISH;
    else if((map_xmax[lb]>>3)-(map_xmin[lb]>>3)>=64 || map_ymax[lb]-map_ymin[lb]>=128)begin box_rejected[lb]<=1;ls<=L_PUBLISH;end
    else ls<=L_BASE;
   end
   L_BASE:begin
    job_base<=source_base+job_row_offset+job_x_offset;ls<=L_SOURCE_START;
   end
   L_SOURCE_START:if(fetch_ready)ls<=L_SOURCE;
   L_SOURCE:if(fetch_done)ls<=L_PUBLISH;
   L_PUBLISH:begin
    published[lb]<=map_generated[lb];lb<=!lb;
    if(tile_x[lb]+32>=width && tile_y[lb]+8>=height)ls<=L_DONE;else ls<=L_WAIT;
   end
   L_DONE:if(!running)ls<=L_IDLE;
  endcase
 end

 localparam R_IDLE=0,R_WAIT=1,R_SCAN=2,R_DRAIN=3,R_FINISH=4;
 reg [2:0] rs;reg [7:0] issue_pairs,result_pairs,total_pairs;
 reg [127:0] coord_q,coord_reg;reg v1,v2,v3,v4,v5,v6,v7;
 // Separate the map BRAM clock-to-output from signed bounds comparisons and
 // parity-bank address routing. COORD_PIPELINE=0 restores the earlier timing.
 wire [127:0] render_coord=COORD_PIPELINE?coord_reg:coord_q;
 wire [31:0] pixels;wire [1:0] interp_valid;
 generate for(k=0;k<2;k=k+1)begin:lane
  wire [63:0] coord=render_coord[k*64+:64];
  wire signed [31:0] sx=$signed(coord[31:0])>>>12,sy=$signed(coord[63:32])>>>12;
  wire [15:0] local_y=sy-box_y[rb],local_word=(sx>>>3)-box_word[rb];
  wire [15:0] next_word=((sx+1)>>>3)-box_word[rb],next_y=local_y+1'b1;
  wire [3:0] mask=box_rejected[rb]?4'd0:{sx>=-1 && sx<$signed({1'b0,width})-1 && sy>=-1 && sy<$signed({1'b0,height})-1,
   sx>=0 && sx<$signed({1'b0,width}) && sy>=-1 && sy<$signed({1'b0,height})-1,
   sx>=-1 && sx<$signed({1'b0,width})-1 && sy>=0 && sy<$signed({1'b0,height}),
   sx>=0 && sx<$signed({1'b0,width}) && sy>=0 && sy<$signed({1'b0,height})};
  wire [7:0] selectors={{next_y[0],next_word[0]},{next_y[0],local_word[0]},{local_y[0],next_word[0]},{local_y[0],local_word[0]}};
  wire [43:0] indices={{next_y[6:1],next_word[5:1]},{next_y[6:1],local_word[5:1]},
                      {local_y[6:1],next_word[5:1]},{local_y[6:1],local_word[5:1]}};
  reg [10:0] address[0:3],address_q[0:3];
  reg [7:0] sel_q,sel_d,sel_e;reg [3:0] mask_q,mask_d,mask_e;
  reg [2:0] lane0,lane1,lane0_d,lane1_d,lane0_e,lane1_e;
  reg [11:0] dx_q,dy_q,dx_d,dy_d,dx_s3,dy_s3,dx_s4,dy_s4,dx_s5,dy_s5;reg [15:0] samples[0:3];
  reg [127:0] selected_word[0:3];reg [3:0] mask_f;
  reg [2:0] lane0_f,lane1_f;
  // Keep the physical DRM-to-register path separate from the pixel selection
  // and interpolation DSP input mux. No arithmetic or rounding changes.
  reg [511:0] cache_q /* synthesis syn_preserve=1 */;
  wire [511:0] cache=k==0?cache_data0[rb]:cache_data1[rb];integer j;
  for(b=0;b<4;b=b+1)begin:address_bus
   if(k==0)assign read_address0[b*11+:11]=address_q[b];
   else assign read_address1[b*11+:11]=address_q[b];
  end
  always @*begin
   for(j=0;j<4;j=j+1)address[j]=0;
   for(j=0;j<4;j=j+1)if(mask[j])address[selectors[j*2+:2]]=indices[j*11+:11];
  end
  always @(posedge clk)begin
   for(j=0;j<4;j=j+1)begin
    address_q[j]<=address[j];
    // Separate the high-fanout parity-bank selector from the pixel selector
    // and DSP input. This adds one cycle, with unchanged sample/weight bits.
    selected_word[j]<=cache_q[sel_e[j*2+:2]*128+:128];
    if(SAMPLE_PIPELINE)
     samples[j]<=mask_f[j]?(selected_word[j]>>(16*(j[0]?lane1_f:lane0_f))):128'd0;
    else samples[j]<=mask_e[j]?(cache_q[sel_e[j*2+:2]*128+:128]>>(16*(j[0]?lane1_e:lane0_e))):128'd0;
   end
   cache_q<=cache;
   sel_q<=selectors;sel_d<=sel_q;sel_e<=sel_d;mask_q<=mask;mask_d<=mask_q;mask_e<=mask_d;
   mask_f<=mask_e;lane0_f<=lane0_e;lane1_f<=lane1_e;
   lane0<=sx[2:0];lane1<=sx[2:0]+1'b1;lane0_d<=lane0;lane1_d<=lane1;lane0_e<=lane0_d;lane1_e<=lane1_d;
   dx_q<=coord[11:0];dy_q<=coord[43:32];dx_d<=dx_q;dy_d<=dy_q;dx_s3<=dx_d;dy_s3<=dy_d;dx_s4<=dx_s3;dy_s4<=dy_s3;
   dx_s5<=dx_s4;dy_s5<=dy_s4;
  end
  bilin interpolate(.clk(clk),.rst_n(rst_n),.in_valid(SAMPLE_PIPELINE?(COORD_PIPELINE?v7:v6):(COORD_PIPELINE?v6:v5)),.p00(samples[0]),.p01(samples[1]),.p10(samples[2]),.p11(samples[3]),
   .dx(SAMPLE_PIPELINE?dx_s5:dx_s4),.dy(SAMPLE_PIPELINE?dy_s5:dy_s4),.out_valid(interp_valid[k]),.pixel(pixels[k*16+:16]));
 end endgenerate
 always @(posedge clk)begin coord_q<=maps[{rb,issue_pairs[6:0]}];coord_reg<=coord_q;end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin v1<=0;v2<=0;v3<=0;v4<=0;v5<=0;v6<=0;v7<=0;end
 else begin v1<=rs==R_SCAN;v2<=v1;v3<=v2;v4<=v3;v5<=v4;v6<=v5;v7<=v6;end

 // Four neighbouring tiles form an eight-row strip. Transpose their words
 // into two 2KiB scratch banks, so the writer sends up to 16 beats per row.
 reg [127:0] output_words[0:255];reg [95:0] partial;
 reg ob,wb,group_reserved;reg [1:0] produced,consumed,out_last;
 reg [27:0] out_address[0:1];reg [3:0] out_rows[0:1];reg [4:0] out_words[0:1];
 wire output_free=produced[ob]==consumed[ob];
 wire group_end=tile_x[rb][6:5]==3 || tile_x[rb]+32>=width;
 wire tile_last=tile_x[rb]+32>=width && tile_y[rb]+8>=height;
 wire [127:0] complete_word={pixels,partial};
 wire [7:0] output_index={ob,result_pairs[6:4],tile_x[rb][6:5],result_pairs[3:2]};
 always @(posedge clk)if(interp_valid[0] && result_pairs[1:0]==3)output_words[output_index]<=complete_word;
 localparam W_IDLE=0,W_PREP=1,W_ADDR=2,W_DATA=3;
 reg [1:0] ws;reg [2:0] write_row;reg [4:0] row_word,burst_beat,burst_beats;
 reg [27:0] write_address,row_address;reg [127:0] output_data;
 wire [8:0] page_room=9'd256-{1'b0,write_address[11:4]};
 wire [4:0] capacity=page_room<16?page_room[4:0]:5'd16;
 wire [4:0] words_left=out_words[wb]-row_word;
 wire [4:0] chunk=words_left<capacity?words_left:capacity;
 assign awvalid=ws==W_ADDR;assign awaddr=write_address;assign awlen=burst_beats-1'b1;
 assign wdata=output_data;assign wstrb=(ws==W_ADDR || ws==W_DATA)?16'hffff:16'h0000;
 wire accept=(ws==W_DATA || (ws==W_ADDR && awready)) && wready;
 wire row_done=row_word+1==out_words[wb];
 wire strip_done=accept && row_done && {1'b0,write_row}+4'd1==out_rows[wb];
 wire frame_done=strip_done && out_last[wb];
 wire [7:0] current_read={wb,write_row,row_word[3:0]};
 // Look ahead on acceptance: no WVALID exists, so the next RAM word must be
 // ready on the very next cycle even if the native controller never stalls.
 always @(posedge clk)output_data<=output_words[accept?current_read+8'd1:current_read];
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin ws<=W_IDLE;wb<=0;consumed<=0;write_row<=0;row_word<=0;burst_beat<=0;burst_beats<=0;write_address<=0;row_address<=0;end
 else if(start && ready)begin ws<=W_IDLE;wb<=0;consumed<=0;write_row<=0;row_word<=0;burst_beat<=0;burst_beats<=0;end
 else begin
  case(ws)
   W_IDLE:if(produced[wb]!=consumed[wb])begin
    write_row<=0;row_word<=0;write_address<=out_address[wb];row_address<=out_address[wb];ws<=W_PREP;
   end
   W_PREP:begin burst_beats<=chunk;burst_beat<=0;ws<=W_ADDR;end
   W_ADDR:if(awready)ws<=W_DATA;
  endcase
  if(accept)begin
   row_word<=row_word+1'b1;write_address<=write_address+28'd16;burst_beat<=burst_beat+1'b1;
   if(burst_beat+1==burst_beats)begin
    if(row_done)begin
     row_word<=0;
     if(strip_done)begin consumed[wb]<=produced[wb];wb<=!wb;ws<=W_IDLE;end
     else begin write_row<=write_row+1'b1;row_address<=row_address+{11'd0,width,1'b0};write_address<=row_address+{11'd0,width,1'b0};ws<=W_PREP;end
    end else ws<=W_PREP;
   end
  end
 end
 wire [4:0] stride_mod=width[7:3];
 wire [4:0] total_mod=stride_mod*height[4:0];
 wire [4:0] row_mod=tile_y[rb][4:0]+result_pairs[6:4];
 wire [4:0] raster_mod=row_mod*stride_mod+tile_x[rb][7:3]+result_pairs[3:2];
 wire [4:0] rotate_amount=(total_mod-5'd1-raster_mod)*5'd5;
 wire [31:0] mixed=complete_word[31:0]^{complete_word[62:32],complete_word[63]}^{complete_word[92:64],complete_word[95:93]}^{complete_word[120:96],complete_word[127:121]};
 reg hash_valid;reg [31:0] hash_word;reg [4:0] rotate_q;
 wire [31:0] hash_term=(hash_word<<rotate_q)|(hash_word>>(32-rotate_q));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin hash_valid<=0;hash_word<=0;rotate_q<=0;end
 else begin hash_valid<=interp_valid[0] && result_pairs[1:0]==3;
  if(interp_valid[0] && result_pairs[1:0]==3)begin hash_word<=mixed;rotate_q<=rotate_amount;end
 end
 assign ready=!running && ls==L_IDLE && gs==G_IDLE && rs==R_IDLE && error==0;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  running<=0;done<=0;error<=0;checksum<=0;rs<=R_IDLE;rb<=0;ack<=0;
  ob<=0;group_reserved<=0;produced<=0;issue_pairs<=0;result_pairs<=0;total_pairs<=0;partial<=0;
  out_last<=0;out_address[0]<=0;out_address[1]<=0;out_rows[0]<=0;out_rows[1]<=0;out_words[0]<=0;out_words[1]<=0;
 end else begin
  done<=0;
  if(hash_valid)checksum<=checksum^hash_term;
  if(load_error!=0)error<=load_error;
  if(accept && wlast!=(burst_beat+1==burst_beats))error<=8'h34;
  if(start && ready)begin running<=1;rs<=R_WAIT;rb<=0;ack<=0;ob<=0;group_reserved<=0;produced<=0;checksum<=0;end
  else case(rs)
   R_WAIT:if(published[rb]!=ack[rb] && (group_reserved || output_free))begin
    issue_pairs<=0;result_pairs<=0;partial<=0;
    total_pairs<=tile_y[rb]+8<=height?8'd128:(height-tile_y[rb])<<4;
    if(!group_reserved)begin
     group_reserved<=1;
     out_address[ob]<=output_base+tile_y[rb]*width*2+{12'd0,tile_x[rb][15:7],8'd0};
     out_rows[ob]<=tile_y[rb]+8<=height?4'd8:height-tile_y[rb];
     out_words[ob]<=width-{tile_x[rb][15:7],7'd0}>=128?5'd16:(width-{tile_x[rb][15:7],7'd0})>>3;
     out_last[ob]<=tile_x[rb]+128>=width && tile_y[rb]+8>=height;
    end
    rs<=R_SCAN;
   end
   R_SCAN:begin issue_pairs<=issue_pairs+1'b1;if(issue_pairs+1==total_pairs)rs<=R_DRAIN;end
   R_DRAIN:if(interp_valid[0] && result_pairs+1==total_pairs)begin
    if(group_end)begin produced[ob]<=!produced[ob];ob<=!ob;group_reserved<=0;end
    ack[rb]<=published[rb];rb<=!rb;rs<=tile_last?R_FINISH:R_WAIT;
   end
  endcase
  if(frame_done)begin rs<=R_IDLE;running<=0;done<=1;end
  if(interp_valid[0])begin
   if(result_pairs[1:0]!=3)partial[result_pairs[1:0]*32+:32]<=pixels;
   result_pairs<=result_pairs+1'b1;
  end
 end
 reg [31:0] compute_cycles,write_cycles,overlap_cycles,output_wait_cycles,source_wait_cycles,tile_frames;
 wire compute_active=rs==R_SCAN || rs==R_DRAIN;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin compute_cycles<=0;write_cycles<=0;overlap_cycles<=0;output_wait_cycles<=0;source_wait_cycles<=0;tile_frames<=0;end
 else begin
  if(running && compute_active)compute_cycles<=compute_cycles+1'b1;
  if(running && ws!=W_IDLE)write_cycles<=write_cycles+1'b1;
  if(running && compute_active && ws!=W_IDLE)overlap_cycles<=overlap_cycles+1'b1;
  if(running && rs==R_WAIT && published[rb]!=ack[rb] && !group_reserved && !output_free)output_wait_cycles<=output_wait_cycles+1'b1;
  if(running && rs==R_WAIT && published[rb]==ack[rb])source_wait_cycles<=source_wait_cycles+1'b1;
  if(done)tile_frames<=tile_frames+1'b1;
 end
 assign tile_perf={tile_frames,source_wait_cycles,output_wait_cycles,overlap_cycles,write_cycles,compute_cycles,32'h00010201,32'h54494c31};
endmodule

module warp_dual_cache #(parameter NATIVE_TDP=1)(input clk,we,re,input [10:0] wa,ra0,ra1,input [127:0] wd,output [127:0] rd0,rd1);
 wire [10:0] address_a=we?wa:ra0;
 generate if(NATIVE_TDP)begin:native
  genvar slice;
  for(slice=0;slice<8;slice=slice+1)begin:word_slice
   wire [35:0] qa,qb;
   // 2048x16 per native 36K block, parity positions explicitly skipped.
   // Verified against the installed PDS V_DRM36K_E1 functional model.
   GTP_DRM36K_E1 #(.GRS_EN("FALSE"),.CSA_MASK(3'b111),.CSB_MASK(3'b111),
    .DATA_WIDTH_A(16),.DATA_WIDTH_B(16),.WRITE_MODE_A("NORMAL_WRITE"),.WRITE_MODE_B("NORMAL_WRITE"),
    .DOA_REG(0),.DOB_REG(0),.RST_TYPE("SYNC"),.RAM_MODE("TRUE_DUAL_PORT"),
    .ECC_WRITE_EN("FALSE"),.ECC_READ_EN("FALSE")) ram(
    .CLKA(clk),.CLKB(clk),.CEA(we || re),.CEB(re),.WEA(we),.WEB(1'b0),
    .ADDRA({1'b1,address_a,4'b1111}),.ADDRB({1'b1,ra1,4'b1111}),
    .ADDRA_HOLD(1'b0),.ADDRB_HOLD(1'b0),.CSA(3'b111),.CSB(3'b111),
    .DIA({19'd0,wd[slice*16+8+:8],1'b0,wd[slice*16+:8]}),.DIB(36'd0),
    .BWEA(8'h03),.BWEB(4'd0),.DOA(qa),.DOB(qb),.ORCEA(1'b0),.ORCEB(1'b0),
    .RSTA(1'b0),.RSTB(1'b0),.CINA(1'b0),.CINB(1'b0),.INJECT_SBITERR(1'b0),.INJECT_DBITERR(1'b0));
   assign rd0[slice*16+:16]={qa[16:9],qa[7:0]};
   assign rd1[slice*16+:16]={qb[16:9],qb[7:0]};
  end
 end else begin:behavioral
 reg [127:0] data0,data1;
 assign rd0=data0;assign rd1=data1;
 reg [127:0] memory[0:2047];
 // One physical address for port A is essential: separate write/read address
 // expressions made PDS infer a replicated 1W/2R memory (twice the DRM).
 // Reads while loading this tile owner are not valid renderer samples.
 always @(posedge clk)begin
  if(we)memory[address_a]<=wd;
  if(we || re)data0<=memory[address_a];
 end
 always @(posedge clk)if(re)data1<=memory[ra1];
 end endgenerate
endmodule
