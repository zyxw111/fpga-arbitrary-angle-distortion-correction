# HDMI dummy 与 HDMI_Warp 合并上板记录（2026-10-23，进行中）

工程入口为 `../../hdmi_warp.pds`，分支 zyxw-gpt。
配置 800×600/60 Hz 输入，640×400 RGB565 LE 输出，比例 2/3，左右黑边。
ARM 保持 RK3568-PCIE 的 6cf5ab5，未修改源码或驱动。

- PDS 全流程通过；全部时序约束满足，DDR 用户域 setup 最小余量 0.504 ns。
- 独立 HDMIK V1.1 参考表与实际布局报告逐项检查 34 个 RGB/控制/时钟/按键引脚，通过。
- EDID 的 256 字节写入与校验和检查通过；默认映射全部 256000 点检查通过。
- 新位流已下载 SRAM：DONE=1、CRC 错误=0，状态 0x081ffca0，详见 program.txt。
- 下载文件为 build/debug/generate_bitstream/hdmi_warp_top.sbit；SHA256 为
  4d8817a5549305b08789f8313d23ed561c827e3f3296c9e72132c6c3229f231a。
- DebugCore 确认 PLL、DDR 锁定、DDR 初始化及双 PCIe link 状态均正常；EDID 完成，I2C 错误为 0。
- 第一轮 ARM probe 能识别 CAM2 寄存器，下载后 BAR 已由原程序修复；未收到有效帧。
- 第一轮像素时钟 148499060 Hz；用户随后截图确认桌面 800×600，但活动信号仍为 1920×1080/60 Hz。
  本位流像素域按 40 MHz 约束；此时的非正常宽高统计不能作为有效采集结果。
- 接收器输出配置 ready 仍为 false，待输入活动信号改为 800×600 后继续排查。

当前没有验证实际 HDMI 图像显示成功。first-sink.wdf/json 是首轮内部状态，
timing-summary.txt 为本次构建报告。目录外 2026-10-22 记录和交付位流属于旧版，
不能用于证明本次合并已经完成硬件联调。
