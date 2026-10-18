# Distortion 位流

当前统一版为 [unified/boardtop.sbit](unified/boardtop.sbit)，同一个位流内 KEY1 循环选择
彩条、畸变原图和校正结果。2026-10-18 在本机 PDS 2022.2-SP6.4 完成编译、综合、布局布线、
时序检查和位流生成，`All Constraints Met`，46 项 RTL 测试通过。未下载上板或进行 ARM 联调。
`unified/` 同时保存本次 `.rtr`、`.prr`、`.bgr` 和 `build-inputs.json` 输入指纹。

## 原始交付存档

2026-10-18 从用户提供的 `Distortion/prj/Distortion_video` 导入，目标 PG2L100H-6IFBG484。

| 子目录 | 图像 | 位流 |
| --- | --- | --- |
| `board_bars` | 内部彩条 | `board_bars.sbit` |
| `board_raw` | 内部畸变原图 | `board_raw.sbit` |
| `board_corrected` | RTL 校正结果 | `board_corrected.sbit` |

每个目录同时保存交付包的 `.rtr`、`.prr`、`.bgr` 及原始 `final_source_hashes.json`，
作为原有构建的证据。这些位流为交付文件原件，本次合入未重新生成，也未下载上板。

原始构建清单内的工程路径与生成结果属于发送方环境。合入时仅调整了 `still.v` 和
`source/pcie_dma/ips2l_pcie_dma.v` 中声明与使用的顺序，以兼容本机 Icarus 13，RTL 逻辑不变；
其余源码/IP 保持原字节。
PDS 工程已清除构建状态并适配本地相对路径。来源及 SHA-256 见
`../../../FPGA_AADCS/Distortion_video/import_manifest.json`。

使用新的工程入口和配套 ARM `tools/board_demo`，详见
[工程说明](../../../FPGA_AADCS/Distortion_video/README.md)。

当前源码已统一为 `FPGA_AADCS/Distortion_video/board_video.pds`。上述三份位流是原始交付存档，
不包含后加的 KEY1 动态模式；统一版请从新工程构建 `build/generate_bitstream/boardtop.sbit`。
