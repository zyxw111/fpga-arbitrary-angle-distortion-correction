# Warp 性能板测手册（Phase 0）

适用：`FPGA_AADCS/HDMI_Warp`，CAM3 + PRF0 v1；ARM仓库 `RK3568-PCIE`。此手册不修改算法或现有参数。

## 1. 先区分版本与测试端点

1. 记录两仓库分支、HEAD、工作区diff、所有参与构建的源码hash、位流SHA256、匹配的rtr/prr、标定文件hash和应用代次。
2. 保留当前已验证位流。`firmware/fpga/hdmi-warp`中的旧CAM2不能当作当前CAM3位流。
3. 保持相同HDMI有源尺寸/帧率、标定参数和ARM运行命令；先测无GUI接收，再测GUI显示。接收fps、源fps、绘制fps分别记录。
4. 本阶段仍用当前1080p30输入，不能把它当作60fps信号源。不要为测数改EDID或算法。

## 2. 构建 / A/B

在 `F:/AADCS_git_zyxw`：

```powershell
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/perf-phase0-v2
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/perf-off -PerfDisable
```

两个目录隔离。`-PerfDisable`只在构建目录生成一份顶层参数PERF_ENABLE=0的源码，原图像数据通路相同；不修改主工程源文件。依次运行构建，禁止构建中修改源文件。默认 `PERF_SNAPSHOT_BITS=20`，无需为采样提高更新频率。

本轮使用修正DMA观测接线的v2；旧 `build/perf-phase0` 的v1不能用于读取DMA忙周期/完成页计数。通过时序和观测信号绑定检查后，下载命令为：

```powershell
./FPGA_AADCS/HDMI_Warp/program.ps1 -BuildDir build/perf-phase0-v2
```

`program.ps1`不指定目录时仍选择保留的诊断前 `build/` 基准位流。先核对SHA256，不要把两个目录混用。

核对rtr全部约束通过，全设计最差setup WNS相比基线恶化≤0.2ns，并列出关键clock对余量及LUT/FF/DRM/APM变化。不要使用“独立always”代替实际时序验收。不满足时不上板替换已验证版本。

构建脚本同时拒绝观测模块`page_completed`位宽不匹配及`perf_enabled.*`无驱动警告。观测父信号必须在generate作用域使用前声明，避免PDS生成同名局部隐式线并绑0。计数值为0要与已知流量交叉验证，不能只看仿真单元通过。

仿真（在FPGA仓库）：

```powershell
& 'C:/Users/hp/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe' -X utf8 FPGA_AADCS/HDMI_Warp/sim/regress.py --tests warp_perf warp_tiles hdmi_live_pcie hdmi_live_perf_off
```

## 3. ARM只读采样

先使用原有fpga-view/fpga-probe正常启动链路和BAR恢复。PRF0工具自身不写PCI配置、不修复BAR、不控制DMA，因此必须在已配置成功的端点上使用。

```sh
python3 tools/warp_perf.py --samples 60 --interval 1 > /tmp/warp-perf.jsonl
```

每条JSONL包括：

- `warped_fps` / `consumed_fps`：处理发布 / 输出槽消费速率；不是GUI绘制fps。
- `last_warp_ms` / `last_dma_ms`：最近一次局部硬件阶段周期；不是两段严格串行的总延迟。
- `host_hz_from_counter_ratio`：通过host/DDR周期差分推算PCIe用户时钟；当前Gen1链路约62.5MHz，不能把125MHz时序约束直接用于DMA时间换算。
- `MB_per_s`：各流按返回/接收beat差分×16；十进制MB。源流包含tile重复，LUT只读量与建表写量分开。
- `average_burst_beats`：实际已握手AR声明beat数 / AR笔数；硬件最大16，不得将128-beat逻辑任务计作一笔原生突发。
- `max_outstanding`：reset以来峰值，warp / host / shared三类；不能证明整个采样区间始终达到该峰值。
- `stall_fraction`：AR等待、在途无返回、输出槽等待；计数可能同时发生，不要将比例相加当作CPU式分解。
- `error_flags` / `discarded_captures` / `delta`：现有及新增观测异常、异常采集丢弃、原始差分。

工具先后读snapshot_sequence，只接受相同代次。读不到PRF0时明确报错；不尝试写入旧位流。32-bit累计值按模回绕处理，采样≤10秒，建议1秒；reset / reprogram后重启采样进程，避免把复位当回绕。

## 4. 如何判断假设

| 检查 | 支持的判断 | 不可据此断言 |
|---|---|---|
| host outstanding=1，host返回等待较高，DMA约21ms | 输出读取串行是可优化部分 | 21ms全是多余copy |
| warp峰值接近16、map/source流稳定 | 并发逻辑生效 | 实际持续≥8，或带宽已经达到峰值 |
| map bytes / warped frame ≈16,588,800 | 1080p稳态每帧读取全二维表 | XY表经过PCIe传给ARM |
| map平均突发≈16 | 当前原生读基本满长度 | 平均128/256beat已达标 |
| source bytes / warped frame明显高于4,147,200 | tile源足迹重叠 / 对齐引起读放大 | 四抽头没有片上缓存 |
| output_slot_wait高，ARM slot等待或copy/GUI高 | 消费端阻塞反馈到处理 | 增加缓冲就能解决平均吞吐不足 |
| 无GUI稳定，带GUI下降 | ARM拷贝/转换/显示需独立优化 | FPGAwarp已经达到60fps |
| LUT写beats只在启动/参数变化增加 | 预生成表复用正常 | 建表时间等于稳态每帧时间 |

