# AADCS

当前默认工程：**FPGA 内部畸变视频源 → DVP 摄像头接收器 → FPGA DDR → PCIe DMA → RK3568 DDR**。
640×400 RGB565，不需要连接摄像头。内部连续源约 30.048 fps；主机仍按完整帧快照读取，
实际接收帧率取决于采集、DDR 和 ARM。当前发送畸变原图，尚未接入板级矫正处理。

- 唯一工程：[board_video.pds](FPGA_AADCS/Distortion_video/board_video.pds)，顶层 `boardtop`。
- 当前使用说明：[内部畸变视频源](docs/internal-distorted-video.md)。
- 当前位流：[boardtop.sbit](firmware/fpga/distortion-video/unified/boardtop.sbit)。
- ARM 接收程序：[ov5640-capture](firmware/rk3568/ov5640-capture)，兼容 CAM2。
- 物理摄像头可通过 `INTERNAL_CAMERA=0` 重新构建，接线见 [OV5640 文档](docs/ov5640-camera.md)。

FPGA 为 PG2L100H-6IFBG484，PDS 2022.2-SP6.4，板卡 RK3568_MES2L100H。

```powershell
./FPGA_AADCS/Distortion_video/build.ps1
```

构建/仿真在 `build/`，不要打开里面的临时 PDS。`scripts/program_fpga.tcl` 默认下载交付目录的位流。
新版本未实板下载或 ARM 联调；历史 JTAG 成功记录对应之前的物理摄像头版。
