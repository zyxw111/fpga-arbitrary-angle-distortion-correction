# 内部畸变视频 / PCIe 工程

唯一入口：[board_video.pds](board_video.pds)，顶层 `boardtop`，PG2L100H-6IFBG484。
默认 `INTERNAL_CAMERA=1`：内部畸变图像 → 连续 DVP → camera_stream → 外部 DDR → PCIe。
640×400 RGB565；无需摄像头，不等待 SCCB。详见 [当前使用说明](../../docs/internal-distorted-video.md)。

设置 `INTERNAL_CAMERA=0` 后重新构建可恢复真实 OV5640，接线见 [物理摄像头文档](../../docs/ov5640-camera.md)。
两种配置共用本 PDS，交付目录只有当前默认位流。KEY0 复位，KEY1 保留。
内部源约 30.048 fps，主机采用取完再采的完整帧快照方式，不保证逐帧送达。
本版发送畸变原图，没有接入板级矫正核心。

```powershell
./FPGA_AADCS/Distortion_video/build.ps1 -PdsRoot 'F:/PDS_2022.2-SP6.4'
python FPGA_AADCS/Distortion_video/sim/regress.py --bin 'F:/AADCS_git/.cache/tools/iverilog/bin'
```

中间结果在 `build/`，交付位流为 [boardtop.sbit](../../firmware/fpga/distortion-video/unified/boardtop.sbit)。
`source/rtl` 为硬件模块，`source/pcie_dma` 为 DMA，`ipcore` 为厂商 IP，`sim` 为验证源码。
仿真新增完整 640×400 DVP 黄金图像比较和内部源→DDR→实际 PCIe DMA 的端到端比较。
新位流尚未进行实板下载/ARM 接收实测；旧版下载记录不作为本版实测证据。
