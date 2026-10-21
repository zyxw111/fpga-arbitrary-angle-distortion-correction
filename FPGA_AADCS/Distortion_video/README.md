# OV5640 PCIe 采集工程

唯一入口：[board_video.pds](board_video.pds)，顶层 `boardtop`，PG2L100H-6IFBG484。
当前实现 OV5640 DVP RGB565 640×400 → FPGA DDR 完整帧 → PCIe → RK3568 DDR。
这是完整帧采集/发送模式，主机取完后才重新采集，不是 1080p30 无丢帧连续视频。
当前板级通路不调用畸变/仿射核心，旧三模式内部演示不再作为板级默认输入。

**接线、电气约定和 ARM 命令以 [OV5640 使用说明](../../docs/ov5640-camera.md) 为准。**
使用模块自带 24 MHz 晶振，不连接/驱动 J7-18 XCLK。SCCB 开漏，PWDN 保持低。
KEY0 复位，KEY1 本版保留。J16 显示 PCIe 链路，M17 显示帧就绪或错误闪烁。

从仓库根目录构建：

```powershell
./FPGA_AADCS/Distortion_video/build.ps1 -PdsRoot 'F:/PDS_2022.2-SP6.4'
```

批处理位流为 `build/generate_bitstream/boardtop.sbit`，当前保存的固件在
[boardtop.sbit](../../firmware/fpga/distortion-video/unified/boardtop.sbit)。
GUI 构建会生成对应输出目录；这些都是中间结果，工程入口始终是本目录的 `board_video.pds`。

RTL 回归（包含旧核心和新摄像头测试）：

```powershell
python FPGA_AADCS/Distortion_video/sim/regress.py --bin 'Icarus安装目录/bin'
```

结果写入 `build/sim/`。新增测试覆盖 SCCB 真实线级读写、初始化重试、DVP 帧有效性、
FIFO 溢出和 DVP→DDR→实际 DMA 收发逻辑的逐像素比较与随机反压。
本机工具缓存为 `F:/AADCS_git/.cache/tools/iverilog/bin`。

`source/rtl` 为硬件模块，`source/pcie_dma` 为 DMA，`ipcore` 为厂商 IP，`sim` 为验证源码。
`doc/` 和 `import_manifest.json` 保留导入时历史资料，旧路径及三模式描述不作为当前操作依据。
CAM2 寄存器及匹配 ARM 接收程序见 [使用说明](../../docs/ov5640-camera.md)，
本阶段改动见 [改动记录](../../docs/changes/010-ov5640-pcie-camera.md)。
未执行本版下载、实板摄像头采集或 ARM 接收实测。
