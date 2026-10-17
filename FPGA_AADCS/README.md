# AADCS FPGA PCIe 测试工程

本工程在 PG2L100H-6IFBG484 上生成测试数据，通过 PCIe Memory Write
发送到 RK3568。第一阶段使用内部数据源；视频采集、DDR3 帧缓存与畸变矫正后续接入。

## 工程入口

- GUI：用 PDS 2022.2-SP6.4 打开 `FPGA_AADCS.pds`，顶层 `aadcs_pcie_top`。
- 批处理：在仓库根目录执行 `./scripts/build_fpga_pcie.ps1`。
- 调试版：`./scripts/build_fpga_pcie.ps1 -DebugCore`，输出在 `build/debug/`，包含双时钟 DebugCore。
- 指定安装路径：`./scripts/build_fpga_pcie.ps1 -PdsRoot '实际 PDS 安装目录'`。
- 输出：`build/generate_bitstream/aadcs_pcie_top.sbit`。
- 仿真：`./scripts/test_fpga_pcie.ps1 -IcarusBin 'Icarus 的 bin 目录'`。
- GUI 工程检查：`./scripts/check_fpga_project.ps1`，使用 PDS 解析 `.pds` 并编译 RTL；批处理构建会先执行此检查。

构建输入全部在仓库内，工程不引用 `E:/Downloads/fpga`。工具链与构建结果不进入 Git。
本机缓存的 Icarus 可由测试脚本自动发现；新机器需安装 Icarus 并传入目录或加入 PATH。

## 组成

| 路径 | 用途 |
| --- | --- |
| `rtl/aadcs_pcie_top.v` | PCIe IP、DMA、复位同步、按键模式及 LED |
| `rtl/pcie_test_source.v` | 128-bit 同步测试数据源 |
| `rtl/pcie_reset_control.v` | 独立时钟上电复位、同步释放和按键消抖 |
| `rtl/pcie_dma/` | 参考 PCIe DMA RTL 及必要修改 |
| `ip/pcie_test/` | 本地 PCIe IP 源码与 IDF，PCIe 1.2c，Gen1 x2 |
| `constraints/pcie_100h.fdc` | 100H 板卡引脚、HSST 位置及时钟约束 |
| `project/build.tcl` | 可复现的 PDS 构建脚本 |
| `project/sources.txt` | 综合输入清单 |
| `sim/` | 数据源、寄存器及实际 MWr 数据通路的仿真 |
| `reference_manifest.json` | 导入文件来源和 SHA-256 |

## 板卡操作

- KEY0（M15）：向 PCIe IP 断言复位，并重启约 10.49 ms 的上电复位计时；主机可能需要重新枚举。旧版实测 KEY0 不能恢复链路，不能将它描述为已验证的恢复方法。
- F_RESET：板级 FPGA 重配置。主机报告中有效的恢复方法；重配置载入的内容由板上启动配置决定，未固化的 JTAG 位流可能被替换。
- KEY1（M16）：释放时为彩条；按住时为递增数据。两个按键都不是主机 PERST 引脚。
- LED3（J16）：PCIe 两个 link-up 状态均有效时点亮。
- LED4（M17）：数据读取计数的分频指示；短传输时不一定可见闪烁。
- PCIe 100 MHz 差分参考时钟：F6/E6；两个 HSST 通道按板卡原连接约束。
- 独立 25 MHz 板载时钟：V4，LVCMOS15，用于配置完成后的复位计时，不依赖 PCIe 时钟。

**切换 KEY1 模式前停止接收程序，按键稳定后再启动。** 连续稳定约 2.1 ms 后切换，
同步清空 DMA 和源指针；运行中切换会中断正在传输的描述符。
默认彩条帧为 640x400，不随主机 `--size` 自动改变。

## 数据格式

彩条：640x400，RGB565，1280 字节/行，512000 字节/帧。低地址存储前面的像素，
每个 RGB565 像素的两个字节交换，匹配现有 `RK3568-PCIE` 接收程序的默认 `--swap`。
上方是八色彩条，下方为具有多种像素值的渐变，避免纯八色图被接收程序误报为无信号。

每帧开头 16 字节是原始状态头，未做 RGB565 字节交换：

