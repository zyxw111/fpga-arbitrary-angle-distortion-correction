# HDMI 诱骗 + 在线畸变/仿射 + PCIe 位流

2026-10-26 从 FPGA_AADCS/HDMI_Warp/build/generate_bitstream 同步。
适用 PG2L100H / HDMIK V1.1，普通版，不含 DebugCore。

SHA256：65aae5b356e69984e55b6c5122a8d762a594587ddc7cabeb0a3b9ad7cd674513。

已通过全部静态时序、JTAG SRAM 下载、1920×1080 HDMI 输入、640×400 CAM2
PCIe DMA 到 ARM DDR、原 fpga-view 显示及在线参数修改实测。输出为逐像素快照，
当前约 2～5 fps，不是 1080p30 输出。断电后 SRAM 配置不保留。

按键/接线/ARM 工具及完整步骤见源码工程 README.md；实测记录见
FPGA_AADCS/HDMI_Warp/checks/2026-10-26/result.md。
