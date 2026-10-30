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

## 9. 1080p60 采集诊断扩展

后续已获得1080p60优化授权，当前测试和回退开关见 `warp_perf_1080p60.md`。上文Phase 0的30Hz限制仅描述当时阶段。

新候选在BAR0 `0x2D0..0x2FF`增加RXD1只读快照，与PRF0使用同一host快照代次。旧字段和写入地址均不变；旧位流没有该magic时，ARM工具跳过此扩展。`PERF_ENABLE=0`移除该监测。

| 地址 | 字段 | 含义 |
|---|---|---|
| 0x2D0 | capture_magic | 0x52584431 (RXD1) |
| 0x2D4 | input_frame_ends | 像素域观察到的输入帧边界 |
| 0x2D8 | invalid_input_frames | frame_end时frame_good为0 |
| 0x2DC | fifo_failed_frames | 每次采集首次发生无打包槽/FIFO背压溢出 |
| 0x2E0 | geometry_failed_frames | 非预期SOF、越界坐标或像素数过量 |
| 0x2E4 | incomplete_frames | 提交时像素数不足或最后一字未准备 |
| 0x2E8 | invalid_commits | 提交时frame_good为0 |
| 0x2EC | marker_errors | DDR侧SOF/EOF与预期beat位置不符 |
| 0x2F0 | padded_frames | 未发布而填零结束的采集帧 |
| 0x2F4 | capture_timeouts | 采集看门狗触发次数 |
| 0x2F8 | max_capture_stall_cycles | 有有效采集字但writer不接收的最长连续DDR时钟数 |
| 0x2FC | last_capture_failure | 最近失败的原因锁存 |

last_capture_failure的bit0/1/2/3分别是FIFO满、输入帧无效、提交不完整、坐标异常；bit4为同步后的bad，bit5为pad。原因计数允许重叠，例如FIFO溢出也可能造成提交不完整。该扩展不控制ready、复位、DDR仲裁或像素发布；像素域累计数通过held-bundle mailbox跨域，不能用失败标志简单双拍同步替代累计数的跨域传递。

若同一标定下显示与headless均约40fps、warp/DMA单阶段均小于17ms，应先核对RXD1与源帧号。invalid_input_frames增长指向输入时序；fifo_failed_frames增长且输入帧有效指向采集写入背压；marker_errors增长则应查打包/帧边界。不能仅因单个阶段小于17ms宣称整链路60fps。

逐帧硬件追踪在ARM仓库运行：

```sh
python3 tools/warp_frame_trace.py --frames 10000 --timeout 300 --out /userdata/warp-10k.jsonl
```

工具只读BAR0，先检查快照代次；同一代次只读取sequence，出现新快照才取完整计数。它累加每个8ms快照的周期和帧差分，记录每个新warp/DMA完成的last周期。`missed_frame_observations`非0时，不能把所记录的最大值宣称为全部帧的最大值；完整验收要求warp和DMA都没有漏观测。还需联合capture/skipped与KMS EOS总数核对，工具通过不单独证明物理屏幕送显。

可加`--compact`降低采样自身的MMIO流量，RXD1可用时每快照从约67次读取降至20次，全部验收字段和首尾代次一致性检查保留；默认完整快照不变。精简快照省去未用于本工具判定的带宽/tile计数，测各流带宽时另用低频`warp_perf.py`。此优化尚未证明能改善真实帧周期。

有限显示运行加`--verbose --frames 22000`，退出后在ARM仓库执行`python3 tools/check_frame_log.py <完整显示日志>`，核对至少10000个连续的新source、连续frame、固定generation、平均≥59.9fps及EOS submitted=rendered=已验证日志条数、dropped=0。周期追踪和源帧/送显检查都须通过，任何一项失败都不能验收。

结果文件和`.summary.json`包含原始首尾快照、逐阶段fps、耗时最大值和采集异常；缺少RXD1明确标记诊断不可用，不把缺失字段当成实测0。`hardware_acceptance_pass`同时要求至少目标帧数、无漏观测/错误/采集丢弃、各阶段≥59.9fps（容许标称60Hz时钟偏差）、warp/DMA最大值≤17ms。原始数值仍需保留，不能仅提交一个PASS标签。

全帧精度复核在Windows的`FPGA_AADCS/HDMI_Warp`目录运行，参数文件必须是ARM实际应用后导出的17个定点字记录：

```sh
python sim/full_frame.py --params checks/2026-10-28-live60/capture2/capture2_calibration.applied.json --modes serial fast --out build/full-native-ab --timeout 1800
```

结果保存各路径2073600像素、校验和、输入和源码SHA256。任一像素不一致立即失败；`max_error=0`因此也满足逐RGB565通道最大误差0和PSNR=∞。这使用DDR接口模型验证数学/边界/所有权，不代替物理DDR或10k帧连续送显测试。与当前`COORD_PIPELINE=1`对应的已有完整证据在`checks/2026-10-28-live60/coord-pipeline-proof`。

本轮60Hz验收使用已发布的原生1080p标定代次，电脑有源信号1920×1080/60Hz，运行唯一的`stage/run.sh --mode cam2 --kms`进程并每秒采样，连续累加至少10000个新warp、consume和DMA帧。联合记录capture日志的source/skipped，要求稳态skipped不增加、错误及discard为0。启动前无人消费造成的历史skipped绝对值不作为测试期丢帧。结束时SIGTERM该进程、等待EOS排空，核对submitted=rendered且dropped=0，再恢复显示；不能让两个捕获进程同时争用DMA。headless只作为显示影响的对照测试。

