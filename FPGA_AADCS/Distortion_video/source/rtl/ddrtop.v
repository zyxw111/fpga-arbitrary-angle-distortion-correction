// Standalone destructive DDR smoke-test top. Not the video/PCIe top.
module ddrtop(input free_clk,input rst_board,output heart_beat_led,output err_flag_led,
output mem_cs_n,output mem_rst_n,output mem_ck,output mem_ck_n,output mem_cke,
 output mem_ras_n,output mem_cas_n,output mem_we_n,output mem_odt,
 output [14:0] mem_a,output [2:0] mem_ba,inout [1:0] mem_dqs,inout [1:0] mem_dqs_n,
 inout [15:0] mem_dq,output [1:0] mem_dm);
wire clk,pll_lock,init_done;
wire free_clk_g;
GTP_CLKBUFG u_free_clk(.CLKIN(free_clk),.CLKOUT(free_clk_g));
reg [15:0] powerup=0;
always @(posedge free_clk_g or negedge rst_board)
 if(!rst_board) powerup<=0; else if(!(&powerup)) powerup<=powerup+1'b1;
wire ip_rst_n=rst_board && (&powerup);
reg [1:0] ready_sync /* synthesis syn_preserve=1 */;
wire ready_async=ip_rst_n && pll_lock && init_done;
always @(posedge clk or negedge ready_async)
 if(!ready_async) ready_sync<=0;else ready_sync<={ready_sync[0],1'b1};
reg [1:0] reset_sync /* synthesis syn_preserve=1 */;
always @(posedge clk or negedge ip_rst_n)
 if(!ip_rst_n) reset_sync<=0;else reset_sync<={reset_sync[0],1'b1};
wire awvalid,awready,wready,wlast,arvalid,arready,rvalid,rlast;
wire [27:0] awaddr,araddr;wire [3:0] awlen,arlen;
wire [127:0] wdata,rdata;wire [15:0] wstrb;
wire passed,failed;wire [2:0] fail_code /* synthesis PAP_MARK_DEBUG="true" */;
wire [31:0] checked /* synthesis PAP_MARK_DEBUG="true" */;
wire [27:0] fail_addr /* synthesis PAP_MARK_DEBUG="true" */;
wire [127:0] expected,observed /* synthesis PAP_MARK_DEBUG="true" */;
// BIST reset uses board reset, so loss of init can latch a diagnostic.
ddrbist u_bist(.clk(clk),.rst_n(reset_sync[1]),.init_done(ready_sync[1]),
 .awvalid(awvalid),.awready(awready),.awaddr(awaddr),.awlen(awlen),
 .wdata(wdata),.wstrb(wstrb),.wready(wready),.wlast(wlast),
 .arvalid(arvalid),.arready(arready),.araddr(araddr),.arlen(arlen),
 .rvalid(rvalid),.rlast(rlast),.rdata(rdata),.passed(passed),.failed(failed),
 .fail_code(fail_code),.checked(checked),.fail_addr(fail_addr),.expected(expected),.observed(observed));
assign heart_beat_led=passed;
assign err_flag_led=failed;
ddrlink u_mem(.ref_clk(free_clk),.rst_n(ip_rst_n),.clk(clk),.pll_lock(pll_lock),.init_done(init_done),
 .axi_awvalid(awvalid),.axi_awready(awready),.axi_awaddr(awaddr),.axi_awlen(awlen),
 .axi_wdata(wdata),.axi_wstrb(wstrb),.axi_wready(wready),.axi_wusero_last(wlast),
 .axi_arvalid(arvalid),.axi_arready(arready),.axi_araddr(araddr),.axi_arlen(arlen),
 .axi_rvalid(rvalid),.axi_rlast(rlast),.axi_rdata(rdata),
 .mem_cs_n(mem_cs_n),
 .mem_rst_n(mem_rst_n),
 .mem_ck(mem_ck),
 .mem_ck_n(mem_ck_n),
 .mem_cke(mem_cke),
 .mem_ras_n(mem_ras_n),
 .mem_cas_n(mem_cas_n),
 .mem_we_n(mem_we_n),
 .mem_odt(mem_odt),
 .mem_a(mem_a),
 .mem_ba(mem_ba),
 .mem_dqs(mem_dqs),
 .mem_dqs_n(mem_dqs_n),
 .mem_dq(mem_dq),
 .mem_dm(mem_dm));
endmodule
