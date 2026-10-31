// Unsigned (numerator << FRAC)/denominator, saturating quotient.
// Latency WIDTH+FRAC clocks; throughput one/clock. No combinational '/'.
module ray_divide_pipe #(parameter WIDTH=32,FRAC=16)(
 input clk,rst_n,in_valid,input [WIDTH-1:0] numerator,denominator,
 output out_valid,output [WIDTH-1:0] quotient,output invalid);
 localparam N=WIDTH+FRAC;
 reg [WIDTH:0] remainder[0:N];reg [WIDTH-1:0] divisor[0:N];
 reg [N-1:0] dividend[0:N],result[0:N];
 reg [N:0] valid,bad;
 assign out_valid=valid[N];assign invalid=bad[N];
 assign quotient=bad[N]?{WIDTH{1'b0}}:(|result[N][N-1:WIDTH])?{WIDTH{1'b1}}:result[N][WIDTH-1:0];
 always @*begin remainder[0]=0;divisor[0]=denominator;dividend[0]={numerator,{FRAC{1'b0}}};result[0]=0;end
 always @*begin valid[0]=in_valid;bad[0]=denominator==0;end
 genvar g;
 generate for(g=0;g<N;g=g+1)begin:stage
  wire [WIDTH:0] trial={remainder[g][WIDTH-1:0],dividend[g][N-1]};
  wire subtract=trial>={1'b0,divisor[g]};
  always @(posedge clk or negedge rst_n)
   if(!rst_n)begin remainder[g+1]<=0;divisor[g+1]<=0;dividend[g+1]<=0;result[g+1]<=0;valid[g+1]<=0;bad[g+1]<=0;end
   else begin
    remainder[g+1]<=subtract?trial-{1'b0,divisor[g]}:trial;
    divisor[g+1]<=divisor[g];dividend[g+1]<=dividend[g]<<1;
    result[g+1]<={result[g][N-2:0],subtract};valid[g+1]<=valid[g];bad[g+1]<=bad[g];
   end
 end endgenerate
endmodule
