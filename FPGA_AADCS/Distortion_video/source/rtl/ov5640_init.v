// User module has its own 24 MHz oscillator. Do not drive its XCLK net.
// Configure DVP RGB565 640x400 using the supplied, provenance-recorded table.
module ov5640_init #(
 parameter integer HALF_CYCLES=125,MS_CYCLES=25000,
 parameter integer POWER_CYCLES=500000,RESET_CYCLES=125000,SCCB_CYCLES=500000
)(input clk,input rst_n,input sda_in,
 output scl_pull_low,output sda_pull_low,
 output cam_rst_n,output cam_pwdn,
 output reg ready,output reg [7:0] error_code,
 output reg [15:0] chip_id,output [8:0] register_index);
 localparam WAIT_POWER=0,ID_H=1,ID_H_WAIT=2,ID_L=3,ID_L_WAIT=4,
            WRITE_REG=5,WRITE_WAIT=6,DELAY=7,FINISHED=8,FAILED=9;
 reg [3:0] state;
 reg [8:0] index;
 reg [31:0] delay_count;
 reg [1:0] retries;
 reg start,write_en;
 reg [15:0] address;
 reg [7:0] value;
 wire power_ready,busy,done,nack,last;
 wire [7:0] read_value;
 wire [23:0] rom;
 assign register_index=index;
 camseq #(.POWER_CYCLES(POWER_CYCLES),.RESET_CYCLES(RESET_CYCLES),.SCCB_CYCLES(SCCB_CYCLES)) seq(
  .clk(clk),.rst_n(rst_n),.enable(1'b1),.cam_rst_n(cam_rst_n),.cam_pwdn(cam_pwdn),.ready(power_ready));
 ov5640_regs regs(.index(index),.value(rom),.last(last));
 sccb_xfer #(.HALF_CYCLES(HALF_CYCLES)) bus(
  .clk(clk),.rst_n(rst_n),.start(start),.reg_addr(address),.write_en(write_en),.write_data(value),
  .sda_in(sda_in),.scl_pull_low(scl_pull_low),.sda_pull_low(sda_pull_low),
  .busy(busy),.done(done),.nack(nack),.data_out(read_value));
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=WAIT_POWER;index<=0;delay_count<=0;retries<=0;start<=0;
   address<=0;value<=0;write_en<=0;ready<=0;error_code<=0;chip_id<=0;
  end else begin
   start<=0;
   case(state)
    WAIT_POWER:if(power_ready)state<=ID_H;
    ID_H:if(!busy)begin address<=16'h300a;write_en<=0;start<=1;state<=ID_H_WAIT;end
    ID_H_WAIT:if(done)begin
     if(nack)begin error_code<=1;state<=FAILED;end
     else begin chip_id[15:8]<=read_value;state<=ID_L;end
    end
    ID_L:if(!busy)begin address<=16'h300b;write_en<=0;start<=1;state<=ID_L_WAIT;end
    ID_L_WAIT:if(done)begin
     chip_id[7:0]<=read_value;
     if(nack)begin error_code<=1;state<=FAILED;end
     else if({chip_id[15:8],read_value}!=16'h5640)begin error_code<=2;state<=FAILED;end
     else state<=WRITE_REG;
    end
    WRITE_REG:if(last)begin ready<=1;state<=FINISHED;end
     else if(!busy)begin address<=rom[23:8];value<=rom[7:0];write_en<=1;start<=1;state<=WRITE_WAIT;end
    WRITE_WAIT:if(done)begin
     if(nack)begin
      if(retries==2)begin error_code<=3;state<=FAILED;end
      else begin retries<=retries+1'b1;state<=WRITE_REG;end
     end else begin
      retries<=0;index<=index+1'b1;
      if(index==1)begin delay_count<=10*MS_CYCLES;state<=DELAY;end
      else state<=WRITE_REG;
     end
    end
    DELAY:if(delay_count==0)state<=WRITE_REG;else delay_count<=delay_count-1'b1;
    FINISHED:ready<=1;
    default:begin ready<=0;state<=FAILED;end
   endcase
  end
 end
endmodule
