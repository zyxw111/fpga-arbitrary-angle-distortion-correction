# OV5640 → FPGA DDR → PCIe → RK3568 DDR

> 2026-10-22 起，当前默认位流改为 FPGA 内部畸变视频源，不需要摄像头。
> 本文的接线和 SCCB 参数适用于 `boardtop.INTERNAL_CAMERA=0` 重新构建的物理摄像头配置；
> 当前默认使用方法见 [内部畸变视频源](internal-distorted-video.md)。

本阶段完成摄像头原始 RGB565 图像传输。目标板为 RK3568_MES2L100H，FPGA 为
PG2L100H-6IFBG484。保留唯一工程入口 `FPGA_AADCS/Distortion_video/board_video.pds`，
顶层 `boardtop`。默认 640×400，每帧 512,000 字节，通过 125 个 4 KiB 描述符传到 ARM。

此版是完整帧采集/发送模式：等待一帧完整结束，校验 DDR 读回后供主机读取；主机取完后再采新帧。
等待期间的传感器帧不进入缓冲，不能将本版描述为无丢帧连续视频或已经达到 1080p30。
本版不做 FPGA 畸变/角度矫正，之前的三种内部图案不再是板级默认输入。

## 资料与电气约定

- 用户提供的 `E:/Downloads/OV5640/OV5640/OV5640摄像头--资料--1712/1，OV5640摄像头模块原理图/Camera_OVx640原理图--1712.pdf`，第 1 页。
- 同资料包 `2、OV5640摄像头驱动程序/F407VE_OV5640摄像头/HARDWARE/OV5640/ov5640cfg.h`。
  寄存器表来源、文件指纹和改动见 `docs/verification/2026-10-21-camera/register-source.json`。
- 板卡硬件使用手册第 24–25 页的 J8→FBG484 引脚表。

按所提供的 1712 转接板：J7-2 为 3.3 V 供电；板上将信号侧 DOVDD 稳压到 2.8 V，
有 Y1 24 MHz 晶振、EX_RST 复位电路和 SCCB 上拉位置。
本程序不驱动 XCLK，J7-18 不连接 FPGA，避免与 Y1 同时驱动。
PWDN 始终输出低电平，由 EX_RST 控制硬复位，避免向 2.8 V PWDN 输入输出 3.3 V 高电平。
SCL/SDA 只拉低或高阻；确认 R10/R11 上拉到模块 **2.8 V**，不得额外上拉到 3.3 V 或 5 V。
FPGA 的 J8 Bank L5 按 3.3 V 输入标准约束；模块的数据/同步/PCLK 输出来自其 2.8 V 信号侧。
若实物转接板与这份原理图不同，需要重新确认电源、电平和引脚，不能套用此表。

## 接线表

断电接线。**不能把 J7 的 20 针排线直插 J8 的前 20 针：J8-2 是 5 V，摄像头 J7-2 需要 3.3 V。**

| 摄像头 J7 | 信号 | FPGA 板 J8 | FPGA 球位/说明 |
| --- | --- | --- | --- |
| 1 | GND | 37 | GND |
| 2 | 3.3 V | 39 | 3.3 V，不能接 J8-2 |
| 3 | SCL | 3 | AB21，开漏 |
| 4 | SDA | 5 | AB22，开漏 |
| 5 | VSYNC | 32 | P16 |
| 6 | HREF | 34 | R17 |
| 7 | EX_RST | 23 | U20 |
| 8 | D0 | 16 | R18 |
| 9 | D2 | 20 | N17 |
| 10 | D1 | 18 | T18 |
| 11 | D4 | 24 | P15 |
| 12 | D3 | 22 | P17 |
| 13 | D6 | 28 | N13 |
| 14 | D5 | 26 | R16 |
| 15 | D7 | 30 | N14 |
| 16 | PCLK | 8 | Y18，GMCLK |
| 17 | PWDN | 25 | V20，固定低电平 |
| 18 | XCLK | 不接 | 使用模块 Y1 |
| 19 | 补光 LED | 不接 | 本版不控制补光 |
| 20 | GND | 38 | GND |