| 32-bit 字序 | 值 |
| --- | --- |
| 0 | `0xD5000001` |
| 1 | `0xA55A0000` |
| 2 | `0x5A000000` |
| 3 | `0x3568CAFE` |

状态头占据左上角八个像素；其中的摄像头/DDR 状态位为零，因为本阶段没有这些模块。
接收程序可在读取起点不位于帧首时利用它对齐行序。

递增模式：按 32-bit 小端字发送 `0,1,2,3,...`，每次读取产生四个连续字。
该模式没有视频状态头。连续描述符间计数保持连续，复位或模式改变后从零开始；
接收程序初始化中的丢帧和预读也会消耗数据，所以最终抓到的第一字不一定是零。

源只在 DMA 接受一次同步读请求时前进；主机暂停、描述符之间等待时保持当前位置。

## RK3568 验证

FPGA 配置完成后检查 `lspci -nn`，预期厂商/设备 ID 为 `0755:0755`。
本项目使用 BAR1 描述符接口和板上 `/dev/pcie_dma_memcpy` 的 DMA 内存分配服务。
后者是运行依赖，并非本仓库已经提供并验证的驱动；需使用匹配的板卡内核。
现有 `RK3568-PCIE` 程序会启用 Memory Space 和 Bus Master。

使用已有接收程序，例如它已部署在 `/userdata/fpga-view` 时：

```sh
sudo /userdata/fpga-view/fpga-probe --mode line --size 640x400 -n 4 -o /tmp/pcie-test
/userdata/fpga-view/run.sh --mode line --size 640x400 --swap --fit
```

BAR 路径取决于实际枚举地址；如果不是程序默认的 `0002:21:00.0`，两个程序都需用
`--bar /sys/bus/pci/devices/实际地址/resource1` 指定。读取 BAR 和 DMA 设备需要相应权限。
启动脚本的显示参数与权限应沿用板上已有配置。

必须显式使用 `--mode line`。本阶段不实现 `0x180/0x184/0x188` 整帧自动流寄存器，
也不实现分页 BAR0 视频窗口；这两个旧协议不是出图的必要条件。

主机每条描述符：先写 BAR1+0x110 的目标总线地址，再写 0x120 的高地址，最后写 0x100。
详见 `../docs/pcie-test-protocol.md`。描述符必须串行发送并留出完成时间；本阶段沿用
参考接收程序的节拍等待，没有增加完成中断或可轮询的完成寄存器。

## 验证边界

本地仿真覆盖完整彩条帧、帧循环、暂停、字节序、32/64-bit 地址寄存器、4 KiB 边界、
4096 字节请求、连续描述符和 MWr 发送背压。新增实际 BAR1 TLP 输入到主机内存的逐字验证，
包括两帧、1000 条描述符、地址和覆盖率；`./scripts/test_fpga_gate.ps1` 还会调用 ADS 综合并验证
数据源和复位控制的门级网表。记录见 `../docs/changes/006-pcie-report-fixes.md`。

仿真使用实际 DMA 寄存器和包发送 RTL，但不模拟 PCIe 模拟 PHY、Linux 驱动或真实链路。
主机侧旧版实测已发现错误；修复版尚需重新验证载荷。仿真不代表真实链路稳定性或比赛算法完成。

## 参考代码

来源为用户提供的 `E:/Downloads/fpga/prj/ipcore/pcie_test`，主要使用 IP 本体和原始
`example_design/rtl/pcie_dma_ctrl`，没有导入旧摄像头、DDR3、裁剪算法或历史位流。
保留厂家版权头。导入时将 IDF 的器件元数据由 50H 改为 100H，链路保持 Gen1 x2；
生成的 HDL 包装端口是 x2，IDF 原始图形 pin_list 中的 x4 宽度不是实际 HDL 端口。

DMA 修改包括：导出同步数据源接口、背压时禁止数据源前进、修正高地址写脉冲自清零、
修正背压下的包头重复、正确解释 1024-dword 请求长度，以及使用当前描述符进行 4 KiB 检查、
仅在有效接收载荷时触发 BAR1 写入。主机 PERST# 的实际接线尚不明确，该 IP 输入仍为常高；
新增上电复位不能代替主机的枚举和复位配合。
