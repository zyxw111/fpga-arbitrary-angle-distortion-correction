# AADCS

当前板级工程实现 **OV5640 → FPGA DDR 帧缓冲 → PCIe DMA → RK3568 DDR**，默认 640×400 RGB565。
在确认一帧完整结束并通过 DDR 读回校验后供主机读取，取完后重新采集；本阶段不做畸变矫正。

- 唯一工程入口：[board_video.pds](FPGA_AADCS/Distortion_video/board_video.pds)，顶层 `boardtop`。
- 接线、电气、运行和寄存器：[OV5640 使用说明](docs/ov5640-camera.md)。
- 当前 FPGA 位流：[boardtop.sbit](firmware/fpga/distortion-video/unified/boardtop.sbit)。
- ARM64 接收程序：[ov5640-capture](firmware/rk3568/ov5640-capture)。
- ARM 源码：[ov5640_capture](rk3568_AADCS/apps/ov5640_capture)。

FPGA 型号 PG2L100H-6IFBG484，工具 PDS 2022.2-SP6.4，板卡 RK3568_MES2L100H。
摄像头使用所提供 1712 转接板的 24 MHz 晶振，XCLK 不接 FPGA。
**J7-2 必须接 J8-39 的 3.3 V，不能接 J8-2 的 5 V。先按接线表确认再上电。**

构建：

```powershell
./FPGA_AADCS/Distortion_video/build.ps1
```

构建和仿真输出在该目录的 `build/`，不要打开里面的临时 PDS 作为源工程。
`scripts/program_fpga.tcl` 默认下载上述当前位流，仅在需要时主动运行。
`docs/` 中的历史记录不代表当前接线或运行协议，当前使用 CAM2 v2，旧 line 模式程序不兼容。
本次只完成代码、离线验证和构建，未下载上板或进行真实摄像头、ARM 驱动联调；实际帧率尚未测量。
