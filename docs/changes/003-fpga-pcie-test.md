# 003：FPGA PCIe 内部数据测试工程

日期：2026-10-14。分支：zyxw，从当时的 dev/8623506 创建。

## 实现

- 将初始化 PDS 工程补全为 `aadcs_pcie_top`，目标 PG2L100H-6IFBG484。
- 参考用户提供的 `E:/Downloads/fpga/prj/ipcore/pcie_test`，导入必要 PCIe IP
  和原始 example_design DMA 代码；保留厂家版权头并记录来源/校验值。
- PCIe 保持 Gen1 x2、ID 0755:0755，发送端使用 128-bit 同步数据源。
- 新增 640x400 RGB565 字节交换彩条/渐变和 32-bit 递增测试流。
- 彩条具有 16-byte 帧头，匹配 `F:/git_clone/RK3568-PCIE` 的 LINE 采集/帧对齐方式。
- KEY0 复位；KEY1 释放为彩条、按住为递增数据；LED 指示链路和传输活动。
- 新增引脚/时钟约束、PowerShell 构建和仿真入口、协议与上板验证说明。
- 增加位流、构建输入指纹、SHA-256 和时序摘要，位于 firmware/fpga/pcie-test。

## 参考 DMA 的必要修改

1. 导出 MWr 同步数据源接口，不再发送 BAR2 初始化测试图样。
2. 读取受 FIFO 背压时不推进数据源。
3. 高地址寄存器写脉冲按自身状态清零，修复原代码误用低地址脉冲。
4. MWr 包头的状态转换与输出寄存器的使能一致，避免 ready 拉低后重复包头。
5. 请求剩余长度使用 11 bit，将 10-bit 零编码解释为 1024 dwords。

## 验证结果

Icarus Verilog 13.0，三组测试全部通过：

- 数据源：两帧完整 640x400、帧循环、读暂停、RGB565 字节序、递增数据和复位。
- 寄存器：32/64-bit 地址、高地址写脉冲、4096 字节长度编码、跨 4KiB 拒绝及字节使能。
- 实际 MWr 发送链路：2208 个连续递增 dword/69 个 TLP，重复描述符和 TX 背压；
  再校验两帧共 256000 个彩条 dword，覆盖 1280 字节行的 4KiB 页边界拆分。
- 将仿真输出还原成 640x400 图像，检查彩条、渐变和帧头覆盖区域。

PDS 2022.2-SP6.4 build 146967：compile、ADS synthesize、dev_map、pnr、
report_timing、report_power、gen_bit_stream 均成功。

布局布线后资源：3112 LUT、3227 FF、24.5 个 36K DRM 等效容量、0 APM。
DMA 时钟约束 8ns（125MHz）；慢角 DMA setup WNS=1.155ns，快角 hold WHS=0.102ns。
已约束内部时钟的 setup/hold 摘要没有失败端点。

专用 HSST 串行引脚由 lane 位置绑定，PDS 不支持对它们施加普通 PAP_IO_LOC；
工具保留串行端口未约束及相关 I/O timing 告警。按键为异步输入，LED 为观测输出，
针对这些端口设置 false path，没有豁免内部 DMA 数据通路。

## 未验证与后续范围

- 尚未执行上板下载、真实 PCIe 枚举、Linux DMA 缓存一致性或显示联调。
- 本地 RTL 仿真不包含模拟 PHY 和操作系统驱动，不能代替硬件验证。
- 保持单进程、串行描述符、16-byte 对齐及参考节拍等待；无完成中断或命令队列。
- 仅实现 LINE 描述符传输，不实现历史整帧流寄存器或分页 BAR0 视频协议。
- 图像采集、DDR3、畸变矫正及比赛实时性能目标待后续实现和测量。
