# 2026-10-17 验证证据

- `rtl-tests.txt`：最终五组 RTL 仿真输出，包含两帧、1000 条真实 BAR1 描述符到主机内存的验证。
- `jtag-program.txt`：调试版实际 SRAM 下载日志摘要，DONE=1，使用显式 program=1。
- `after-arm.dprj` / `after-arm.wdf`：Fabric Debugger 保存的两个核采样，可离线打开工程检查。
  Core1 为先前独立时钟采样；Core0 为用户运行 ARM 程序后 20:35:18 的立即采样。

Core0 flags=0x1CD4，source_data=0、read_count=0。Core1 status=0x3F，heartbeat 在运行。
这些文件证明已完成配置和内部状态采样，未证明真实 DMA 载荷正确；详见
`../../changes/006-pcie-report-fixes.md`。两版位流 SHA-256 位于固件目录 `build-info.json`。
