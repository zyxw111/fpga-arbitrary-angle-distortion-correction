# AADCS

## 当前视频工程

2026-10-18 交付版位于 [FPGA_AADCS/Distortion_video](FPGA_AADCS/Distortion_video/README.md)，
包含内部图像、校正算法、DDR3 及 PCIe 数据通路。
三个板级入口为 `checks/board_bars/board_bars.pds`、`checks/board_raw/board_raw.pds`、
`checks/board_corrected/board_corrected.pds`，路径相对于该目录。
交付位流在 `firmware/fpga/distortion-video/`；配套 ARM `tools/board_demo` 未包含在本次交付中。

## 项目组成
- FPGA_AADCS：PDS FPGA 工程
- rk3568_AADCS：RK3568 软件工程
- firmware：配套烧录文件及部署包
- docs：项目文档
- scripts：构建、打包和检查脚本

## 开发环境
- FPGA 型号：PG2L100H-6IFBG484
- PDS 版本：2022.2-SP6.4
- RK3568 板卡型号：RK3568_MES2L100H（用户已确认 100H）
- 系统及 SDK 版本：待填写
- ARM 编译工具链：待填写

## 两端通信
- 接口方式：PCIe（第一阶段 Gen1 x2）
- 协议版本：测试数据接口 v0.1，见 docs/pcie-test-protocol.md

## 构建与部署
FPGA 使用 FPGA_AADCS/FPGA_AADCS.pds，或在仓库根目录执行
scripts/build_fpga_pcie.ps1；仿真执行 scripts/test_fpga_pcie.ps1。
详细说明见 FPGA_AADCS/README.md。RK3568 应用环境和联合部署仍待确认。

## 当前验证状态
已实现 FPGA 内部彩条/递增数据的 PCIe DMA 测试工程。
主机侧实测报告见 docs/changes/005-rk3568-host-verification.md，旧位流存在恒定载荷和传输遗漏。
本次修复、完整 DMA 回归及 DebugCore 使用见 docs/changes/006-pcie-report-fixes.md。
上述旧 PCIe 测试版的主机端复验尚未完成。
新交付的视频工程已包含校正 RTL，本次合入和验证范围见 `docs/changes/007-import-distortion-video.md`。
