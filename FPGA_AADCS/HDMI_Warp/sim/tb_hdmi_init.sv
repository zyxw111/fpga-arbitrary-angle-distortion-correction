`timescale 1ns/1ps
module tb_hdmi_init;
 reg clk=0,rst_n=0;always #5 clk=~clk;
 tri1 scl,sda;reg slave_low=0;
 wire ready;wire [7:0] error_code;wire [15:0] register_addr;
 assign sda=slave_low?1'b0:1'bz;
 hdmi_rx_init #(.STARTUP_CYCLES(16),.BUS_HALF_CYCLES(4)) dut(
  .clk(clk),.rst_n(rst_n),.hd_scl(scl),.hd_sda(sda),.ready(ready),.error_code(error_code),.register_addr(register_addr));
 reg [7:0] registers[0:65535];
 reg [23:0] expected[0:307];
 reg active=0,reading=0,read_pending=0,read_finished=0;
 reg [7:0] shift=0,send_value=0,byte_value=0;
 reg [15:0] pointer=0;
 integer bits=0,stage=0,send_bit=7,writes=0,fault=0,failures=0,polls=0;
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
       if(byte_value!=8'h56 && byte_value!=8'h57)$fatal(1,"SCCB address %h",byte_value);
       if(byte_value==8'h57)begin
        read_pending=1;
        begin
         if(pointer==16'h209c)polls=polls+1;
         send_value=(pointer>=16'h209c && pointer<=16'h209f)?((pointer==16'h209e && polls>=3)?8'h02:8'h00):registers[pointer];
        end
       end
      end
      1:pointer[15:8]=byte_value;
      2:pointer[7:0]=byte_value;
      3:begin
       if(pointer==16'h0204 && fault!=0)begin byte_nack=1;failures=failures+1;end
       else begin
        if(!fault && (writes>=308 || {pointer,byte_value}!==expected[writes]))
         $fatal(1,"I2C transaction %0d got=%h/%h expected=%h",writes,pointer,byte_value,expected[writes]);
        registers[pointer]=byte_value;writes=writes+1;
       end
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
  $readmemh("sim/ms7200_expected.hex",expected);
  repeat(4)@(negedge clk);rst_n=1;
  wait(ready || error_code);
  if(!ready || error_code || writes!=308 || polls<3)$fatal(1,"HDMI initialization failed error=%h writes=%0d polls=%0d",error_code,writes,polls);
  if(registers[16'h2003]!=1 || registers[16'h0215]!=0 || registers[16'h1024]!=8'h70)
   $fatal(1,"receiver setup incomplete");
  @(negedge clk);rst_n=0;slave_low=0;active=0;fault=1;failures=0;
  repeat(4)@(negedge clk);rst_n=1;
  wait(error_code || ready);
  if(ready || error_code!=8'h10 || failures!=1)$fatal(1,"NACK not reported %h %0d",error_code,failures);
  $display("PASS MS7200 wire I2C: 0x56/0x57 addressing, 300-register initialization, frequency status edge, receiver setup, NACK rejection");$finish;
 end
 initial begin #15000000;$fatal(1,"HDMI init timeout state=%0d addr=%h writes=%0d polls=%0d",dut.ctl.state,register_addr,writes,polls);end
endmodule
