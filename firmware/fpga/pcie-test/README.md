# PCIe 内部测试数据位流

2026-10-17 从本仓库 zyxw 分支工程生成，目标为 PG2L100H-6IFBG484，
PDS 2022.2-SP6.4。提供 Gen1 x2 DMA、640x400 彩条及递增数据。

- `aadcs_pcie_top.sbit`：普通版。
- `aadcs_pcie_top_debug.sbit` / `.fic`：双 DebugCore 版及对应探针配置。

调试版已通过远程 JTAG 下载，DONE=1，并实际采样确认独立时钟、复位释放和 PCIe link-up。
ARM 运行后读取计数仍为 0，真实 DMA 载荷及主机缓冲覆盖率尚未复验通过。
完整记录见 `../../../docs/changes/006-pcie-report-fixes.md`。

校验值、构建输入指纹和验证范围见 `build-info.json`，两版时序摘要见 `timing-summary*.txt`。
指纹按相对路径排序，对输入文本归一化 CRLF 后计算，避免 Git 换行转换影响源内容校验。

工程说明见 `../../../FPGA_AADCS/README.md`；接收程序需要匹配的 DMA 内存分配驱动。
此位流不包含摄像头、DDR3 图像缓存或畸变矫正。

SRAM 下载使用 `../../../scripts/program_fpga_pcie.tcl`，默认普通版；设置环境变量
`AADCS_BITSTREAM` 为调试版绝对路径可切换。成功下载使用显式 `-program 1` 和 1 MHz JTAG。
在 Fabric Debugger Tcl Console 执行 `source 调试脚本绝对路径`，脚本为
`../../../scripts/debug_fpga_pcie.tcl`。重新下载会重置端点，ARM 可能需要恢复枚举/BAR 配置。
