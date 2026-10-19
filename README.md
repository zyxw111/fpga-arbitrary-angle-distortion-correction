# AADCS

FPGA 使用一个统一的 PDS 工程，包含内部图像、畸变矫正、DDR3 和 PCIe DMA 通路。
KEY1 在同一位流内循环选择彩条、畸变原图和校正结果；KEY0 复位回彩条。

- 工程入口：[board_video.pds](FPGA_AADCS/Distortion_video/board_video.pds)，顶层 `boardtop`。
- 使用说明：[FPGA 工程说明](FPGA_AADCS/Distortion_video/README.md)。
- 当前位流：[boardtop.sbit](firmware/fpga/distortion-video/unified/boardtop.sbit)。
- FPGA：PG2L100H-6IFBG484；工具：PDS 2022.2-SP6.4。

从仓库根目录构建：

```powershell
./FPGA_AADCS/Distortion_video/build.ps1
```

源码、IP 和约束在 `FPGA_AADCS/Distortion_video/`；构建和仿真输出在其 `build/` 中，
输出目录的 PDS 是工具生成的中间文件，不能作为工程入口。
`rk3568_AADCS/` 保留原有 ARM 通信示例，当前统一视频协议仍需匹配的接收程序。
下载脚本为 `scripts/program_fpga.tcl`，默认使用当前统一版位流，仅在需要下载时主动执行。
`docs/` 保存设计及验证记录，历史记录中的旧路径可能已清理，当前使用以上工程入口。

统一版已通过 46 项 RTL 测试、完整构建和最终时序检查（`All Constraints Met`），尚未下载上板或进行 ARM 联调。
2026-10-19 清理了旧工程、单元检查 PDS、旧位流及构建缓存；详见 [清理记录](docs/changes/009-clean-project-files.md)。
