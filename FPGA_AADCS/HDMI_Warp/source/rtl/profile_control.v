// KEY1: one debounced press per profile. Switch only between I2C transactions.
module profile_control #(parameter DEBOUNCE_CYCLES=2500000, RESET_CYCLES=125000, REGISTER_CFG_RESET=1)(
 input clk,rst_n,key_n,bus_busy,
 output reg [2:0] profile,output cfg_rst_n,output reg pending);
 reg cfg_reset_q;
 reg [1:0] key_sync;
 reg accepted;
 reg [31:0] debounce,hold_reset;
 assign cfg_rst_n=(REGISTER_CFG_RESET && RESET_CYCLES>0)?cfg_reset_q:(rst_n && hold_reset==0);
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  key_sync<=3;accepted<=1;debounce<=0;hold_reset<=RESET_CYCLES;
  profile<=0;pending<=0;cfg_reset_q<=0;
 end else begin
  key_sync<={key_sync[0],key_n};
  // Equivalent next-value decode: deassert on the same edge that the counter
  // reaches zero. A FF drives the reset tree instead of a 32-bit comparator.
  cfg_reset_q<=hold_reset<=1;
  if(hold_reset!=0)hold_reset<=hold_reset-1'b1;
  if(key_sync[1]==accepted)debounce<=0;
  else if(debounce==DEBOUNCE_CYCLES-1)begin
   debounce<=0;accepted<=key_sync[1];
   if(!key_sync[1])pending<=1;
  end else debounce<=debounce+1'b1;
  if(pending && !bus_busy && hold_reset==0)begin
   pending<=0;profile<=(profile==6)?0:profile+1'b1;hold_reset<=RESET_CYCLES;cfg_reset_q<=0;
  end
 end
endmodule
