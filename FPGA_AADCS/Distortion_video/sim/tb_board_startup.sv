`timescale 1ns/1ps
module tb_board_startup;
 reg refclk=0,key=1,freeclk=0,locked=0;
 always #4 refclk=~refclk;
 always #20 freeclk=~freeclk;
 wire pll_reset,por,dma_reset;
 board_pll_startup #(.COUNT_BITS(4)) startup(refclk,key,pll_reset);
 pcie_reset_control #(.POR_BITS(3)) por_control(.free_clk(freeclk),
  .key0_n(key && locked),.key1_n(1'b1),.dma_clk(refclk),.core_rst_n(1'b1),
  .power_up_rst_n(por),.dma_reset_n(dma_reset),.ramp_mode());
 initial begin
  #1;if(!pll_reset || por || dma_reset)$fatal(1,"unsafe initial release");
  #100;if(!pll_reset)$fatal(1,"PLL startup reset too short");
  wait(!pll_reset);#1;
  if(por || dma_reset)$fatal(1,"released before PLL lock");
  #100;locked=1;
  wait(dma_reset);if(!por)$fatal(1,"DMA released before POR");
  #7;key=0;locked=0;#1;
  if(!pll_reset || por || dma_reset)$fatal(1,"KEY0 did not reset all domains");
  #19;key=1;
  #100;if(!pll_reset || por || dma_reset)$fatal(1,"reset recovery released too early");
  wait(!pll_reset);#100;locked=1;wait(dma_reset);
  $display("PASS board startup: independent PLL reset pulse, wait for lock, POR then DMA release, KEY0 recovery");$finish;
 end
 initial begin #10000;$fatal(1,"startup timeout");end
endmodule
