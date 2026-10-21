# 2026-10-21：OV5640 原始图像 PCIe 传输

用户提供 OV5640 硬件和 STM32 驱动资料，要求摄像头接 FPGA，通过 PCIe 送到 RK3568 DDR；
随后确认允许 FPGA 外部 DDR 作帧缓冲。本阶段收拢为 640×400 RGB565 原始图像传输，不做畸变和角度处理。

- 在唯一 `board_video.pds` / `boardtop` 中接入 J8 DVP、SCCB、硬复位和 DDR 帧通路。
- `ov5640_init` 验证 ID，运行有来源记录的 264 项寄存器配置；新增读写 SCCB 主机和 NACK 重试。
- 按 `0x4300=0x6f` 低字节先出接收；模块自带 24 MHz，XCLK 不由 FPGA 驱动。
  PWDN 保持低，EX_RST 按提供的模块电路完成复位，SCCB 只开漏拉低。
- `camera_stream` 在下一 VSYNC 确认原始行/字节数后发布最后一个字，异步 FIFO 跨到 DDR 时钟。
- `camera_frame` 保存并读回校验一整帧，按页供给 PCIe；完整帧消费后重采。
  短帧和溢出通过填充完成已发 DDR 写，再丢弃并恢复，避免半帧成为有效图像。
- CAM2 BAR0 状态提供摄像头 ID、初始化索引、错误、帧计数、游标和校验。
- 增加 ARM 接收工具、协议辅助函数和测试，申请 coherent DDR 内存，正确分段并等待完成；
  生成 ARM64 静态二进制，支持原始 RGB565 和 PPM 保存。
- 修复旧回归 bench 仍向已清理的 `checks/regression/` 写文件的问题，统一输出到 `build/sim/`。

接线、电气约定、命令和寄存器详见 `docs/ov5640-camera.md`。
本阶段不声称 1080p30、连续无丢帧、实板摄像头或 ARM 联调已验收。

最终验证：50 项 RTL 回归通过；PDS 完成综合、布局布线和位流生成，时序报告为
`All Constraints Met`。ARM64 静态程序完成交叉编译和本机协议单元测试。
最终源码指纹、回归结果及构建信息见 `docs/verification/2026-10-21-camera/`。
构建中间目录清理后，仅保留一个可打开的源 PDS 工程和一套当前交付位流。
