# 004：修复 PDS GUI 工程解析

日期：2026-10-14；分支：zyxw。

## 问题与修复

`FPGA_AADCS.pds` 的手写源码条目缺少 `_timespec`，IP 错写为 `_file`/`idf`
格式；PDS 在读取源码列表时报告 Flow-0130/Flow-0121，GUI 无法打开。
此前验证的是 Tcl 批处理构建，未覆盖 GUI 工程入口。

以 PDS 自己生成的 setup 结构替换手写条目，保留相对路径、正确的 `_ip` 和
`_ip_source_item` 元数据，显式设置顶层 `aadcs_pcie_top` 及 ADS 综合选项。
删除验证过程写回的临时编译产物引用，GUI 构建目录仍为 `build`。

新增 `scripts/check_fpga_project.ps1`，复制 GUI 工程到忽略目录并锚定输入路径，
使用 PDS 的 `-project ... -run compile` 验证，避免检查过程污染正式入口。
`build_fpga_pcie.ps1` 在 Tcl 全流程构建前先运行这个检查。

## 验证

- PDS 2022.2-SP6.4 直接加载正式 GUI `.pds` 并 compile 成功，退出码 0。
- 清除临时输出引用后的工程再次通过独立 GUI 工程检查，退出码 0。
- 硬件 RTL、IP、约束与 Tcl 构建输入未改变，没有重建或更换位流。
- 修正构建元数据的输入指纹范围：记录实际使用的 Tcl/RTL 输入，GUI 描述文件不是
  先前批处理位流的输入；原位流 SHA-256 保持有效。

许可证到期提醒与上述工程语法错误无关。
