# Distortion 视频工程（2026-10-18 导入）

本目录来自交付包 `Distortion/prj/Distortion_video`，用于 PG2L100H-6IFBG484。
内部静态图像经过校正或直通、DDR3 写入与读回校验，再由 PCIe DMA 传给 RK3568。
显示器接 RK3568 的 HDMI OUT。当前目录只有 `board_video.pds` 一个工程入口。

## 工程入口与按键

打开 [board_video.pds](board_video.pds)，顶层为 `boardtop`，器件为 PG2L100H-6IFBG484。
同一个位流包含三种模式，上电默认彩条；KEY1（M16，低有效）每次按下循环切换：

| 模式值 | 图像 | BAR0 GROUP / VIEW |
| --- | --- | --- |
| 0 | 彩条 | 0 / 1 |
| 1 | 畸变原图 | 1 / 0 |
| 2 | 校正结果 | 1 / 1 |

KEY1 有约 20 ms 消抖，长按只切换一次；切换尚未完成时的额外按键不排队。
KEY0（M15）复位整个端点，恢复彩条模式。
切换等待图像引擎空闲、当前 DMA 描述符和 PCIe TX 完成，再清除图像会话、
重新写入并校验 DDR；DDR PHY 和 PCIe IP 保持运行，无需重新枚举 PCIe。
重建期间 `frame_ready=0`；完成后游标和该模式的完成计数从零开始。

旧 PCIe 工程、三个独立板级入口、单元诊断 PDS 和 IP 附带的独立 PDS 已清理。
源码在 `source/rtl`，适配后的 DMA 在 `source/pcie_dma`，IP 在 `ipcore`，测试在 `sim`。
`doc/` 是导入时的历史开发资料，当前操作以本文为准。

## 本机使用

GUI：用 PDS 2022.2-SP6.4 打开 `board_video.pds`。
从仓库根目录构建：

```powershell
./FPGA_AADCS/Distortion_video/build.ps1 -PdsRoot 'F:/PDS_2022.2-SP6.4'
```

批处理输出为 `build/generate_bitstream/boardtop.sbit`；GUI 直接构建的输出为
`generate_bitstream/boardtop.sbit`。脚本在 `build/` 内生成独立 PDS 状态文件。
[firmware/fpga/distortion-video](../../firmware/fpga/distortion-video/README.md)
仅保留当前统一版位流和相应构建报告。
本次已生成并保存统一版 [boardtop.sbit](../../firmware/fpga/distortion-video/unified/boardtop.sbit)，
对应时序报告为 `All Constraints Met`，46 项 RTL 测试通过；尚未下载上板或进行 ARM 联调。

RTL 回归：

```powershell
python FPGA_AADCS/Distortion_video/sim/regress.py --bin 'Icarus安装目录/bin'
```

本机现有工具目录为 `F:/AADCS_git/.cache/tools/iverilog/bin`；脚本接受 `--bin` 指定目录，
无需修改发送方保留的默认路径。回归结果生成在 `build/sim/`。构建和仿真产生的文件均为可重新生成的输出；
在 PDS 中只打开本目录的 `board_video.pds`，不要打开输出目录里的临时工程。
为兼容本机 Icarus 13，调整了 `still.v` 和 DMA 适配文件中声明与使用的先后顺序；
信号连接、寄存器行为和状态机逻辑未改动。

## 协议及板级状态

本版由 BAR0 读取版本、图像就绪和完成计数，BAR1 写入 DMA 描述符。
统一版版本号为 `0x00010001`，保留 BAR0 的 0x00–0x30 布局，增加：

| BAR0 字节偏移 | 32 位内容 |
| --- | --- |
| 0x40 | `0x4d4f4445`（MODE 标识） |
| 0x44 | 模式代数 generation，每次实际切换加一，KEY0 复位归零 |
| 0x48 | [1:0] 当前模式，bit 2 切换请求待执行或复位中 |
| 0x4c | `1`，支持 KEY1 动态模式 |

以上均为只读状态，当前通过 KEY1 操作。ARM 应在完整帧接收前后读取 generation，
若变化则丢弃跨模式的半帧，等待 `frame_ready=1` 后重新接收；
同时刷新 GROUP / VIEW、游标及完成计数基线。建议切换时先停止提交 DMA，等待切换完成再接收。

它需要配套的 ARM `tools/board_demo`，不能直接沿用旧版的 line 模式显示步骤。
本次交付文件未包含该 ARM 测试包，仍需取得匹配的接收、比较和显示程序。

板级入口使用 R4/T4 的 125 MHz 差分时钟，内部生成 25 MHz；不使用旧测试工程的 V4 时钟。
时钟、DDR 约束、SCBV 设置及 IP 保持交付版本。未执行统一版的下载或板级测试。

原始交付说明保存在 [交付说明](../../docs/imports/2026-10-18/FPGA工程交付与使用说明.md)。
仓库内位置与原压缩包不同，本文的工程链接为当前入口。统一改动见
[统一工程记录](../../docs/changes/008-unified-video-project.md)。历史导入记录见
[合入记录](../../docs/changes/007-import-distortion-video.md)，导入时的文件来源和改动哈希见 `import_manifest.json`；
清理记录见 [工程清理](../../docs/changes/009-clean-project-files.md)。