## FPGA 数据通路

```text
模块 24 MHz → OV5640 SCCB 初始化 → 640×400 RGB565 DVP
                                   ↓
完整行/帧检查 → 8 像素打包 → 异步 FIFO → FPGA DDR 写入
                                   ↓
整帧读回校验 → 4 KiB 页缓存 → PCIe DMA → RK3568 DDR coherent 缓冲
```

SCCB 地址为 0x3c，读取 0x300a/0x300b，必须得到 0x5640 才开始配置。
按模块例程生成 264 项写寄存器序列，包含软复位等待、RGB565 设置及 640×400 尺寸覆盖。
寄存器写入 NACK 最多尝试三次，失败后不发布图像。

保留例程 `0x4300=0x6f`：DVP 先输出像素低字节，再输出高字节；FPGA 按此拼成 RGB565，
ARM 内存和 `.rgb565` 文件均为 RGB565 小端格式。
这一顺序也可在 [Linux 上游 OV5640 驱动的 RGB565_2X8_LE 项](https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5640.c) 核对。

最后一个 128 位字延迟到下一次 VSYNC，在完整原始字节/行计数通过后才附加 EOF。
短行、长行、字节不齐或 FIFO 溢出不会发布为完整帧。DDR 写操作用填充结束后丢弃坏帧，再重采。
DDR 读回滚动校验失败也丢弃重采。该校验是数据通路诊断，不是密码学 CRC。
一帧交给主机后保持不变，直到该帧最后一页已被 DMA 取走；不会把下一帧覆盖到正在读的帧中。

KEY0 复位端点和摄像头初始化，KEY1 本版保留，不再切换内部图案。
J16 为 PCIe link-up；M17 在有效帧就绪时亮，发生配置或通路错误时闪烁。
当前时序约束按 42 MHz PCLK、DVP 输入最大 8 ns/最小 1 ns 路径预算建模；上线时需核对实际 PCLK 与波形。

## FPGA SRAM 下载

2026-10-21 实测：下载到 100% 后曾报 `JtagServer-0312: DONE pin did not go high`。
JTAG 能识别芯片并不代表配置已经完成。先按板上 **F_RESET**（不是 KEY0/KEY1），
关闭 Fabric Configuration 下载窗口以释放下载器；保留本机 JTAG Server（端口 65420）。
然后在 PowerShell 运行仓库已有的下载脚本：

```powershell
& 'F:/PDS_2022.2-SP6.4/bin/cdt_cfg_shell.exe' -file 'F:/AADCS_git_zyxw/scripts/program_fpga.tcl'
```

脚本选择交付目录 `firmware/fpga/distortion-video/unified/boardtop.sbit`，
设置 1 MHz JTAG、`cfg_set_device_property -device_index 0 -program 1`，
显式启用 **Enable WakeDownReconfigure**，只配置 FPGA SRAM，不写 Flash/eFuse。
若使用 GUI，需在器件编程属性中设置上述选项；GUI 和脚本不要同时占用下载器。

本次复位后输出 `The done bit is 1`、`Program execute successfully`，
状态回读 `0x0817fca0`，DONE、DONE 输入和 wakeup_over 均为 1，CRC/ID 错误为 0。
完整状态和日志保存在 `docs/verification/2026-10-21-camera/jtag-*`。
这是配置成功的证据，摄像头初始化、DDR、PCIe 和 ARM 载荷仍需分别验证。

## ARM 接收程序

源码：`rk3568_AADCS/apps/ov5640_capture/`。
预编译 ARM64 静态程序：`firmware/rk3568/ov5640-capture`，不依赖板上另装用户态库。
需要现有 `/dev/pcie_dma_memcpy` 驱动，支持提供例程中的 SETUP/SHUTDOWN ioctl 及 coherent DMA mmap。
驱动返回的 DMA 总线地址用于 FPGA 描述符，不能替换为 malloc 指针或任意物理地址。

在 RK3568 上以有 PCIe BAR 和 DMA 设备访问权限的用户运行，例如：