有在途无返回包含仲裁、控制器和消费者调度影响，不是直接测得DRAM器件200ns延迟。表相关全部stall还包括包围盒与bank切换；当前只统计warp整体等待，不伪装成已分离的全部表stall。

## 5. 10k帧与画质验收（后续WP使用）

1. 建表完成、参数代次已发布后开始稳态区间；记录源帧号、输出帧号、generation、checksum/footer、PRF0差分及ARM渲染日志。
2. 每秒采样累加到软件64-bit总计，至少10000帧；分别核对源→采集、采集→处理、处理→DMA、DMA→显示的计数，解释区间边界上的在途帧。
3. `discarded_captures=0`和`error_flags=0`不足以证明无跳帧：无空槽时跳过的源帧需用源帧号及既有skipped统计交叉检查。FIFO异常沿用现有接收错误；不得把重复显示旧帧当新帧。
4. 在相同输入帧、相同参数/取整/边界语义下导出A/B RGB565，逐通道对比；纯调度改动要求bit-exact。PSNR与最大误差的LSB单位需先确认，不对打包的16-bit RGB565整数直接求颜色误差。
5. 原始双线性和固定点逻辑保持；未来任何近似另开参数，单独报告其画质。包括tile边界、高曲率、越界黑边、非零p1/p2、旋转和动态参数切换。

## 6. 扫描建议（本阶段只建议，不改数据通路）

- 先以当前native16beat、shared16 outstanding、32×8tile为基线，测稳定映射与强畸变映射的source读放大。
- 后续允许参数化时，读并发扫描1/2/4/8/16；每点保持同样位流构建seed、参数、源及CPU策略，并检查资源/时序。
- 长预取长度按逻辑64/128/256beat比较，原生仍分割≤16beat；报告两种长度。
- tile大小及源缓存深度改变前先估算DRM，四bank总262144B已占一定资源，不直接套128×128大tile。
- `PERF_ENABLE=0/1`用于观测开销A/B；`PERF_SNAPSHOT_BITS`建议20固定，不以提高更新频率换取更多诊断数据。

未获得Phase 0后的确认，不实施WP数据通路重构、表压缩或60Hz输入模式调整。

## 7. 远程USB恢复

Windows能枚举FTDI不代表PDS一定能打开。若PDS返回`CableList is empty`，可从USB远程助手所配置的VirtualHere客户端读取`LIST`，再只对该列表中的FTDI地址执行`STOP USING`和`USE`；该流程无需停止SSH/VPN或其他USB设备。命令与返回值见[VirtualHere官方客户端API](https://www.virtualhere.com/client_api)。

助手可能在释放后自动重新接入，此时`USE`返回Already in use，应以`LIST`中的In-use by you及PDS重新扫描结果核对，不重复断开。下载进行中保持连接。记录DONE与CRC检查；若下载到100%/DONE=1后仅状态读失败，应先检查ARM端实际固件与数据，避免把状态读取失败直接等同于配置失败。

## 8. 已确认的WP1：计算与写回重叠

Phase0后已获得继续实施WP1的确认。当前实现与验收见 `warp_perf_wp1.md`，证据在 `FPGA_AADCS/HDMI_Warp/checks/2026-10-27-wp1`。本包不修改源坐标、插值、帧协议或ARM显示路径。

```powershell
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/wp1-overlap
./FPGA_AADCS/HDMI_Warp/program.ps1 -BuildDir build/wp1-overlap
# A/B回退，使用相同数学和接口：
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/wp1-serial -WarpSerial
```

新读取工具自动识别BAR0 `0x2B0` 的TIL1，只读尾部包含计算、写回、同时活跃、输出槽满、源tile等待及帧计数。原PRF0字段和地址保持兼容。`tile_pipeline.write_overlap_fraction`只描述tile写回与计算的重叠；整帧DMA此前已经与warp重叠，不能把约21ms DMA直接从端到端时间中减掉。

板测使用已发布的原标定代次，输入1920×1080/30Hz，先启动现有headless捕获，再每秒采样，连续累加至少10000个`delta.warped_frames`和`delta.consumed_frames`。同时记录capture日志的source/skipped，要求稳态skipped不增加、错误及discard为0。启动前无人消费造成的历史skipped绝对值不作为测试期丢帧。关闭headless后再启动GUI，不能让两个进程同时争用DMA。

若输出scratch满等待远高于源tile等待，下一包应验证短行写突发与DDR仲裁占用，不应仅凭先验假设增加source缓存。平均AR突发仍受硬件16-beat上限限制；TIL1没有伪造256-beat能力。
