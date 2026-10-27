// In-order rectangle prefetch. Reserve the complete destination scratch tile
// before accepting a job. Up to sixteen bursts may be outstanding; no RREADY.
module tile_fetch(input clk,rst_n,start,output ready,
 input [27:0] base,stride,input [8:0] words,input [7:0] rows,
 output arvalid,input arready,output [27:0] araddr,output [3:0] arlen,
 input [127:0] rdata,input rvalid,rlast,
 output valid,output [127:0] data,output [7:0] row,column,
 output reg done,output reg [7:0] error);
 reg busy,issued_done;reg [27:0] address,row_base;
 reg [7:0] req_row,req_column;reg [8:0] left;
 reg [7:0] row_queue[0:15],column_queue[0:15];reg [4:0] length_queue[0:15];
 reg [3:0] head,tail;reg [4:0] count,beat;
 wire [8:0] page_room=9'd256-{1'b0,address[11:4]};
 wire [4:0] capacity=page_room<16?page_room[4:0]:5'd16;
 wire [4:0] chunk=left<capacity?left[4:0]:capacity;
 assign ready=!busy && error==0;
 assign arvalid=busy && !issued_done && count<16;
 assign araddr=address;assign arlen=chunk-1'b1;
 wire push=arvalid && arready;
 wire available=count!=0 || push;
 wire [7:0] response_row=count!=0?row_queue[head]:req_row;
 wire [7:0] response_column=count!=0?column_queue[head]:req_column;
 wire [4:0] response_length=count!=0?length_queue[head]:chunk;
 assign valid=busy && rvalid && available;
 assign data=rdata;assign row=response_row;assign column=response_column+beat;
 wire pop=valid && rlast;
 wire last_request=left==chunk && req_row+1==rows;
 wire finishing=pop && ((count==1 && !push && issued_done) || (count==0 && push && last_request));
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  busy<=0;issued_done<=0;address<=0;row_base<=0;req_row<=0;req_column<=0;left<=0;
  head<=0;tail<=0;count<=0;beat<=0;done<=0;error<=0;
 end else begin
  done<=0;
  if(start && ready)begin
   busy<=1;issued_done<=0;address<=base;row_base<=base;req_row<=0;req_column<=0;left<=words;
   head<=0;tail<=0;count<=0;beat<=0;
  end
  if(push)begin
   row_queue[tail]<=req_row;column_queue[tail]<=req_column;length_queue[tail]<=chunk;tail<=tail+1'b1;
   if(left==chunk)begin
    if(last_request)issued_done<=1;
    else begin
     req_row<=req_row+1'b1;req_column<=0;row_base<=row_base+stride;
     address<=row_base+stride;left<=words;
    end
   end else begin
    left<=left-chunk;req_column<=req_column+chunk;address<=address+{19'd0,chunk,4'd0};
   end
  end
  if(valid)begin
   if(rlast!=(beat==response_length-1'b1))error<=8'h32;
   beat<=rlast?5'd0:beat+1'b1;
  end
  if(pop)head<=head+1'b1;
  case({push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
  if(finishing)begin busy<=0;done<=1;end
 end
endmodule
