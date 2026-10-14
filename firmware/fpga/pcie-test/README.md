# PCIe 内部测试数据位流

`aadcs_pcie_top.sbit` 是 2026-10-14 从本仓库的 zyxw 分支工程生成的位流，
目标为 PG2L100H-6IFBG484，PDS 2022.2-SP6.4。它提供 Gen1 x2 DMA、
640x400 彩条及递增数据，尚未执行上板下载或 FPGA/RK3568 联合验证。

校验值、构建输入指纹和验证范围见 `build-info.json`，时序摘要见 `timing-summary.txt`。
指纹按相对路径排序，对输入文本归一化 CRLF 后计算，避免 Git 换行转换影响源内容校验。

工程说明见 `../../../FPGA_AADCS/README.md`；接收程序需要匹配的 DMA 内存分配驱动。
此位流不包含摄像头、DDR3 图像缓存或畸变矫正。
