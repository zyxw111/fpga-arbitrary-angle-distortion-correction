# 2026-10-18：合入 Distortion 视频工程

将用户提供的 `E:/Downloads/Distortion/Distortion/prj/Distortion_video` 合入本地 `zyxw`，
基线提交为 `d706fb6`。原始交付说明保存在 `docs/imports/2026-10-18/`。

## 工程位置与使用

有效源码、IP、仿真、约束和板级入口位于 `FPGA_AADCS/Distortion_video/`。
三个板级工程分别为：

- `checks/board_bars/board_bars.pds`：彩条。
- `checks/board_raw/board_raw.pds`：畸变原图。
- `checks/board_corrected/board_corrected.pds`：校正图。

`Distortion_re.pds` 是顶层为 `vtop` 的诊断工程。导入后的 README 和仓库首页均已注明板级入口。
视频工程独立于旧 `FPGA_AADCS.pds`，防止两套同名 DMA/IP 模块混入一次编译。
接口采用交付版 BAR0 状态和 BAR1 描述符协议，需要配套 ARM `tools/board_demo`；该接收包未在
本次提供的目录中，不能把旧 `fpga-probe --mode line` 的操作说明当作本版验证步骤。

三份交付位流及原始时序、资源和位流生成报告位于 `firmware/fpga/distortion-video/`。
位流逐字节保留，未在此次合入中重新生成。原始构建的 296 项源文件哈希在三份清单中均匹配
交付目录当前文件；清单作为发送方构建证据保留。

## 合入适配

- 仅导入有效的 `Distortion_video`，外层早期 RTL、`Distortion_re` 原工程和历史备份没有覆盖新工程。
- 保留 `source`、所需 IP 文件、`sim`、开发文档和独立检查工程；排除大量编译缓存和日志。
- PDS 源码、IP 和约束使用本目录的相对路径，清除历史构建结果及完成状态。
  已被 PDS 明确引用的四份 PCF 约束从构建目录移到工程目录并继续作为输入保留。
- 构建脚本新增 `-PdsRoot`，默认本机 `F:/PDS_2022.2-SP6.4`；检查辅助脚本从自身位置解析工程根目录。
- `still.v` 的 `bridge_ready` 原先在 `fetch` 端口表达式使用之后才声明。本机 Icarus 13 拒绝解析，
  现在仅将该 `wire` 声明前移；未改变逻辑、时序参数或信号连接。
- `source/pcie_dma/ips2l_pcie_dma.v` 的视频接口赋值和状态采样块也移到内部信号声明之后，
  修复同一严格解析限制；未改变组合表达式或寄存器行为。
- DDR/PCIe IP、引脚、电平、板级时钟和 SCBV 按交付版保留。厂商模板中的历史 RAM 初始化路径
  也未用任意数据替换；若工具报告缺失，需核对具体 IP 的初始化配置。
- `import_manifest.json` 记录导入文件的原始哈希、导入哈希及适配项。

新视频入口使用交付版 R4/T4 125 MHz 差分时钟，旧测试工程的 V4 方案仍在旧入口中。
原始开发文档保留了历史阶段记录，最终板级入口及验收文档才对应本次三份位流。

## 本机验证

三份迁移后的 `.pds` 已在隔离验证目录通过 PDS 2022.2-SP6.4 的解析及 RTL 编译。
所有导入工程的源码、IP 及约束文件引用均可解析。

RTL 回归使用仓库原有 Icarus 13 缓存及交付包 `sim/regress.py` 执行。
结果与输入指纹保存在 `docs/verification/2026-10-18-distortion/`。
回归包含校正、图像打包、跨时钟、DDR 模型、三种内部图像和实际 DMA RX/控制器/TX 的测试。

交付包已有的三份布局布线时序报告均包含 `All Constraints Met`，这属于原始构建证据；
本次迁移验证没有将 PDS 编译通过描述为重新完成布局布线。没有执行本版下载、真实 DDR/PCIe
抓帧、ARM 测试或电气测量。

## 本地分支与工作目录

`F:/AADCS_git` 当时停在旧 `main`，并有用户未提交的 PDS 修改。
本次在同一 Git 仓库的 `F:/AADCS_git_zyxw` 工作目录检出本地 `zyxw` 并提交，保留原目录工作状态。
本地提交属于同一个 `zyxw` 分支，远程推送不在本次操作范围内。
