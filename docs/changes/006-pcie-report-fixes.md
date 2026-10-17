# 2026-10-17：根据 RK3568 实测报告修复 FPGA PCIe 工程

对应输入：`005-rk3568-host-verification.md`，旧版 `50725bd`。
主机报告证明旧版存在非法恒定载荷和未覆盖缓冲区；它未读取 FPGA 内部信号，
报告中的原因推断不能直接当作已确认根因。本次保持 BAR1 描述符格式、彩条帧头、RGB565 字节序不变。

## 已复现并修复的错误

整链路测试经过实际 `ips2l_pcie_dma` 的 RX、控制器、读 FIFO、MWr 发送器，
不再跳过 BAR1 解析和描述符控制器。主机内存预填 `0xAAAAAAAA`，逐字检查地址、数据、遗漏和重复。

旧控制器的 4 KiB 检查读取 `o_req_length`，它比当前命令寄存器晚更新一拍。
连续发三行 1280 字节后，下一行在页尾先发 256 字节的合法分段；检查器仍使用上一行的
1280 字节长度，错误报告越界并清空命令标志。修复前测试在第 4 条描述符失败：

```
descriptor 4 got 960 expected 1024 cross=1
```

现在直接从当前命令计算字节数，再检查边界。该错误可以造成传输段丢失，
但未证明它单独解释主机报告的 75.5% 空洞，更不能据此解释非法恒定载荷。

RX 路径也改为仅在有效载荷拍产生写脉冲，BAR1 只接受单 dword 且 lane0 有效的 MWr。
避免 `bar_hit` 或旧 payload 在包间空闲时被当作新的寄存器写入；保留完整 32-bit 字节使能检查。

## 复位与数据源

- 使用板载 25 MHz 时钟（V4，LVCMOS15）生成配置完成后的约 10.49 ms 复位。
  计数器和复位控制寄存器有显式配置初值，KEY0 会重启计时，不依赖 PCIe 时钟先启动。
- PCIe core reset 与上电复位共同控制 DMA 时钟域的异步断言、同步释放。
- KEY1 经同步及约 2.1 ms 消抖后改变模式，DMA 与数据源同时复位一拍。
  去掉组合比较器产生的异步源复位。切换前仍须停止主机采集。
- 彩条使用八路独立组合像素连线，再一次性寄存完整 128-bit 数据；游标越界可以恢复。
  两种模式的字节格式与帧首状态头不变。
- 未知主机 PERST# 实际布线，未把任何按键误当成 PERST#；该 IP 输入目前仍常高。
  自主复位不保证 RK3568 在任意时间重新枚举，JTAG 重配置仍需主机配合。

## 本地验证

`scripts/test_fpga_pcie.ps1` 五组测试通过：

- 完整彩条帧、帧循环、同步读停顿、字节交换及递增数据。
- 32/64-bit 地址、4096 字节编码、真越界拒绝、部分字节使能拒绝。
- 实际 MWr 读 FIFO 和发送器，长时间及短周期 TX 背压。
- 无外部上电复位脉冲、PCIe 时钟最初停止、KEY0、KEY1 抖动和模式/core reset 重启。
- 完整 DMA 主机模型：4096 个递增 dword；两帧 640×400 彩条，64-bit 目标地址、
  1000 条描述符、8000 个 TLP，所有 256000 个 dword 数据和地址正确，无空洞或重复。
  包头与载荷间插入空拍，发送端同时施加背压。

只有未使用的 BAR RAM 采用行为模型；测试不包含模拟 PHY、PCIe 链路协议、内核驱动或真实主机缓存。

`scripts/test_fpga_gate.ps1` 调用 ADS 生成独立网表，使用厂家 GTP 仿真库，验证数据源的完整两帧
以及复位/初始化控制，均通过。为缩短复位门级仿真，夹具的计数位数为 4/3；生产设计仍为 18/18。
门级夹具不等价于完整 PCIe 硬核门级验证。

普通版和双 DebugCore 版均完成 PDS 编译、综合、映射、布局布线、时序检查和位流生成，
时序报告为 `All Constraints Met`。位流、输入指纹及具体裕量见固件目录的 `build-info.json`。

