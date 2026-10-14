# AADCS

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
本地仿真与 PDS 构建结果见 docs/changes/003-fpga-pcie-test.md。
尚未执行上板及 FPGA/RK3568 联合验证，畸变矫正尚未实现。
