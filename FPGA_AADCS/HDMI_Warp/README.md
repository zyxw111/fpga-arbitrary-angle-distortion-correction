# HDMI 诱骗、在线畸变矫正与 PCIe 显示

入口 `hdmi_warp.pds`，顶层 `hdmi_warp_top`，PG2L100H-6IFBG484 / PDS 2022.2-SP6.4，
本地分支 `zyxw-gpt`。只打开源码目录的 PDS；build 内为中间工程。原内部视频工程保留。

合入 `F:/AADCS_git/hdmi_dummy_plug/v2.0` 的七档 EDID、MS7200 初始化、0x03→0x02
模式切换修复、下降沿采样、完整帧检查和频率检测。源 dummy 工程不改，不需另烧 dummy。

```text
Windows HDMI → HDMIK V1.1 / MS7200（FPGA 装载 EDID）
 → RGB888 下降沿采样 → 帧检查 → RGB565 / 异步 FIFO
 → FPGA DDR 输入帧：字节地址 0，最大 1920×1080×2
 → 逆仿射 → Brown 畸变映射 → 四邻域 DDR 读取 → 双线性插值
 → FPGA DDR 输出帧：字节地址 0x800000，640×400 RGB565 LE
 → DDR 整帧读回校验 → PCIe DMA → RK3568 coherent DDR → 原 fpga-view
```

输入宽高按有效视频帧识别，支持不超过 1920×1080、像素数为 128 倍数的逐行 RGB 信号。
EDID 声明 VGA60、720p50/60、1080p30/50/60。本合并工程的硬件结论见
`checks/2026-10-26/result.md`；源 dummy 接收实测不能代替当前整链路实测。

这是逐像素的**帧快照实现**：采一帧、矫正、校验，等 ARM 取完才采下一帧。
期间跳过其他源帧，**不承诺 30/60 fps 矫正输出**。坏帧、FIFO 溢出、中断会完成
已开始的 DDR 事务并丢帧，不复位在途 DDR/PCIe。

上电参数按 1920×1080、零畸变/旋转、比例 1/3 设置，输出上下留黑。输入其他尺寸或
切换分辨率后，用 `warpctl.py apply` 重新适配。演示系数不是镜头标定结果。

## 接线、按键

仅适用 **HDMIK V1.1**。Windows 接子卡 HDMI IN，ARM 显示器接主板 HDMI 输出。
子卡与摄像头引脚重叠，不可同时接入。

| 信号 | FPGA 球位 |
|---|---|
| PCLK / DE / HS / VS | W19 / P16 / U17 / R17 |
| R[7:0] | AB21 Y18 AB22 Y19 N15 V18 AA19 V19 |
| G[7:0] | AB20 R18 V17 T18 W17 N17 AA18 P17 |
| B[7:0] | AB18 P15 U20 R16 V20 N13 W20 N14 |
| SDA / SCL | AA20 / AA21，开漏，MS7200 地址 0x2B |

KEY0 重置整个链路，先停止采集程序。KEY1 循环 EDID：0 多模式、1 VGA60、2 720p50、
3 720p60、4 1080p30、5 1080p50、6 1080p60；等待 I²C 空闲后重新配置。
Windows 可能需要重插 HDMI 才会读取新 EDID；未假定未经验证的 HPD 寄存器有效。
核对 Windows **有源信号分辨率**，桌面分辨率可能受显卡缩放影响。

内部像素时钟约束 148.5 MHz。接收器外部输出延迟/走线资料不足，没有使用虚构输入
延迟宣称板级签核；下降沿采样选择来自源 v2.0 实测，仍需检查当前整链路。

## 构建、下载

```powershell
./build.ps1 -Seed 4
./program.ps1
# 如需内部探针，另构建并检查调试版本：
./build.ps1 -Debug -Seed 4
./program.ps1 -Debug
```

普通位流 `build/generate_bitstream/hdmi_warp_top.sbit`；调试版在 `build/debug/generate_bitstream`。
专用 program.ps1 检查对应时序报告、以 500 kHz JTAG 下载 SRAM，不写 Flash/eFuse。
`firmware/fpga/hdmi-warp` 已同步本次上板验证位流；以后修改源码仍需重新构建、更新交付快照。
根目录旧下载脚本默认指向内部图案。
修改 `config/warp.json` 可改变上电参数；在线调参无需重新编译。

## ARM 显示、调参

ARM 仍用 `RK3568-PCIE` 的 6cf5ab5 采集/显示源码和 coherent DMA 驱动。新增独立工具
`tools/warpctl.py`、`tools/warp_math.py`，一起复制到板卡 `/userdata/fpga-view/tools/`。
需 root/Python3，无第三方 Python 包。先用原程序恢复 JTAG 下载后的 BAR，再启动窗口：

```sh
/userdata/fpga-view/fpga-probe --mode cam2 -n 1 -v
sh /userdata/fpga-view/run.sh --mode cam2 --fit
```

仅运行一个采集实例。另一 SSH 会话可与窗口并行调参：

```sh
python3 /userdata/fpga-view/tools/warpctl.py status
python3 /userdata/fpga-view/tools/warpctl.py apply --save /userdata/warp.json
python3 /userdata/fpga-view/tools/warpctl.py apply --config /userdata/warp.json \
  --k1 -0.12 --k2 0.02 --angle-degrees 12 --save /userdata/warp.json
```

不提供 `--config` 时，每次 apply 从检测尺寸的零畸变等比例适配配置开始，不继承上次参数。
支持 fx/fy/cx/cy、k1/k2/k3/p1/p2、旋转、缩放、XY 平移；工具检查数值范围，读回影子
参数后提交。整组在处理器安全空闲时生效，当前帧继续使用旧参数，DMA 输出帧保持不变。
超时不撤回已发提交，先检查 pending。镜头系数应取自真实标定。

上位机可 SSH 调同一命令，密码交互输入，不保存进工程：

```sh
ssh -p 2222 root@10.144.144.2 "python3 /userdata/fpga-view/tools/warpctl.py apply --k1 -0.12"
```

协议详见 ARM 仓库 `docs/hdmi-warp-control.md`。CAM2 仍为 640×400、stride1280、512000 字节。
BAR0 0x80 WRP1、0x84 pending/rejected、0x88 accepted、0x8C applied 参数代号；
0x90 是当前处理/就绪帧代号，ready 时可与帧关联；0x94 为该帧源高宽。
BAR0 0x100..140 读影子，BAR1 0x200..240 写 17 个完整 DWORD，0x250 提交非零新代号。
旧 DMA 0x100/110/120 不变。0x74/78/7C 为活动高宽/实测像素 Hz/源帧数。

## 验证

```powershell
python sim/regress.py
python tools/check_default_mapping.py
python tools/check_sink.py --build build
```

覆盖独立浮点/整数坐标模型、真实 PCIe RX/MMIO/CplD/TX、在线系数变化和精确像素比较、
HDMI v2 接收、坏帧/FIFO、尺寸/频率切换、I²C、七档 EDID、原子参数提交及复位。
硬 PCIe/DDR PHY 在仿真中由模型替代。历史检查保存在 checks，不能用旧版记录证明新版成功。