采集写入对照：`build.ps1 -CaptureWriteBanks 1`恢复原单缓存；2启用双256B写缓存。`-CaptureFifoBits 11/13/14`分别是32/128/256KiB有效像素缓存，SOF/EOF元数据另占空间。每个组合都须重新验证最终时序和资源；FIFO更深不自动代表平均吞吐达标。默认构建和下载要求所有时序通过且最差setup≥+0.197ns，临时诊断例外不能沿用为正式验收。

若输出scratch满等待远高于源tile等待，下一包应验证短行写突发与DDR仲裁占用，不应仅凭先验假设增加source缓存。平均AR突发仍受硬件16-beat上限限制；TIL1没有伪造256-beat能力。

## 10. 像素选择流水级与独立后端复现

`WARP_SAMPLE_PIPELINE=0`保持原选择器，1在缓存bank选择后增加一拍，同时延迟有效位、边界mask与插值权重；配置入口是`build.ps1 -SamplePipeline 1`。小帧及背压对照可运行：

```sh
python sim/regress.py --tests warp_fast_sample warp_fast_sample_stall warp_fast_sample_legacy_coord warp_fast hdmi_live_sample
python sim/full_frame.py --params checks/2026-10-28-live60/capture2-fifo13-s8/fifo13_resume.applied.json --modes fast_sample --out build/full-live60-sample --timeout 1800
```

2026-10-29全帧结果为2073600像素最大误差0；日志和源码hash在`checks/2026-10-29-live60/sample-pipeline-proof`。每个候选都须重新完成物理实现及最终STA，不能借用这个功能仿真作为时序证据。

若试用旧合格实现导出的DDR PHY位置作为布局提示，先使用`build.ps1 -Action dev_map -RtlSnapshot`完成本次映射，再追加提示；重新运行整个PDS工程可能再次映射并覆盖PCF。独立`pds_shell -action place_route`以本次map ADF和工程为输入，工作目录必须设为候选`place_route`目录；之后从`report_timing`目录对新PNR ADF执行独立`-action report_timing`，以最终`.rtr`验收。不能以hold修复后的中间summary替代最终STA。

生成位流可使用已核实的Tcl `set_arch -family Logos2 -device PG2L100H -speedgrade -6 -package FBG484`和`gen_bit_stream -force_to_run -input_db_file {本次PNR ADF绝对路径} -scbv {High Voltage}`。基准PNR重生成位流已比较，仅创建时间字段6字节不同，配置载荷相同；这不免除每个新候选的最终时序检查和DONE/CRC回读。

导出提示含`-no_check`，部分名称会在重新优化时消失或改变位置，必须用`generate_constraint`从本次PNR再次导出并逐实例比对。读权重2诊断候选的2032条旧PHY位置仅1321条完全保持，不能声称锁定整个PHY，也不能把旧实现的时序裕量套用到新候选。

USB远程助手当前配置的客户端可能与旧版本目录不同；只读取其`VirtualHerePath`字段，使用当前客户端执行`LIST`/设备操作。含空格的API命令通过PowerShell `Start-Process -ArgumentList`传入时须保留整段引号，如`'"STOP USING,列表中的FTDI地址"'`，避免把`STOP`和`USING`拆成两个参数。`LIST`中的已占用及Windows驱动OK仍不能证明可编程；必须以PDS成功打开电缆并扫描到PG2L100H为准。


## 11. 采集计数流水线与有限联测

`build.ps1 -CaptureCountPipeline 1`预寄存采集端的`total-1`，拆开减法与最终128-bit像素字的使能路径；默认0保留原实现。`python sim/regress.py --tests hdmi_rx_count_ab hdmi_live_count_pipe`分别逐周期比较完整1080p数据/帧标记，并测试真实PCIe模型。仿真覆盖8像素最小帧、几何切换、空拍、坏帧与FIFO溢出，证据在`checks/2026-10-30-live60/capture-count-proof`。不能以此替代最终STA。

ARM仓库的`sh tools/bench_live60.sh <RAM输出目录>`同时运行有限22000帧显示和18000帧精简硬件追踪，启动显示3秒后自动开始计数，避免人工延迟导致追踪跨到EOS后空闲。默认沿用三槽解耦、256B复制、直接RGB565和可选3复制线程；设置`FPGA_COPY_WORKERS=2`可对照。显示及追踪都结束后才检查源帧日志，结果为`result.txt`和两个独立JSON判定。测试结束后归档RAM记录，避免重启丢失。

可选`FPGA_KMS_POOL=1`使用kmssink通过ALLOCATION查询提供的缓冲池；填充时遵循VideoMeta的实际pitch和offset，不依赖私有KMS头文件。默认关闭，保留系统内存GstBuffer路径。查询池模式与普通路径都须通过`make -C tests kms-copy CC_HOST=cc`，验证全1080p、补齐行、源缓冲复用、保留帧和池退役。随后重新跑相同有限联测；不能只凭省去一次复制判定吞吐改善。

联测前分别确认电脑→FPGA的有源信号与ARM→屏幕的真实模式，两者不是同一条HDMI链路。ARM显示曾为720p60且DPMS关闭了扫描输出，现已设置HDMI-1为1080p60。临时关闭屏保/DPMS做对照时，退出必须恢复测试前设置；不能把一次模式/电源设置变化混入其他A/B收益。源帧/EOS通过、逐帧周期通过与正式setup≥+0.197ns三项缺一不可。
