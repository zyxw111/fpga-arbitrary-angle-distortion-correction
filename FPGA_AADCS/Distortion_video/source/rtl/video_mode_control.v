// KEY1: one step per debounced press, even when held. Never interrupt a DDR
// transaction or a posted PCIe payload. Only the image and host session reset;
// the DDR PHY and PCIe endpoint retain calibration and link state.
module video_mode_control #(
 parameter integer DEBOUNCE_CYCLES=2500000,RESET_CYCLES=32
)(input clk,input rst_n,input key1_n,input image_idle,
 input host_busy,input request,input tx_busy,
 output reg [1:0] mode,output image_rst_n,output switching,
 output reg [31:0] generation);
 localparam RUN=0,WAIT_IDLE=1,HOLD=2;
 reg [1:0] state,key_sync,idle_sync;
 reg key_stable,image_run;
 reg [31:0] debounce_count,reset_count;
 wire press=key_sync[1]!=key_stable && !key_sync[1] &&
            debounce_count==DEBOUNCE_CYCLES-1;
 assign image_rst_n=rst_n && image_run;
 assign switching=state!=RUN;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=HOLD;mode<=0;generation<=0;reset_count<=0;image_run<=0;
   key_sync<=3;key_stable<=1;debounce_count<=0;idle_sync<=0;
  end else begin
   key_sync<={key_sync[0],key1_n};idle_sync<={idle_sync[0],image_idle};
   if(key_sync[1]==key_stable)debounce_count<=0;
   else if(debounce_count==DEBOUNCE_CYCLES-1)begin
    key_stable<=key_sync[1];debounce_count<=0;
   end else debounce_count<=debounce_count+1'b1;
   case(state)
    RUN:if(press)state<=WAIT_IDLE;
    WAIT_IDLE:if(idle_sync[1] && !host_busy && !request && !tx_busy)begin
     state<=HOLD;image_run<=0;mode<=(mode==2)?0:mode+1'b1;
     generation<=generation+1'b1;reset_count<=0;
    end
    HOLD:if(reset_count==RESET_CYCLES-1)begin state<=RUN;reset_count<=0;image_run<=1;end
         else reset_count<=reset_count+1'b1;
    default:begin state<=HOLD;image_run<=0;reset_count<=0;end
   endcase
  end
 end
endmodule