```sh
chmod +x ./ov5640-capture
sudo ./ov5640-capture --frames 1 --output frame.rgb565 --ppm frame.ppm
sudo ./ov5640-capture --frames 30
```

默认 PCIe 路径为 `/sys/bus/pci/devices/0002:21:00.0`，若实际枚举地址不同：

```sh
sudo ./ov5640-capture --pci /sys/bus/pci/devices/实际BDF --frames 1 --ppm frame.ppm
```

`frame.ppm` 可用普通图片查看器打开；这是接收工具，不启动 HDMI/GTK 窗口。
`--frames 0` 连续接收，Ctrl+C/SIGTERM 在完成当前帧后停止。
请只运行一个采集程序；旧的 `fpga-view`、`fpga-probe --mode line` 不兼容此版 CAM2 协议。
需要重新采集时，停止旧程序后按 KEY0，再启动新程序，避免接着旧的半帧游标读取。

程序先检查 CAM2 版本、尺寸和状态，申请 512,000 字节 DMA 缓冲，按 4 KiB 边界提交 125 个描述符，
逐个等待 FPGA 完成计数，最后核对内存滚动校验。它不使用固定延时来假定 DMA 已完成。
驱动必须提供 coherent 映射；仅增加用户态内存屏障不能修复驱动中的非一致性缓存映射。
若描述符超时，程序不调用 SHUTDOWN 归还仍可能被 DMA 写入的分配；复位 FPGA 并重启 ARM 后再重试。

在 Linux 上重编译：

```sh
cd rk3568_AADCS/apps/ov5640_capture
make CC=aarch64-linux-gnu-gcc
make test CC=gcc
```

板上本机编译时使用 `make CC=gcc`。本次预编译使用 Zig 0.13.0 的 `aarch64-linux-musl` 静态目标。

## 寄存器（BAR0 只读，字节偏移）

| 偏移 | 含义 |
| --- | --- |
| 0x00 | `0x43414d32`，CAM2 |
| 0x04 | `0x00020000` |
| 0x08 | bit0 帧就绪，bit1 DMA 正忙，bit2 通路错误，bit3 摄像头配置成功，bit4 配置错误 |
| 0x0c | 已接受最后一个 TX TLP 的累计描述符完成数 |
| 0x10 / 0x14 / 0x18 / 0x1c | 宽 / 高 / stride / 帧字节数 |
| 0x20 | 已校验并发布的帧数（不是所有传感器帧的计数） |
| 0x24 | 尝试采集时丢弃的坏帧数，不计等待主机期间未采集的帧 |
| 0x28 / 0x2c | 当前字节游标 / 当前帧滚动校验 |
| 0x30 | 摄像头 ID，成功时 0x5640 |
| 0x34 | [15:8] 初始化错误，[7:0] hostlink 错误 |
| 0x38 / 0x3c | 初始化寄存器索引 / DDR-页缓存通路错误 |

BAR1 的 0x110/0x120 为 DMA 地址低/高字，0x100 写 `0x01000000 | (字节数/4-1)` 提交 FPGA→ARM 描述符。
描述符长度为 16–4096 字节、16 字节对齐，不跨 4 KiB 页；当前仅支持 32 位 DMA 地址。
主机完成计数表示 FPGA 端 TX 接受，不等于 CPU 已观察到内存写入，因此接收工具还检查 coherent 缓冲内容。

初始化错误：1=ID 访问 NACK，2=ID 不是 0x5640，3=配置写入持续 NACK。
通路错误：1=DDR/页缓存协议错误，2=DDR 初始化状态丢失，3=通路超时，6=非法页请求。

## 验证范围

本机验证包括 SCCB 线级从机模型、坏帧/溢出测试，以及
DVP→DDR 模型→实际厂商 DMA RX/控制器/TX 的端到端像素比较与随机反压。
保留已有单元测试，结果及最终 PDS 时序、资源、位流输入指纹在 `docs/verification/2026-10-21-camera/` 和固件目录。
PDS 构建成功仅证明当前约束模型下可实现；本版已通过 FPGA SRAM 下载和 DONE 状态回读，未执行真实摄像头采集、ARM 驱动运行或实际帧率测量。
