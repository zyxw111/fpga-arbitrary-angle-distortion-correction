# FPGA / ARM 联调记录（进行中）

后续故障定位与实机通过结果见 [2026-10-23 联调续记](../2026-10-23-joint/notes.md)。以下保留前一阶段的观察记录。

日期：2026-10-22，时区 Asia/Shanghai。FPGA 工作分支 zyxw-gpt；ARM 工作目录 F:/git_clone/RK3568-PCIE。

- 已通过 USB 远程助手提供的 SSH 转发连接到 RK3568，板载 GCC / GTK3 可用。
- 初始端点配置可读，BAR0 完整 32 位读为 0x54321000 等地址回显，是旧测试设计的行为。
- 下载原 unified/boardtop.sbit（SHA256 293047d5b075f114f67656670a3ca306b1b411c4869c837f91047913f457052c）成功，但 PCIe 端点配置变成全 ffffffff。
- 尝试恢复根桥总线号与 retrain 后仍无端点响应。rk-pcie 控制器重新绑定后 LTSSM 停在 0x3，驱动未能初始化主桥；等待 FPGA 修复后重新绑定恢复。
- 新 ARM CAM2 接收程序已在板上编译。原 32 项测试、CAM2 异步设备模型的完整帧/4KiB 分段/posted completion 后可见性/计数回绕/中途退出恢复/超时保留 DMA/拒绝损坏数据均通过。
- FPGA afifo 已加各时钟域独立同步释放；52 项原 RTL 回归通过。
- 第一份 DebugCore 固件已完成时序验证并成功下载，独立 125 MHz 域抓取成功：debug_boot_flags=0x00000003。KEY0/KEY1 松开；board_clock_locked=0，power_up_rst_n=0，core_rst_n=0，dma_reset_n=0，两个 PCIe link_up=0。板载参考与 PLL 输出的两个计数器都在变化，PLL 输出未锁定。
- boot-before-fix.dprj / .wdf 保存上述抓取，已校正总线位序。通道 0..31 为 boot_flags，32..63 为 PLL 输出心跳，64..95 为板载参考心跳。
- 正在构建 PLL 修复：独立参考时钟产生上电复位脉冲；IDIV=5，FDIV=40，ODIV0=40，DUTY0=DUTYF=40。25 MHz 时钟目标不变。新启动复位/锁定/POR/DMA/KEY0 顺序仿真通过。

当前尚未收到并验证真实 PCIe 图像；不能将离线测试当作实机画面验证。
