# WP1：tile 计算与 DDR 写回重叠

状态：实现、全尺寸画质、时序和1080p30连续11000帧板测已验证。原标定下1080p warp周期已降到≤32ms，并保持逐像素一致。此包不宣称完成60fps总目标。

## 基线

- FPGA：`zyxw-gpt`，基线提交 `9639205be7388d267c2ebda58f4eb04606baf901`，Phase0 v2位流 SHA256 `8ee33e2e70e8dec01ad8d78e88cc866c88ce564628b2d4745f011d8dd54fac76`。
- ARM：`main`，基线提交 `f785445`；本包仅扩展只读性能工具及其测试，不修改捕获、校验、显示或内核驱动。
- 原标定 SHA256 `982882c4f23bd89c6b2642d6ad95f56b4baeb094592d7c9c7d685962b241779f`；输入/视频输出1920×1080，输入30Hz，参数17字不变。

## 行为与所有权

旧路径在每个32×8 tile计算完成后，串行写8个64B行，写完才释放源缓存。

新路径将计算和写回拆为独立控制器：计算端预留一个输出槽，完成最后一个插值像素后发布该槽，并释放对应源缓存；写回端按发布顺序发送同样的4-beat行突发。只有接受该槽最后一个写beat后，才允许重用输出槽。输出地址在计算阶段登记，写回时逐行加原stride。

整帧`done`仍等待**最后一个tile的最后一个DDR写beat**；此时最后一个校验和项也已经完成。帧槽释放、generation、footer和DMA可见性保持原含义。源坐标、四邻居mask、定点位宽、取整、插值和raster校验和算法未改变。

## 参数与回退

新参数集中在顶层参数区，并向`hdmi_live`和`warp_tiles`传递。

| 参数 | 默认 | 含义 |
|---|---:|---|
| `WARP_OVERLAP_WRITE` | 1 | 1=计算/写回重叠；0=保留的原串行控制器 |
| `WARP_OUTPUT_BANKS` | 2 | 每槽512B；支持1–8槽，默认双缓冲；串行路径实际仅1槽 |
| `PERF_ENABLE` | 1 | 可关闭所有未被数据通路使用的诊断逻辑 |

```powershell
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/wp1-overlap
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/wp1-serial -WarpSerial
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/wp1-three -OutputBanks 3
```

保留的Phase0 v2位流也可直接用于硬件回退；不要将原`build/`旧位流与新构建目录混用。此次没有推送或合并远程分支。

## TIL1 只读观测

PRF0版本与原40个word地址不变，另在BAR0 `0x2B0–0x2CF`增加TIL1尾部，使用同一个握手快照及sequence保证读取一致。旧读取工具仍能读取原区域；新`tools/warp_perf.py`自动识别尾部，也兼容Phase0旧位流。

| 地址 | 字段 |
|---|---|
| 0x2B0 | magic `0x54494C31` |
| 0x2B4 | bit0=重叠开关；bits15:8=实际输出槽数 |
| 0x2B8 | 累计计算周期（R_SCAN/R_DRAIN） |
| 0x2BC | 累计写回周期（AW等待与数据发送） |
| 0x2C0 | 计算与写回同时活跃的周期 |
| 0x2C4 | 输入tile已就绪、输出槽满的等待周期 |
| 0x2C8 | 等待源tile就绪的周期 |
| 0x2CC | 写回完成帧数 |

均为32-bit模回绕累计值。写回重叠率=`Δ0x2C0/Δ0x2BC`；它不等于原WP1中整帧生成与PCIe DMA重叠率。长写背压时，输出槽满会阻止计算，重叠率下降是预期流控行为。

## 验证

| 测试 | 结果 |
|---|---|
| 64×40连续两帧、第二帧修改源图、输出内存预填poison | 开关两路径均精确匹配、raster checksum一致 |
| 周期性1500-cycle写背压 | 双槽/三槽均通过，输出满等待实际发生，无提前done |
| 非2幂输出槽数3 | 指针回绕、两帧复用通过 |
| 真实PCIe RX/控制/TX模型 | 两路径均通过29,696像素，含64×40→96×44尾部tile、参数原子切换和随机停顿 |
| 全1920×1080原标定A/B | 两路径各2,073,600像素全部匹配；最大误差0，PSNR=∞；checksum均`4de73ca9` |
| PRF0/TIL1快照 | 原寄存器、DMA计数、尾部两bank均通过 |
| ARM只读解码 | 5项测试通过，含旧位流兼容与重叠率计算 |

全尺寸测试用相同RGB565原图与相同Q20.12二维表预载到接口模型，保留原标定逐级取整。结果证明调度与写回未改变像素；该模型不是DDR PHY带宽/时序证明。生成数据留在`build/full-wp1`，不将约50MB测试输入提交Git。复现：

```powershell
python FPGA_AADCS/HDMI_Warp/sim/full_frame.py
python FPGA_AADCS/HDMI_Warp/sim/regress.py --tests warp_perf warp_tiles warp_tiles_serial warp_tiles_stall warp_tiles_three_banks hdmi_live_pcie hdmi_live_serial
```

