# HDMI 输入、畸变矫正与仿射变换

独立的 PG2L100H-6IFBG484 / PDS 2022.2-SP6.4 工程。入口是本目录的
`hdmi_warp.pds`，顶层 `hdmi_warp_top`。原 `Distortion_video` 工程保持原样。
只打开源码目录的 PDS；`build` 内是构建工具临时生成的工程。

## 数据链路

```text
HDMIK V1.1 / MS7200
  RGB888 + PCLK + DE + VS
  -> RGB565 打包、异步 FIFO、完整帧检查
  -> FPGA DDR 输入帧（字节地址 0）
  -> 逆仿射 + Brown 畸变映射 + DDR 四邻域读取 + 双线性插值
  -> FPGA DDR 输出帧（字节地址 0x100000）
  -> 输出帧 DDR 读回校验
  -> PCIe Memory Write DMA -> RK3568 驱动分配的 coherent DDR -> ARM 显示
```

第一阶段发送端设置 **640×480、60 Hz、RGB**，FPGA 输出 **640×400 RGB565 小端**。
初始化表沿用配套 EDID，发送端可能自动选择更高分辨率；请手动固定为上述模式。
默认零畸变、零旋转、单位缩放，对输入居中取 640×400。默认 VS 低有效；可在
`config/warp.json` 修改 `vs_active_high`。DE 界定有效像素/行；HS 预留为接收器引脚。
源不能暂停，故每次等待完整新帧，处理及主机读取期间跳过输入帧。短帧、长行、
FIFO 溢出会填完已开始的 DDR 写事务、丢弃本帧，再等待新帧。

这是低分辨率功能验证的帧快照实现。每次处理一个像素、四项 DDR 字缓存，
**不承诺 640×400 的 30/60 fps，也尚未实现 1080p30**。接收时序 60 Hz 与交付帧率不同。
1080p 后续需调整输入/输出缓冲布局、提高随机读缓存效率、并行化映射及更新 ARM 几何参数。

## 连接与版本

依据用户提供的 `RK3568_HDMI_IN/RK3568_HDMI_IN/hdmi_loop_v1.1.fdc`。
只适用于已确认的 **HDMIK V1.1**。必须使用子卡 HDMI **IN** 接口；主板的 RK3568 HDMI
输出口不能作为这里的 FPGA 视频输入。子卡替代原摄像头接线，二者引脚重叠。
按配套子卡连接器及丝印方向连接，不能凭本例程推断反插方向。

| 信号 | FPGA 球位 |
|---|---|
| PCLK / DE / HS / VS | W19 / P16 / U17 / R17 |
| R[7:0] | AB21 Y18 AB22 Y19 N15 V18 AA19 V19 |
| G[7:0] | AB20 R18 V17 T18 W17 N17 AA18 P17 |
| B[7:0] | AB18 P15 U20 R16 V20 N13 **W20** N14 |
| I²C SDA / SCL | AA20 / AA21 |

接收端 I/O 使用配套约束的 LVCMOS33。V1.0 的 W19/W20 分配不同，不能下载本版本位流。
MS7200 地址是 7 位 0x2B（总线地址 0x56/0x57）；沿用配套 300 项初始化及状态轮询，
SCL/SDA 改为开漏，并检查 ACK。未检测到输入频率状态时继续等待；NACK 报 0x10。
配套例程没有给 `rx_rst_n` 输出分配引脚，本工程同样不凭空分配复位脚。

FDC 像素时钟按 VGA 25.175 MHz 设置；输入延迟暂使用 1～10 ns 的工程预算。
静态时序通过仅说明满足此约束，实际接收器输出相位/板间走线仍需上板核验。

## 调整参数与构建

编辑 `config/warp.json`，然后运行：

```powershell
./build.ps1
```

