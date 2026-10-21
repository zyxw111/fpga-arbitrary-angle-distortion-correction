# FPGA 工程

唯一工程入口：[Distortion_video/board_video.pds](Distortion_video/board_video.pds)。
顶层 `boardtop`，PG2L100H-6IFBG484，PDS 2022.2-SP6.4。

当前版本从 OV5640 采集 640×400 RGB565，经过 FPGA DDR 帧缓冲与读回校验，
再通过 PCIe DMA 写入 RK3568 DDR。KEY0 复位，KEY1 保留，不再切换内部图案。
完整接线和两端操作见 [摄像头使用说明](../docs/ov5640-camera.md)。
