# Distortion 工程交付与使用说明

更新日期：2026-10-18

本文按“已收到并解压 `Distortion` 工程压缩包”的情况编写。下文路径均相对于解压后的 `Distortion` 文件夹，不要求放在发送方原来的 E 盘目录。

## 1. 这个工程用来做什么

目标开发板为 **RK3568_MES2L100H**，FPGA 器件为 **PG2L100H-6IFBG484**。

当前提供不接摄像头的内部图像测试版本，用于验证校正算法及后续数据通路：

```text
内部生成图像 → 校正或直通 → 像素打包 → FPGA DDR3
           → 读回核验 → PCIe DMA → RK3568 接收、校验和显示
```

当前图像为 **640×400、RGB565 的静态测试帧**，可以反复传输。显示器接 **RK3568 的 HDMI OUT**，不要把它理解为 FPGA 直接输出 HDMI 的工程。

## 2. 先找对工作目录

```text
Distortion/
├─ doc/                          开发板手册及硬件资料
├─ rtl/                          早期 RTL，未与当前副本自动同步
├─ sim/                          早期仿真资料
└─ prj/
   ├─ Distortion_re/              原工程，保留作对照
   └─ Distortion_video/           当前开发和上板使用的工程副本
      ├─ source/
      │  ├─ rtl/                 当前 RTL 源码
      │  └─ pcie_dma/            PCIe DMA 收发逻辑
      ├─ ipcore/
      │  ├─ ddr3_100h/           DDR3 控制器和 PHY
      │  └─ pcie_test/           PCIe IP
      ├─ sim/                    仿真测试、参考图数据、回归脚本
      ├─ checks/                 各独立测试工程及构建结果
      ├─ doc/                    当前开发状态、验收和操作说明
      ├─ backup_*/               历次修改前的备份
      └─ Distortion_re.pds        保留的诊断工程入口，顶层为 vtop
```

**实际开发以 `prj/Distortion_video/source` 为准。不要直接修改原工程 `prj/Distortion_re`，也不要用外层 `rtl` 覆盖副本源码。**

`compile`、`synthesize`、`device_map`、`place_route`、`report_timing`、`generate_bitstream` 等目录是对应工程的构建结果；日志用于定位问题。不要把这些目录当作源码修改。

## 3. 三个可上板的工程入口

推荐使用 **PDS 2022.2-SP6.4**，并准备有效的器件许可。第一次可直接使用现有位流，不必先重新编译。

| 测试内容 | 使用的 PDS 工程 | 顶层模块 |
|---|---|---|
| 第一组：彩条 | `prj/Distortion_video/checks/board_bars/board_bars.pds` | `board_bars` |
| 第二组：畸变原图 | `prj/Distortion_video/checks/board_raw/board_raw.pds` | `board_raw` |
| 第二组：校正结果 | `prj/Distortion_video/checks/board_corrected/board_corrected.pds` | `board_corrected` |

每个工程目录下的文件用途相同：

- `generate_bitstream/同名.sbit`：下载到 FPGA 的位流。
- `report_timing/同名.rtr`：布局布线后的时序报告。
- `place_route/同名.prr`：布局布线、资源及实际 IO 信息。
- `build.ps1`：自动构建脚本。

例如彩条位流的完整相对路径是：

```text
prj/Distortion_video/checks/board_bars/generate_bitstream/board_bars.sbit
```

**不要误用 `prj/Distortion_video/Distortion_re.pds`：它仍选择诊断顶层 `vtop`，不是以上三个板级下载入口。**

## 4. 如何编译和选择功能

1. 在 PDS 中打开上表对应的 `.pds`。
2. 确认器件为 `PG2L100H`、封装 `FBG484`、速度等级 `-6`，并核对顶层名称。
3. 修改需要调试的源码后，依次完成编译、综合、器件映射、布局布线、时序分析和位流生成。
4. 确认没有错误，并检查时序报告包含 `All Constraints Met`，再使用新生成的 `.sbit`。

三个板级顶层文件位于 `prj/Distortion_video/source/rtl/`。其参数含义为：

| 参数 | 取值 | 含义 |
|---|---|---|
| `DEMO_GROUP` | `0` | 彩条 |
| `DEMO_GROUP` | `1` | 合成畸变测试图 |
| `DEMO_VIEW` | `0` | 第二组显示原始畸变图 |
| `DEMO_VIEW` | `1` | 第二组显示经过实际 RTL 校正的结果 |

通常直接选择三个现成工程即可。修改参数后必须重新生成位流，已有 `.sbit` 不会自动改变。

主要源码分工如下：

| 文件 | 作用 |
|---|---|
| `demo.v`、`chart.v`、`pat.v` | 内部图像及扫描时序生成 |
| `warp.v`、`coord.v`、`addr.v`、`bilin.v` | 校正通路、坐标计算、邻域寻址及插值 |
| `pack.v`、`afifo.v` | 像素打包及跨时钟传输 |
| `still.v` | 内部帧写 DDR、读回核验和分段读取 |
| `bridge.v` | DDR 与 PCIe 之间的完整段缓冲 |
| `hostlink.v` | ARM 请求、供数准备和完成状态 |
| `burst.v`、`fetch.v`、`ddrlink.v` | DDR 突发写入、读取及真实 IP 适配 |
| `board_bars.v`、`board_raw.v`、`board_corrected.v` | 连接 DDR、PCIe 和物理引脚的板级顶层 |

