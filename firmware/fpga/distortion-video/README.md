# 当前 FPGA 位流：内部畸变视频源

[unified/boardtop.sbit](unified/boardtop.sbit) 为默认 `INTERNAL_CAMERA=1`、CAM2 v2：
内部畸变视频 → DVP 接收器 → FPGA DDR 完整帧校验 → PCIe DMA → RK3568 DDR，640×400 RGB565。
无需连接摄像头，当前发送畸变原图；使用说明见 [内部畸变视频](../../../docs/internal-distorted-video.md)。
工程入口为 [board_video.pds](../../../FPGA_AADCS/Distortion_video/board_video.pds)。
同目录保存 `.rtr`、`.prr`、`.bgr` 和 `build-inputs.json`。新位流尚未实板下载/ARM 联调。
物理 OV5640 版本可从 Git 提交 `3135047` 恢复；历史三模式版为 `ab8b51e`。
