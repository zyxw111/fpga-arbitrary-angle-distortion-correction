`timescale 1ns/1ps
module tb_fetch_capacity;
 fetch_queue #(.OUTSTANDING(8)) dut(.clk(1'b0),.rst_n(1'b0),.start(1'b0),
  .base_addr(28'd0),.beats(32'd0),.arready(1'b0),.rvalid(1'b0),.rlast(1'b0),
  .rdata(128'd0),.out_ready(1'b0));
 integer offset,n,j,count=0;reg [31:0] remaining;
 task check(input [31:0] left);
  reg [31:0] old_capacity,old_chunk;
  begin
   dut.cursor=offset*16;dut.issue_left=left;
   old_capacity=256-offset;if(old_capacity>16)old_capacity=16;
   old_chunk=left<old_capacity?left:old_capacity;
   #1;
   if(dut.capacity!==old_capacity[4:0] || dut.chunk!==old_chunk[4:0])
    $fatal(1,"capacity/chunk offset=%0d left=%h actual=%d/%d expected=%d/%d",
       offset,left,dut.capacity,dut.chunk,old_capacity,old_chunk);
   count=count+1;
  end
 endtask
 initial begin
  for(offset=0;offset<256;offset=offset+1)begin
   for(n=0;n<=64;n=n+1)check(n);
   for(j=0;j<32;j=j+1)begin
    remaining=32'd1<<j;check(remaining);check(remaining-1);check(remaining+1);
   end
   check(32'hffffffff);
  end
  $display("PASS fetch capacity/chunk equivalence: %0d boundary cases",count);
  $finish;
 end
endmodule
