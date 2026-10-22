# FPGA 工程

唯一入口：[Distortion_video/board_video.pds](Distortion_video/board_video.pds)。
顶层 `boardtop`，PG2L100H-6IFBG484，PDS 2022.2-SP6.4。

默认在 FPGA 内生成畸变图像，连续模拟 640×400 RGB565 DVP 摄像头，
经原采集器、FPGA DDR 和 PCIe DMA 传给 RK3568 DDR。不需要连接摄像头。
KEY0 复位，KEY1 保留。完整说明见 [内部畸变视频源](../docs/internal-distorted-video.md)。
