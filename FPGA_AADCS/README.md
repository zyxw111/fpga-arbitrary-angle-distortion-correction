# FPGA 工程

唯一工程入口：[Distortion_video/board_video.pds](Distortion_video/board_video.pds)。
顶层 `boardtop`，器件 PG2L100H-6IFBG484，PDS 2022.2-SP6.4。

KEY1 在同一位流中循环切换彩条、畸变原图和矫正图，KEY0 复位。
构建、仿真、寄存器及使用说明见 [工程说明](Distortion_video/README.md)。
旧 PCIe 测试工程和单元诊断工程已清理；历史版本可从 Git 提交记录恢复。