脚本先运行 `tools/configure.py` 生成 `hdmi_config.v` 和顶层几何参数，再构建隔离的
`build/hdmi_warp.pds`；最终位流是 `build/generate_bitstream/hdmi_warp_top.sbit`。
本次交付的位流另存于仓库 `firmware/fpga/hdmi-warp/hdmi_warp_top.sbit`。
修改参数重新构建后，应下载 `build/generate_bitstream` 下的新位流；交付目录快照不会自动更新。
原 `scripts/program_fpga.tcl` 仍默认下载旧内部视频源；使用该脚本下载本工程时，
先把环境变量 `AADCS_BITSTREAM` 设为这个新位流的绝对路径。
默认使用本机已有 Python；其他电脑可传 `-PythonExe C:/Python312/python.exe`。
GUI 直接编译前也应先执行 `python tools/configure.py`。

参数包括 `fx/fy/cx/cy`、`k1/k2/k3/p1/p2`、`angle_degrees`、`scale`、
`translate_x/translate_y`。这些是编译期参数，不能通过按键或 ARM 在线改写。
`config/demo.json` 是非零畸变和 12° 旋转的演示参数；如要编译演示，将内容复制到
`config/warp.json` 后构建。演示数值**不是镜头标定结果**。

算法对每个输出点先计算逆仿射，再归一化并应用 Brown 模型：

```text
r² = x²+y²
s  = 1+k1*r²+k2*r⁴+k3*r⁶
xd = x*s+2*p1*x*y+p2*(r²+2*x²)
yd = y*s+p1*(r²+2*y²)+2*p2*x*y
source = (fx*xd+cx, fy*yd+cy)
```

逆仿射由旋转、缩放、平移及输入/输出中心生成；支持子像素坐标。
图像坐标 y 向下，正角度使显示内容逆时针旋转；正平移使显示内容向右/下移动。
越界邻点置黑后插值。内部 Q16.16、倒数焦距 Q2.30、采样坐标 Q20.12。
配置脚本限制数值范围，避免内部溢出；不支持任意超范围系数或透视单应矩阵。

## ARM 接收与显示

沿用仓库 `firmware/rk3568/ov5640-capture` 和原 coherent DMA 驱动，**无需因为 HDMI 来源
改驱动 ABI**。该程序名字带 OV5640，但校验的是通用 CAM2 帧协议。先保存一帧：

```bash
sudo ./ov5640-capture --frames 1 --timeout-ms 20000 --output frame.rgb565 --ppm frame.ppm
```

ARM 桌面若已有 Python3、numpy 和带 GUI 的 OpenCV，可用新增的预览脚本：

```bash
sudo python3 hdmi_preview.py --capture ./ov5640-capture
```

脚本位于 `rk3568_AADCS/apps/hdmi_preview/hdmi_preview.py`，逐帧调用已校验的接收程序，
转换 RGB565 并显示。此方案用于首阶段联调，逐帧分配/释放缓冲存在开销。
实际 PCI BDF 不同时传 `--pci /sys/bus/pci/devices/实际BDF`。不要同时运行旧 line 模式
显示程序；其数据协议不同。按 q/Esc 退出；Ctrl+C 可中断等待。

BAR0 保持 CAM2/00020000 和原尺寸寄存器；flags 新增 bit6 表示 HDMI，bit5 为 0。
bit3 表示接收器初始化完成，不能单凭此位判断视频当前是否锁定。
0x20/0x24 是已发布帧/异常丢帧数（跳过未采集的连续输入帧不计异常）；
0x30=0x7200，0x34 高字节是 I²C 错误、低字节是主机错误，
0x38 是正在访问的 MS7200 寄存器地址，0x3c 是帧处理错误。
KEY0 重置整个链路，KEY1 预留。按 KEY0 前先停止 ARM 接收程序。

## 验证

```powershell
python sim/regress.py --bin F:/AADCS_git/.cache/tools/iverilog/bin
```

覆盖独立浮点坐标参考、接收帧/溢出/同步极性、线级 I²C 从机模型，以及真实 PCIe
RX/MMIO/CplD/TX RTL 的完整处理数据链。仿真中的 DDR/PCIe PHY 用接口模型代替。
详见 `checks/verification.md`。没有连接真实 HDMI 源和 ARM 联调前，不能把仿真通过
写成实际显示成功；本次交付不会更改板上当前配置。