板级入口使用 R4/T4 的板载 125MHz 差分时钟，在内部生成 25MHz；PCIe 使用独立参考时钟。当前顶层不使用 V4，也不连接摄像头。首次联调不要随意更改时钟、DDR 引脚、电平或 IP 参数。

工程主要源码/IP 引用为相对路径。`build.ps1` 中的 PDS 安装位置和 `sim/regress.py` 中的仿真工具位置属于发送方电脑配置，换电脑后按实际安装位置修改；通过 PDS 界面构建不需要运行该 PowerShell 脚本。厂商 RAM 模板中仍有旧初始化文件路径，如工具报告该路径缺失，应核对具体 IP 用途及初始化配置，不要随意用其他文件替代。

## 5. 第一次如何上板

建议按 **彩条 → 畸变原图 → 校正图** 的顺序测试。

1. 正常连接开发板电源及 FPGA JTAG 下载器，暂不接摄像头或转接板。
2. 使用 PDS 配套的 Fabric Configuration 工具扫描器件，核对 PG2L100H。
3. 添加所选 `.sbit`，先下载到 **FPGA SRAM**，首次测试先不固化 QSPI Flash。
4. 检查 PCIe 链路及 DDR 图像就绪状态，再运行 ARM 接收测试。
5. 切换图像时，重新下载另一份 `.sbit`，并重新运行 ARM 测试。

SRAM 程序在断电后丢失；板卡重启或重新下载可能需要恢复 PCIe 枚举。停止所有采集程序后再处理对应端点，不要随意移除 PCIe 根桥。

指示灯含义：

- **J16 常亮**：PCIe 链路建立。
- **M17 常亮**：DDR 内部图像核验通过。
- **M17 闪烁**：检测到错误，应结合 ARM 读取的错误信息排查。

指示灯通过不等于整帧传输已经正确，最终仍需 ARM 完整比对。

## 6. ARM 接收与显示需要什么

**仅收到 `Distortion` 压缩包时，不能假定已经包含 ARM 应用或测试脚本。** FPGA 工程中虽然有 PCIe 逻辑，但接收、校验和显示由 RK3568 上的软件完成。

需要发送方另外提供本次的 **“不接摄像头上板测试包”**，或者从真实 ARM 工程取得配套的 `tools/board_demo`。运行目录必须包含：

```text
board_demo/
├─ board_capture.c
├─ board_contract.h
├─ board_view.c
├─ run_board_test.sh
└─ expected/
   ├─ bars.rgb565
   ├─ raw.rgb565
   └─ corrected.rgb565
```

将这套文件完整复制到 RK3568，例如 `/home/rock/board_demo`。先关闭其他采集程序，再检查设备：

```sh
lspci -nn
ls -l /dev/pcie_dma_memcpy
```

应找到 `0755:0755` 的 FPGA 端点。默认 PCIe 地址为 `0002:21:00.0`，实际运行时以该板系统枚举结果为准。

```sh
cd /home/rock/board_demo
sudo sh run_board_test.sh 0002:21:00.0 3
```

脚本在板上使用 `cc` 编译，以上命令验证 3 帧。系统还需要现有的 `/dev/pcie_dma_memcpy` 分配服务；匹配该服务的内核源码目前尚未取得，本工程不包含替代驱动。

成功时应看到：

```text
PASS frame ... 512000 bytes exact
PASS board capture.
```

随后生成对应的 `captured_bars.ppm`、`captured_raw.ppm` 或 `captured_corrected.ppm`，内容来自实际接收的数据。具备 GTK3 开发环境和桌面会话时，可以用配套工具查看：

```sh
./board_view captured_corrected.ppm
```

没有图形环境时，把 PPM 和 `board_test.log` 拷回电脑检查即可。

## 7. 常见问题

| 现象 | 优先检查 |
|---|---|
| 下载后没有预期图像 | 是否用了三个板级入口；显示器是否接 RK3568；ARM 是否运行配套程序 |
| `Wrong bitstream` | 位流是否更新、端点地址是否正确、BAR 是否可读 |
| `DDR/image not ready` | 板型、时钟、DDR 初始化和错误码 |
| `DMA completion timeout/error` | PCIe 状态、DMA 服务、是否有其他采集进程占用 |
| `Payload mismatch/stale DMA mapping` | 实际数据错误、字节排列或 DMA 映射一致性问题，不能直接忽略 |
| 换图案后仍显示旧图 | 是否重新下载正确位流、重新抓图并打开新输出文件 |

发生 DMA 超时后，先停止继续采集，重置 FPGA 并恢复 PCIe，必要时重启系统后重新下载 SRAM 程序。不要反复启动多个采集进程尝试覆盖故障。

## 8. 当前完成程度与交接结果

- 三份板级位流均完成 PDS 全流程，时序报告为 `All Constraints Met`。
- 44 组 RTL 回归、6 组 ARM 离线测试通过。
- 实际 PCIe DMA 收发 RTL 仿真覆盖 90 条描述符、350 个 TLP，以及两帧共 20480 像素的精确比较和随机反压。
- 尚未在实际开发板执行本版下载、抓帧或电压测量，离线测试结果不能代替实板结果。
- 本版用于内部静态图像、校正算法、DDR 顺序读写和 PCIe/ARM 链路测试，不代表连续摄像头、真实摄像头 DDR 随机读取缓存、运行时标定调参或 1080p60 已完成。

首次联调后，请保留并反馈：**所用位流名称、实际 PCIe 地址、`board_test.log`、三种模式的实抓 PPM，以及异常时的完整报错**。这些结果用于决定下一步是修复板级链路，还是继续接入真实摄像头。