## 前后对比

| 项目 | Phase0串行基线 | WP1重叠 |
|---|---:|---:|
| 全尺寸接口模型周期 | 2,715,781 | 2,656,833（−2.17%） |
| 小尺寸高读延迟模型周期 | 3925 | 3853（−1.83%） |
| 全设计slow setup WNS | +0.358ns | +0.397ns |
| DDR同域WNS | +0.358ns | +0.450ns |
| PCIe125同域WNS | +0.664ns | +0.807ns |
| HDMI同域WNS | +0.622ns | +0.397ns |
| LUT / FF | 15,413 /18,570 | 15,745 /19,440（+332 /+870） |
| DRM / APM | 80.5 /30 | 80.5 /30 |
| 同轮12秒板测warp周期中位数 | 34.512ms | 31.210ms（−9.57%） |
| warp最近值采样范围 | 31.560–34.624ms | 31.181–31.228ms |
| 处理新帧率 | 28.943fps | 30.044fps（有限窗口含边界一帧） |
| DMA阶段中位数 | 20.778ms | 21.570ms |
| map / source读有效带宽 | 481.171 /176.160MB/s | 497.694 /182.208MB/s |
| host读 / output写有效带宽 | 120.273 /120.293MB/s | 124.318 /124.424MB/s |
| capture写 / LUT写有效带宽 | 120.629 /0MB/s | 124.422 /0MB/s |
| 平均原生AR beat：map/source/host | 16 /3.78455 /15.35938 | 16 /3.78456 /15.36026 |
| 峰值outstanding：warp/host/shared | 16 /1 /16 | 16 /1 /16 |
| 输出帧槽等待 | 0 | 0 |
| tile写回与计算重叠率 | 串行，0 | 51.279% |
| 输出scratch满 / 源tile等待占周期 | 旧版无此细分 | 37.739% /6.999% |
| 同轮capture日志skipped增量 | 29秒内+28 | 1800帧测试内+0 |
| 性能error / 异常采集discard | 0 /0 | 0 /0 |

时序以全设计最差setup WNS比较满足不恶化超过0.2ns；各域余量单独列出，所有约束通过。新增FF主要来自TIL1计数和一致性快照；默认输出scratch仅由512B增至1024B。

位流SHA256：`95704b6bd7b704e556078e1eea643e35086e15dcf2de6b74f3a9173c49eacf2f`。本轮使用JTAG重新下载后，ARM既有程序检测到BAR丢失并完成原位修复；after日志启动时的两条BAR错误是此恢复过程，后续DMA和校验正常。10k测试在恢复完成后独立启动。

≤32ms阶段目标已达到。DMA仍是必要的输出搬运，并未消失；此前它已经与生成流水重叠，本包改变的是tile计算与写回的重叠。实际板测改善约9.6%，接口模型改善2.17%，两者不能互相替代。

新增计数器把当前主要等待定位到输出scratch满（约38%），明显高于源tile等待（约7%）。输出仍为每行4-beat短突发，因此下一包优先验证写回合并/仲裁效率，再评估源预取。仅增加source并发不能据此保证≤17ms；当前60fps和60fps下10k无丢帧均未完成。

## 10k帧连续板测

输入1920×1080/30Hz；ARM headless接收11000帧，日志平均30.0fps。性能计数器独立稳态窗口340.490秒、340个快照间隔，采集/处理/消费/DMA完成分别为10215, 10215, 10215, 10215帧，区间边界保留在途帧。

处理/消费速率30.000916fps，warp周期31.162–31.242ms，中位数31.205ms；DMA最近值21.421–22.214ms。skipped始终17863（启动前历史计数），稳态增量0；error_flags=0、discarded_captures=0、捕获日志无告警/错误、stderr为空。现有错误位未报告FIFO异常；该结论限本次30Hz输入和原标定，不外推到60Hz。

读回accepted/applied/published均为1，17个影子参数逐字匹配原标定，TIL1配置0x201。完整原始计数及日志见checks/2026-10-27-wp1/board_10k.*与board_summary.json。10k窗口各流有效带宽：map/source/host读497.662/182.181/124.414MB/s，capture/output写124.416/124.416MB/s；map/source/host平均原生突发16/3.78452/15.36001beat，峰值在途16/1/16。

## 恢复显示与下载器

11000帧无界面测试完成后已恢复既有CAM3 GUI（1280×720 fit/fast显示窗口）；连续日志约29–31fps，copy约36–51ms，GUI受CPU调度影响存在波动。GUI恢复检查与无界面10k无跳帧验收分开，不把后者外推成GUI长期保证。

本次重新接入远程FTDI后，等待JTAG Server实际监听再下载成功；只读复查识别PG2L100H，DONE=1、init_complete=1、CRC错误位=0。program.ps1已将固定2秒等待改为最长30秒等待实际监听，未改变位流格式。
