`timescale 1ns/1ps
module tb_ov5640_init;
 reg clk=0,rst_n=0;always #20 clk=~clk;
 wire scl_pull_low,sda_pull_low,cam_rst_n,cam_pwdn,ready;
 wire [7:0] error_code;wire [15:0] chip_id;wire [8:0] register_index;
 tri1 scl,sda;reg slave_low=0;
 assign scl=scl_pull_low?1'b0:1'bz;
 assign sda=(sda_pull_low || slave_low)?1'b0:1'bz;
 ov5640_init #(.HALF_CYCLES(4),.MS_CYCLES(4),.POWER_CYCLES(4),.RESET_CYCLES(4),.SCCB_CYCLES(8)) dut(
  .clk(clk),.rst_n(rst_n),.sda_in(sda),.*);
 reg [7:0] registers[0:65535];
 reg active=0,reading=0,read_pending=0,read_finished=0;
 reg [7:0] shift=0,send_value=0,byte_value=0;
 reg [15:0] pointer=0;
 integer bits=0,stage=0,send_bit=7,writes=0,fault=1,failures=0;
 reg byte_nack=0;
 // Independent wire-level SCCB slave: decode address/data on SCL edges.
 always @(negedge sda)if(scl && rst_n)begin
  active=1;reading=0;read_pending=0;read_finished=0;bits=0;stage=0;shift=0;
 end
 always @(posedge sda)if(scl)begin active=0;slave_low=0;end
 always @(posedge scl)if(active && rst_n)begin
  if(reading)begin
   if(send_bit==0)begin reading=0;read_finished=1;end
   else send_bit=send_bit-1;
  end else if(!read_finished)begin
   if(bits<8)begin
    shift={shift[6:0],sda};bits=bits+1;
    if(bits==8)begin
     byte_value=shift;byte_nack=0;
     case(stage)
      0:begin
       if(byte_value!=8'h78 && byte_value!=8'h79)$fatal(1,"SCCB address %h",byte_value);
       if(byte_value==8'h79)begin
        read_pending=1;
        send_value=(pointer==16'h300a)?8'h56:((pointer==16'h300b)?8'h40:registers[pointer]);
       end
      end
      1:pointer[15:8]=byte_value;
      2:pointer[7:0]=byte_value;
      3:begin
       if(pointer==16'h3808 && (fault==2 || (fault==1 && failures==0)))begin byte_nack=1;failures=failures+1;end
       else begin registers[pointer]=byte_value;writes=writes+1;end
      end
     endcase
     stage=stage+1;
    end
   end else begin
    bits=0;shift=0;
    if(read_pending)begin reading=1;read_pending=0;send_bit=7;end
   end
  end
 end
 always @(negedge scl)begin
  if(!active || !rst_n || read_finished)slave_low=0;
  else if(reading)slave_low=!send_value[send_bit];
  else slave_low=(bits==8 && !byte_nack);
 end
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  wait(ready || error_code);
  if(!ready || error_code || chip_id!=16'h5640 || writes!=264 || failures!=1)$fatal(1,"init/retry failed %h %0d %0d",error_code,writes,failures);
  if(registers[16'h3808]!=2 || registers[16'h3809]!=8'h80 || registers[16'h380a]!=1 || registers[16'h380b]!=8'h90 ||
     registers[16'h4300]!=8'h6f || registers[16'h3008]!=2)$fatal(1,"wrong camera mode/size");
  @(negedge clk);rst_n=0;slave_low=0;active=0;fault=2;failures=0;
  repeat(4)@(negedge clk);rst_n=1;
  wait(error_code || ready);
  if(ready || error_code!=3 || failures!=3)$fatal(1,"persistent NACK not stopped %h %0d",error_code,failures);
  $display("PASS OV5640 wire SCCB: 0x5640 ID, 264 register writes, 640x400 RGB565, transient NACK retry, persistent NACK rejection");$finish;
 end
 initial begin #30000000;$fatal(1,"SCCB init timeout state=%0d index=%0d",dut.state,register_index);end
endmodule
