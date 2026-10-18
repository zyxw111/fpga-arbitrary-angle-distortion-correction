# Distortion 视频工程（2026-10-18 导入）

本目录来自交付包 `Distortion/prj/Distortion_video`，用于 PG2L100H-6IFBG484。
内部静态图像经过校正或直通、DDR3 写入与读回校验，再由 PCIe DMA 传给 RK3568。
显示器接 RK3568 的 HDMI OUT。原 `FPGA_AADCS.pds` 仍是此前的 PCIe 数据源测试工程。

## 工程入口

| 图像 | PDS 工程 | 顶层 |
| --- | --- | --- |
| 彩条 | [board_bars.pds](checks/board_bars/board_bars.pds) | `board_bars` |
| 畸变原图 | [board_raw.pds](checks/board_raw/board_raw.pds) | `board_raw` |
| 校正结果 | [board_corrected.pds](checks/board_corrected/board_corrected.pds) | `board_corrected` |

`Distortion_re.pds` 是诊断入口，顶层 `vtop`；实际板级测试使用表中的三个入口。
源码在 `source/rtl`，适配后的 DMA 在 `source/pcie_dma`，IP 在 `ipcore`，测试在 `sim`。
这些模块与旧 PCIe 工程分开编译，不要把两个源码目录同时加入同一工程。

## 本机使用

GUI：用 PDS 2022.2-SP6.4 打开相应 `.pds`。

PowerShell 构建示例（从仓库根目录执行）：

```powershell
./FPGA_AADCS/Distortion_video/checks/board_bars/build.ps1 -PdsRoot 'F:\PDS_2022.2-SP6.4'
```

原始交付位流及厂家工具的时序、资源报告在
[firmware/fpga/distortion-video](../../firmware/fpga/distortion-video/README.md)。
自行构建的输出在对应工程的 `generate_bitstream/`，不会覆盖保存的交付位流。

RTL 回归：

```powershell
python FPGA_AADCS/Distortion_video/sim/regress.py --bin 'Icarus安装目录/bin'
```

本机现有工具目录为 `F:/AADCS_git/.cache/tools/iverilog/bin`；脚本接受 `--bin` 指定目录，
无需修改发送方保留的默认路径。回归结果生成在 `checks/regression/`。
为兼容本机 Icarus 13，调整了 `still.v` 和 DMA 适配文件中声明与使用的先后顺序；
信号连接、寄存器行为和状态机逻辑未改动。

## 协议及板级状态

本版由 BAR0 读取版本、图像就绪和完成计数，BAR1 写入 DMA 描述符。
它需要配套的 ARM `tools/board_demo`，不能直接沿用旧版的 line 模式显示步骤。
本次交付文件未包含该 ARM 测试包，仍需取得匹配的接收、比较和显示程序。

板级入口使用 R4/T4 的 125 MHz 差分时钟，内部生成 25 MHz；不使用旧测试工程的 V4 时钟。
时钟、DDR 约束、SCBV 设置及 IP 保持交付版本。导入操作没有执行下载或板级测试。

原始交付说明保存在 [交付说明](../../docs/imports/2026-10-18/FPGA工程交付与使用说明.md)。
仓库内位置与原压缩包不同，本文的工程链接为合入后的入口。详细导入和验证记录见
[合入记录](../../docs/changes/007-import-distortion-video.md)，文件来源和改动哈希见 `import_manifest.json`。
