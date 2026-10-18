`timescale 1ns/1ps
module tb_ddrlink;
 reg ref_clk=0;always #5 ref_clk=~ref_clk;
 reg rst_n=0;
 wire clk,pll_lock,init_done;
 wire awvalid,awready,wready,wlast,arvalid,arready,rvalid,rlast;
 wire [27:0] awaddr,araddr;wire [3:0] awlen,arlen;
 wire [127:0] wdata,rdata;wire [15:0] wstrb;
 wire passed,failed;wire [31:0] checked;
 ddrbist #(.BASE(28'hf00),.BEATS(64),.WAIT_CYCLES(8),.TIMEOUT(3000)) bist(
 .clk(clk),.rst_n(rst_n),.init_done(init_done),
 .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
 .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
 .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
 .rvalid(rvalid),.rlast(rlast),.rdata(rdata),.passed(passed),.failed(failed),.checked(checked));
 ddrlink link(.ref_clk(ref_clk),.rst_n(rst_n),.clk(clk),.pll_lock(pll_lock),.init_done(init_done),
 .axi_awvalid(awvalid),.axi_awready(awready),.axi_awaddr(awaddr),.axi_awlen(awlen),
 .axi_wdata(wdata),.axi_wstrb(wstrb),.axi_wready(wready),.axi_wusero_last(wlast),
 .axi_arvalid(arvalid),.axi_arready(arready),.axi_araddr(araddr),.axi_arlen(arlen),
 .axi_rvalid(rvalid),.axi_rlast(rlast),.axi_rdata(rdata));
 initial begin
 #20;rst_n=1;wait(passed||failed);#10;
 if(failed || checked!=128 || link.u_ddr.wc!=8 || link.u_ddr.rc!=8) $fatal(1,"native adapter BIST");
 $display("PASS DDR native x16 address conversion, burst spacing, boundary and two-pattern readback");$finish;
 end
 initial begin #40000;$fatal(1,"timeout");end
endmodule

// TEST-ONLY behavioral controller stub, never part of PDS sources.
module ddr3 #(
 
   parameter MEM_ROW_WIDTH       = 15          ,
    
   parameter MEM_COLUMN_WIDTH    = 10          ,
   
   parameter MEM_BANK_WIDTH      = 3           ,
  
  parameter MEM_DQ_WIDTH         =  16         ,
  
  parameter MEM_DM_WIDTH         =  2         ,
  
  parameter MEM_DQS_WIDTH        =  2         ,
   
   parameter CTRL_ADDR_WIDTH     = MEM_ROW_WIDTH + MEM_COLUMN_WIDTH + MEM_BANK_WIDTH        
  )(                                                              
   input                              ref_clk                       ,    
   input                              resetn                        ,            
   output                             core_clk                      ,            
   output                             pll_lock                      ,    
   output                             phy_pll_lock                  ,
   output                             gpll_lock                     ,        
   output                             rst_gpll_lock                 ,            
   output                             ddrphy_cpd_lock               ,      
   output                             ddr_init_done                 ,            

   input  [CTRL_ADDR_WIDTH-1:0]       axi_awaddr                    ,
   input                              axi_awuser_ap                 ,
   input  [3:0]                       axi_awuser_id                 ,
   input  [3:0]                       axi_awlen                     ,
   output                             axi_awready                   ,
   input                              axi_awvalid                   ,

   input  [8*MEM_DQ_WIDTH-1:0]        axi_wdata                     ,
   input  [MEM_DQ_WIDTH-1:0]          axi_wstrb                     ,
   output                             axi_wready                    ,
   output [3:0]                       axi_wusero_id                 ,
   output                             axi_wusero_last               ,

   input  [CTRL_ADDR_WIDTH-1:0]       axi_araddr                    ,
   input                              axi_aruser_ap                 ,
   input  [3:0]                       axi_aruser_id                 ,
   input  [3:0]                       axi_arlen                     ,
   output                             axi_arready                   ,
   input                              axi_arvalid                   ,

   output [8*MEM_DQ_WIDTH-1:0]        axi_rdata                     ,
   output [3:0]                       axi_rid                       ,
   output                             axi_rlast                     ,
   output                             axi_rvalid                    ,

   input                              apb_clk                       ,
   input                              apb_rst_n                     ,
   input                              apb_sel                       ,
   input                              apb_enable                    ,
   input  [7:0]                       apb_addr                      ,
   input                              apb_write                     ,
   output                             apb_ready                     ,
   input  [15:0]                      apb_wdata                     ,
   output [15:0]                      apb_rdata                     ,


   output                             mem_cs_n                      ,

   output                             mem_rst_n                     ,                       
   output                             mem_ck                        ,
   output                             mem_ck_n                      ,
   output                             mem_cke                       ,
   output                             mem_ras_n                     ,
   output                             mem_cas_n                     ,
   output                             mem_we_n                      , 
   output                             mem_odt                       ,
   output [MEM_ROW_WIDTH-1:0]         mem_a                         ,   
   output [MEM_BANK_WIDTH-1:0]        mem_ba                        ,   
   inout  [MEM_DQS_WIDTH-1:0]         mem_dqs                       ,
   inout  [MEM_DQS_WIDTH-1:0]         mem_dqs_n                     ,
   inout  [MEM_DQ_WIDTH-1:0]          mem_dq                        ,
   output [MEM_DM_WIDTH-1:0]          mem_dm                        , 

   //debug
   input                              dbg_gate_start                ,
   input                              dbg_cpd_start                 ,
   input                              dbg_ddrphy_rst_n              ,
   input                              dbg_gpll_scan_rst             ,

   input                              samp_position_dyn_adj         ,
   input  [8*MEM_DQS_WIDTH-1:0]       init_samp_position_even       ,
   input  [8*MEM_DQS_WIDTH-1:0]       init_samp_position_odd        ,

   input                              wrcal_position_dyn_adj        ,
   input  [8*MEM_DQS_WIDTH-1:0]       init_wrcal_position           ,
 
   input                              force_read_clk_ctrl           ,
   input  [4*MEM_DQS_WIDTH-1:0]       init_slip_step                ,  
   input  [3*MEM_DQS_WIDTH-1:0]       init_read_clk_ctrl            ,

   output [33:0]                      debug_calib_ctrl              ,
   output [17*MEM_DQS_WIDTH -1:0]     dbg_slice_status              ,
   output [22*MEM_DQS_WIDTH -1:0]     dbg_slice_state               ,
   output [69*MEM_DQS_WIDTH -1:0]     debug_data                    ,
   output [1:0]                       dbg_dll_upd_state             ,
   output [8:0]                       debug_gpll_dps_phase          ,
   
   output [2:0]                       dbg_rst_dps_state             ,
   output [5:0]                       dbg_tran_err_rst_cnt          ,
   output                             dbg_ddrphy_init_fail          , 
   
   input                              debug_cpd_offset_adj          ,
   input                              debug_cpd_offset_dir          ,
   input  [9:0]                       debug_cpd_offset              ,  
   output [9:0]                       debug_dps_cnt_dir0            , 
   output [9:0]                       debug_dps_cnt_dir1            ,

   input                              ck_dly_en                     ,
   input  [7:0]                       init_ck_dly_step              ,
   output [7:0]                       ck_dly_set_bin                ,
  
   output                             align_error                   ,
   output [3:0]                       debug_rst_state               ,
   output [3:0]                       debug_cpd_state               
);
assign core_clk=ref_clk;
assign pll_lock=resetn;
assign ddr_init_done=resetn;
assign phy_pll_lock=resetn;assign gpll_lock=resetn;
assign rst_gpll_lock=resetn;assign ddrphy_cpd_lock=resetn;
assign axi_wusero_id=0;assign axi_rid=0;
reg [27:0] next_aw=28'h780,next_ar=28'h780;
integer wc=0,rc=0;
always @(posedge ref_clk) if(resetn) begin
 if(axi_awvalid && axi_awready) begin
  if(axi_awaddr!==next_aw || axi_awlen!=15) $fatal(1,"native write address/length mismatch");
  wc<=wc+1;next_aw<=wc%4==3 ? 28'h780 : next_aw+128;
 end
 if(axi_arvalid && axi_arready) begin
  if(axi_araddr!==next_ar || axi_arlen!=15) $fatal(1,"native read address/length mismatch");
  rc<=rc+1;next_ar<=rc%4==3 ? 28'h780 : next_ar+128;
 end
end
// Native x16 location -> byte address for interface model only.
ddrmodel #(.WORDS(512)) mem(.clk(core_clk),.rst_n(resetn),
 .awvalid(axi_awvalid),.awready(axi_awready),.awaddr(axi_awaddr<<1),.awlen(axi_awlen),
 .wdata(axi_wdata),.wstrb(axi_wstrb),.wready(axi_wready),.wlast(axi_wusero_last),
 .arvalid(axi_arvalid),.arready(axi_arready),.araddr(axi_araddr<<1),.arlen(axi_arlen),
 .rvalid(axi_rvalid),.rlast(axi_rlast),.rdata(axi_rdata));
endmodule
