# 当前 FPGA 位流：OV5640 摄像头版

[unified/boardtop.sbit](unified/boardtop.sbit) 对应 CAM2 v2：
OV5640 DVP → FPGA DDR 完整帧校验 → PCIe DMA → RK3568 DDR，640×400 RGB565。
工程入口为 [board_video.pds](../../../FPGA_AADCS/Distortion_video/board_video.pds)。
接线和 ARM 接收程序见 [使用说明](../../../docs/ov5640-camera.md)。

此路径已更新为摄像头版，不能继续按旧三模式内部演示或旧 ARM line 协议使用。
同目录保存本次 `.rtr`、`.prr`、`.bgr` 和 `build-inputs.json`；未下载上板或进行 ARM 联调。
历史三模式位流可从 Git 提交 `ab8b51e` 恢复。
