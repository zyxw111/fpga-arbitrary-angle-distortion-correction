// FPGA control port -> MS7200 internal EDID RAM and receiver setup.
// HDMI DDC and HPD are physically handled by the MS7200 on HDMIK V1.1.
module hdmi_rx_init #(parameter STARTUP_CYCLES=6250000, BUS_HALF_CYCLES=625)(
 input clk,input rst_n,input [2:0] profile_select,inout hd_scl,inout hd_sda,
 output bus_busy,
 output ready,output edid_written,output reg [7:0] error_code,
 output [15:0] register_addr,output [6:0] controller_state,
 output [8:0] controller_index,output [31:0] receiver_frequency,
 output reg [31:0] transactions,output reg [7:0] last_read);
 localparam START_BITS=$clog2(STARTUP_CYCLES+1);
 reg [START_BITS-1:0] startup;
 reg [1:0] trigger_pipe;
 wire trigger,write_en,busy,done,nack,scl_low,sda_low,configured;
 wire [7:0] tx,rx;
 assign bus_busy=busy;
 wire run=rst_n && startup==STARTUP_CYCLES && error_code==0;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin startup<=0;error_code<=0;trigger_pipe<=0;transactions<=0;last_read<=0;end
  else begin
   if(startup!=STARTUP_CYCLES)startup<=startup+1'b1;
   trigger_pipe<={trigger_pipe[0],trigger && run};
   if(done)begin
    if(nack)error_code<=8'h10;
    else begin transactions<=transactions+1'b1;last_read<=rx;end
   end
  end
 assign ready=configured && run;
 assign hd_scl=scl_low?1'b0:1'bz;
 assign hd_sda=sda_low?1'b0:1'bz;
 ms7200_ctl ctl(.clk(clk),.rstn(run),.profile_select(profile_select),.init_over(configured),.device_id(),
  .edid_written(edid_written),.debug_state(controller_state),.debug_index(controller_index),
  .debug_frequency(receiver_frequency),.iic_trig(trigger),.w_r(write_en),
  .addr(register_addr),.data_in(tx),.busy(busy),.data_out(rx),.byte_over(done));
 hdmi_i2c #(.HALF_CYCLES(BUS_HALF_CYCLES)) bus(.clk(clk),.rst_n(rst_n),
  .start(trigger_pipe[1] && run),.reg_addr(register_addr),.write_en(write_en),.write_data(tx),
  .sda_in(hd_sda),.scl_pull_low(scl_low),.sda_pull_low(sda_low),
  .busy(busy),.done(done),.nack(nack),.data_out(rx));
endmodule
