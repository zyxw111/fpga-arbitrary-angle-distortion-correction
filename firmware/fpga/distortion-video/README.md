# 当前 FPGA 位流

使用 [unified/boardtop.sbit](unified/boardtop.sbit)，KEY1 在同一位流内循环选择彩条、畸变原图和校正结果。
工程入口为 [board_video.pds](../../../FPGA_AADCS/Distortion_video/board_video.pds)。

该位流于 2026-10-18 使用 PDS 2022.2-SP6.4 生成，目标 PG2L100H-6IFBG484，
最终时序 `All Constraints Met`，46 项 RTL 测试通过。未下载上板或进行 ARM 联调。
`unified/` 同时保存 `.rtr`、`.prr`、`.bgr` 和输入指纹 `build-inputs.json`。

2026-10-19 清理旧 PCIe 测试位流和原始三模式独立位流，只保留当前统一版。
历史文件可从 Git 提交 `ab8b51e` 及更早版本恢复。
