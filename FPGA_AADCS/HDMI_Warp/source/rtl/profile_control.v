// KEY1: one debounced press per profile. Switch only between I2C transactions.
module profile_control #(parameter DEBOUNCE_CYCLES=2500000, RESET_CYCLES=125000)(
 input clk,rst_n,key_n,bus_busy,
 output reg [2:0] profile,output cfg_rst_n,output reg pending);
 reg [1:0] key_sync;
 reg accepted;
 reg [31:0] debounce,hold_reset;
 assign cfg_rst_n=rst_n && hold_reset==0;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin
  key_sync<=3;accepted<=1;debounce<=0;hold_reset<=RESET_CYCLES;
  profile<=0;pending<=0;
 end else begin
  key_sync<={key_sync[0],key_n};
  if(hold_reset!=0)hold_reset<=hold_reset-1'b1;
  if(key_sync[1]==accepted)debounce<=0;
  else if(debounce==DEBOUNCE_CYCLES-1)begin
   debounce<=0;accepted<=key_sync[1];
   if(!key_sync[1])pending<=1;
  end else debounce<=debounce+1'b1;
  if(pending && !bus_busy && hold_reset==0)begin
   pending<=0;profile<=(profile==6)?0:profile+1'b1;hold_reset<=RESET_CYCLES;
  end
 end
endmodule