## 双 DebugCore 与 Tcl

构建：`scripts/build_fpga_pcie.ps1 -DebugCore`，输出在 `FPGA_AADCS/build/debug/`。
`project/debug_config.tcl` 生成 FIC，PDS 用 `add_fic` 插入两个深度 1024 的核：

| 核 | 时钟 | 数据通道 |
| --- | --- | --- |
| 0 | PCIe `pclk_div2` | 0–15 flags，16–143 source_data，144–175 read_count |
| 1 | 独立 `free_clk` | 0–5 同步状态，6–37 heartbeat |

flags[15:13] 为最大载荷配置，[12] core reset_n，[11] DMA reset_n，[10] power-up reset_n，
[9] ramp_mode，[8] source_read，[7:6] smlh/rdlh link-up，[5:4] RX valid/ready，
[3:2] TX valid/ready，[1] TX last，[0] 越界状态。

独立核 status[5:0] 为 KEY1_n、KEY0_n、power_up_rst_n、core_rst_n、smlh_link_up、rdlh_link_up。
Debugger 的 `dbg_add_bus` 通道列表按低位到高位解释，脚本使用升序通道，避免总线值被反转。

可复用脚本：

- `scripts/pcie_jtag_status.tcl`：只读器件 ID 和配置状态。
- `scripts/program_fpga_pcie.tcl`：SRAM 下载，显式 `-program 1` 启用 WakeDownReconfigure；不烧写 Flash/eFuse。
- `scripts/debug_fpga_pcie.tcl`：连接、导入 FIC、立即采样、等待 `source_read` 条件触发。
  采样用 `dbg_save_project` 保存 `.dprj` 和 `.wdf`，可离线重新打开。

脚本中的 JTAG Server 为本机 `127.0.0.1:65420`。新机器需先启动 `cdt_js.exe -port 65420`，
并按实际 PDS 目录调用 `cdt_cfg_shell.exe -file 脚本绝对路径`。
调试脚本在 Fabric Debugger 的 Tcl Console 用 `source 脚本绝对路径` 执行；许可证到期提醒
会阻挡 GUI 工具启动，关闭该提示后执行脚本。它不是 RTL 编译错误。

## 实际板卡验证进展

用户提供远程 USB 并在下载异常后按了复位。已经通过 Tcl 读取 PG2L100H，ID `0x00602899`。
默认下载曾报 DONE 未拉高，ISC-only 尝试未完成并已停止；复位后显式使用
`cfg_set_device_property -device_index 0 -program 1`、1 MHz JTAG，调试位流成功配置：

```
The done bit is 1
COMMAND[Program] execute successfully, takes 30.1 secs.
```

已成功发现并采样两个 DebugCore。独立核 status=`0x3F`，heartbeat 在递增；
DMA 核空闲状态 flags=`0x1CD4`，source_data=0、read_count=0：复位已释放、彩条模式、
链路两侧 link-up，尚无数据源读请求。空闲时全零符合数据源在第一次请求前保持复位输出的行为。

修复版在真实 ARM 描述符下的载荷和主机缓冲覆盖率仍需复验，不能将空闲采样或 RTL 通过写成
实际 DMA 数据正确的结论。

用户随后在 ARM 运行了接收程序。20:35:18 的再次立即采样仍为 flags=`0x1CD4`、
source_data=0、read_count=0，未观察到源读请求。条件触发等待期间曾报 JTAG/core 状态读取超时，
但随后立即采样成功，不能仅凭该超时判定 FPGA 时钟或调试核异常。
后续需要 ARM 的完整启动命令和输出，检查重配置后的枚举、BAR 配置和描述符输入。
当前没有连接 ARM 执行命令，也没有完成真实 DMA 载荷复验。

## 文档更正

保留原始主机报告作为测量记录，其中“彩条只在 y 方向分段、与 x 无关”是文字笔误：
实际彩条沿 x 每 80 像素变色，下方渐变区由 y 选择。
旧报告中 F_RESET 有效、KEY0 未恢复链路是实测事实；它不能证明 JTAG 配置后 PCIe 硬核必然不初始化。
本次成功下载的参数和采样结论如上，主机重枚举与 PERST# 仍需结合真实硬件验证。
