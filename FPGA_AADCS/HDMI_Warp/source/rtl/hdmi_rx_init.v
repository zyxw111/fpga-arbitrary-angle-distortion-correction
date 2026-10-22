// Preserve the supplied MS7200 receiver's register table/status algorithm.
// Generic open-drain register bus adds ACK checking. MS7210 TX is unnecessary.
module hdmi_rx_init #(
 parameter integer STARTUP_CYCLES=1048575,BUS_HALF_CYCLES=120
)(input clk,input rst_n,inout hd_scl,inout hd_sda,
 output ready,output reg [7:0] error_code,output [15:0] register_addr);
 wire trigger,write_en,busy,done,nack,scl_low,sda_low;
 wire [7:0] tx,rx;
 reg [19:0] startup;
 reg [1:0] trigger_pipe;
 wire run=rst_n && startup==STARTUP_CYCLES && error_code==0;
 always @(posedge clk or negedge rst_n)
  if(!rst_n)begin startup<=0;error_code<=0;end
  else begin
   if(startup!=STARTUP_CYCLES)startup<=startup+1'b1;
   if(done && nack)error_code<=8'h10;
  end
 // The supplied controller registers its LUT, then its address/data outputs.
 // Its original I2C driver delayed the trigger internally. Retain that settling
 // time here before the transaction engine latches the next register address.
 always @(posedge clk or negedge rst_n)
  if(!rst_n)trigger_pipe<=0;else trigger_pipe<={trigger_pipe[0],trigger && run};
 wire configured;
 assign ready=configured && run;
 assign hd_scl=scl_low?1'b0:1'bz;
 assign hd_sda=sda_low?1'b0:1'bz;
 ms7200_ctl ctl(.clk(clk),.rstn(run),.init_over(configured),.device_id(),
  .iic_trig(trigger),.w_r(write_en),.addr(register_addr),.data_in(tx),
  .busy(busy),.data_out(rx),.byte_over(done));
 // 25 MHz, about 69 kHz SCL (three phases per bit in hdmi_i2c).
 hdmi_i2c #(.HALF_CYCLES(BUS_HALF_CYCLES)) bus(.clk(clk),.rst_n(rst_n),
  .start(trigger_pipe[1] && run),.reg_addr(register_addr),.write_en(write_en),.write_data(tx),
  .sda_in(hd_sda),.scl_pull_low(scl_low),.sda_pull_low(sda_low),
  .busy(busy),.done(done),.nack(nack),.data_out(rx));
endmodule
