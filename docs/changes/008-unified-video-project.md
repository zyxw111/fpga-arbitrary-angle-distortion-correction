# 统一视频板级工程

将交付包中彩条、原图、矫正图的三个板级入口合并为
`FPGA_AADCS/Distortion_video/board_video.pds`，顶层 `boardtop`。
删除三个复制的板级顶层和对应 PDS、构建脚本，以及重复的 `board_demo.pds` 入口。
其余单元诊断工程和此前的 PCIe 数据源测试工程仍独立保留。
原交付位流、报告及其源文件哈希保存在 `firmware/fpga/distortion-video/`，
导入提交和导入清单记录的是改动前的交付版本。

用户选择同一位流内动态切换，本版用 KEY1 完成，不需要重新综合或下载。
默认彩条，按键依次选择原图、矫正图，再回到彩条。
20 ms 消抖，长按只触发一次；KEY0 全局复位后恢复默认。

三种图像生成逻辑同时存在，通过 `demo_select` 选择当前输出，共用图像打包、
CDC、DDR 写入/校验/读回、页缓存及 PCIe DMA。此前的 GROUP/VIEW 参数化单元测试入口保留。
`video_mode_control` 等待 DDR 图像引擎空闲、当前 DMA 描述符及 TX 排空后，
仅复位图像和 hostlink 会话，稳定模式信号，再重新构造 DDR 图像。
DDR PHY、GPLL 和 PCIe IP 不参与模式复位。切换期间的额外按键不排队。

BAR0 版本改为 `0x00010001`，0x00–0x30 的原状态布局保留。
GROUP/VIEW 改为实际运行模式；0x40–0x4c 增加 MODE 标识、generation、模式/切换状态、按键能力。
generation 每次实际切换递增，不随图像会话复位而清除。
ARM 应在完整帧接收前后核对 generation，丢弃跨模式的半帧；切换完成后游标及完成计数归零，
需刷新接收基线。当前新增的寄存器都是只读，模式控制通过 KEY1。
建议切换时停止提交 DMA，确认新图像 ready 后重新开始。

主时钟、DDR/PCIe IP、引脚、电平及 SCBV 保持交付版设置。
`board_video.fdc` 和 `board_video.pcf` 从原彩条板级约束逐字节复制。
批处理构建将绝对输入引用及 PDS 状态写入忽略的 `build/`，保持 GUI 工程入口可迁移。
输出位流为 `FPGA_AADCS/Distortion_video/build/generate_bitstream/boardtop.sbit`。

## 验证范围

新增真实 DMA 动态模式测试：在同一次运行中按键完成彩条、原图、矫正图、彩条四帧，
使用独立 golden 数据逐像素核对，并经实际厂商 RX/控制器/TX、BAR0 Completion 和随机 TX 反压传输。
另有模式控制测试覆盖 DDR 正忙、描述符正忙、请求待处理、TX 尚未排空、长按、循环和全局复位。
PCIe 硬 PHY 和 DDR 使用模型，不能代替板级验证。

本机 PDS 2022.2-SP6.4 已完成统一顶层的解析、编译、综合、布局布线和最终时序分析。
最终时序报告为 `All Constraints Met`，pclk_div2 的性能汇总余量为 1.140 ns，
ddrphy_sysclk 为 1.096 ns。46 项 RTL 测试全部通过，且测试输入哈希与最终文件一致。
记录位于 `docs/verification/2026-10-18-unified-video/`。
位流生成成功，新位流和构建报告保存到 `firmware/fpga/distortion-video/unified/`，
`boardtop.sbit` 的 SHA-256 为
`9f63d0b8ee9f2a24a7f6f2a37e1c8d48ee94fb26a8a173109b6c39970b48fa60`。

未执行统一版的硬件下载、DDR 实测或 ARM 联调；本次也未修改远程分支。
