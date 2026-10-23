# FPGA / ARM 联调续记

FPGA：F:/AADCS_git_zyxw，分支 zyxw-gpt。ARM：F:/git_clone/RK3568-PCIE。

## 已确认的故障

1. 原板级 25 MHz PLL 未锁定，独立 125 MHz DebugCore 抓到启动标志 0x00000003，PCIe 核被保持在复位。增加独立参考域的 PLL 上电复位，并使用 IDIV=5、FDIV=40、ODIV0=DUTY0=DUTYF=40 后，启动标志为 0x000003ff；ARM 端 PCIe Gen1 x2 正常枚举，DDR 初始化完成。
2. CAM2 仍然丢弃每一帧：写入/回读各 32000 拍，源校验 0x7d6c736d，fetch 消费端校验 0xcebaa49b。新增对 DDR 原始返回数据的独立滚动校验，实机得到 0x7d6c736d，证明差异发生在 fetch 暂存与消费路径。
3. DebugCore 抓到 fetch 输出：每个突发第 0 项为该突发最后一项，其余项为固定异常值。布局布线后网表中，RAM 写地址 N314 的各位均受 arvalid/握手条件控制；在 RECV 阶段 arvalid=0，因此所有数据写到地址 0。fetch-before-netlist.txt 保存相关网表，fetch-before.wdf 保存 176 通道、1024 周期的消费端原始抓取。

## 修复及验证进度

fetch 将常量地址 buffer[0] 与变量地址 buffer[index] 两处赋值合并为一个同步写端口，以 index 统一寻址，同时支持 AR 接受时立即返回首拍。修改后 fetch 的跨页、停顿、即时首拍测试通过；完整 640×400 的 256000 像素比对通过；三帧真实 PCIe RTL 路径的 30720 像素比对通过。

修复位流完整构建成功，时序 All Constraints Met。映射后的读取 RAM 为 GTP_RAM32X2SP，物理读写地址都直接接 index；fetch-after-netlist.txt 保存对应网表。SRAM 下载成功，未改写 Flash。

实机连续采集 4 帧，每帧 512000 字节，共 500 条 DMA 描述符；四帧校验全部为 0x7d6c736d，累计丢帧为 0。下载回本机后，check_capture.py 将 1,024,000 个像素逐个与参考图像及帧号色块比较，全部一致；帧号低字节依次为 1、16、24、31，证明图像源持续运行。

ARM 显示程序持续运行约 10～11 fps。arm-final.txt 记录运行期间已发布 1534 帧、完成 191750 条描述符、丢帧与错误均为 0；寄存器是逐项读取，运行时瞬时 busy/ready/cursor 不构成原子快照。arm-live.png 为 X11 屏幕截图，已目视确认显示畸变网格、红色中心线、绿色矩形和帧号色块。fpga-frame.png 来自已逐像素验证的第一帧。

ARM 原 32 项检查及 5 组 CAM2 异步模型场景全部通过，日志见 arm-final.txt。已验证二进制安装到 /userdata/fpga-view，旧程序备份于其 backup-before-cam2-20261023 子目录；当前显示实例从 /userdata/fpga-view-gpt/stage 运行，同一份已验证二进制。

交付位流：firmware/fpga/distortion-video/unified/boardtop.sbit，SHA256 为 6aa069cc1250e5708ac820ef4460c75c1a5231e6dd84f6fcf7b139d8e7c6b1ac，包含三组 DebugCore。build-inputs.json 记录输入及产物哈希。该性能结果为 640×400 内部畸变源；未完成 1080p30 或真实 HDMI/摄像头的实机验证。

## 探针与寄存器

- DebugCore 0：dclk，通道 0 为消费 valid；16..143 为消费数据；144..175 为帧内消费拍序号。
- DebugCore 1：125 MHz，启动状态与时钟计数。
- DebugCore 2：dclk，0..127 原始 DDR 数据；128..159 消费拍计数；160..187 字节读地址；188..197 为原生接口标志。
- BAR0 0x60：当前原始 DDR 回读校验；校验过程中变化，仅供诊断，不替代帧所有权或 DMA 完成条件。
- WDF 内样本字符串按通道存储，Qt UTF-16BE。Fabric Debugger 的 dbg_set_unit 在本版本中二进制 radix 实际为 0；旧手册枚举与实例有出入。
