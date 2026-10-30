# 1080p60 优化与验收

状态：实现和离线验证进行中，尚未完成1080p60实板验收。基线为FPGA `4033bda`、ARM `e37bdd3`；旧WP1位流保留在 `build/wp1-overlap`，作为已验证回退版本。

当前保存版：`FPGA_AADCS/HDMI_Warp/releases/live60-20261030`，位流37cf17a1…cc23409e，最终setup +0.271ns，已下载并恢复显示。该目录README/manifest记载最新测试，以下为历史过程记录。22000帧全部送显，其中21989连续源帧60.000864fps；重复14000帧有4个稳态单帧跳号，保留偶发丢帧限制。重复测试10500帧硬件追踪无漏观测、59.98003fps、warp最大16.87446ms、DMA14.27254ms。原22000帧对应18000帧追踪漏warp1/DMA2，不能当作完整联合验收通过。

2026-10-30：JTAG已恢复识别PG2L100H；随后获准的读权重2诊断位流`61c8f0d5...177a3e99`首次成功写入SRAM，PROGRAM_RESULT=0、DONE=1、CRC/RBCRC均0。该位流最终setup +0.118ns，仍仅作诊断，不满足正式+0.197ns。重新插拔HDMI后识别到1920×1080、148.499MHz、约59.99977Hz，原生标定17个定点字逐项匹配，accepted/applied/published=1。ARM使用原`ddfdac9`对应程序及三项既有可选开关；正在记录有限22000帧和10500帧精简周期追踪，尚无本次吞吐结论。证据在`checks/2026-10-30-live60/weight2-diagnostic`，当前ARM boot_id=`ed1d9b9d-7569-4ec0-894d-02db2bee4067`。

上述诊断第一轮已完成：10500帧/175.825224s，capture/warp59.718394fps、consume/DMA59.724082fps，FIFO/discard/无效输入/marker/超时/协议错误均0；已观测最大warp16.854705ms、DMA14.267698ms，但漏观测1个warp事件，因此不能把该最大值宣称为窗口内所有帧上限。有限显示22000帧，KMS EOS=22000/22000/0，最长连续源帧段仅2826帧，出现67个断点，整链路验收失败。与原权重1实测相比，观测到的warp耗时降低，但端到端吞吐和源帧连续性退化，不能只报告warp≤17ms。

2026-10-30后续对照（所有行均使用同一读权重2诊断位流、原生标定代次1）：

| ARM运行 | 硬件追踪 | 最大warp / DMA | 有限显示及源帧检查 | 结论 |
|---|---|---|---|---|
| 可选3复制线程，磁盘日志 | 10500帧，60.00194fps，无漏观测和硬件错误 | 16.84072 / 14.26584ms | EOS22000/22000/0，最长连续15775帧但59.78676fps，12断点 | 追踪窗口通过，完整源帧检查失败 |
| 可选3线程，RAM日志 | 追踪启动过晚，退出前仅观测17955帧；360秒结果包含EOS后空闲 | 16.85146 / 14.27009ms | EOS22000/22000/0，最长连续3151帧，25断点 | 失败，不能把含空闲的49.875fps当实际吞吐 |
| 3线程，ARM屏幕1080p60、暂禁DPMS | 18000帧，58.99441fps，漏warp2/DMA3，无硬件错误 | 16.83829 / 14.25881ms | EOS22000/22000/0，321断点，最长863帧 | 失败 |

3线程默认关闭，复用相同3个原始DMA槽和缓存槽，不增加CMA。四组原生pipeline测试通过。第一行已归档`checks/2026-10-30-live60/worker3-disk`；RAM/profile/display_on原始记录仍在ARM，待本轮测试结束后归档。

只读阶段计时显示，profile运行中appsrc入队曾阻塞571466us，对应等待缓存槽572465us；同次PIO读最大618us，不能把该长停顿归咎于寄存器读取。ARM显示原模式为1280×720@60，现已设置HDMI-1为1920×1080@60；实际vblank热身后测量120帧/2.000054424s=59.998367Hz，像素时钟148.5MHz。临时关闭DPMS没有消除吞吐损失，测试后已恢复原600秒屏保/DPMS设置。

正在A/B可选`FPGA_KMS_POOL=1`：按GStreamer公共ALLOCATION查询取得kmssink缓冲池，直接按实际pitch/offset填入RGB565，保留独立缓冲所有权，减少插件对普通系统内存帧的二次复制。默认仍原路径。真实发布函数单测覆盖查询池、填充行、非零offset、源立即复用、消费者持有帧及池退役后的数据完整性；板测结果尚待验证，不先宣称收益。

像素选择流水级normal seed4候选最终STA最差-0.344ns；同map的performance seed8加2032旧PHY提示重试已完成，最终最差-2.132ns。两者均未生成/下载位流。后者记录在`checks/2026-10-30-live60/sample-phy8-retry`，不能称作仍在运行。

新增可关闭`CAPTURE_COUNT_PIPELINE=1`把采集端total-1预先寄存，分离减法进位链与最终像素字的128位CE判断；默认0。完整1080p逐周期A/B、动态几何、8像素边界、停顿、坏帧/FIFO溢出及真实PCIe模型通过，见`capture-count-proof`。结合SAMPLE_PIPELINE1的`build/live60-countpipe-critical4`正在独立物理实现，仅使用两条关键路径位置提示；必须检查实际绑定及最终+0.197ns门限后才能下载。

2026-10-29：读权重2的独立后端候选`build/live60-weight2-phy-reroute`已生成位流，最终独立STA全部约束通过，最差setup **+0.118ns**。用户已允许临时SRAM诊断；该值仍低于正式+0.197ns，不属于正式交付通过。位流SHA256为`61c8f0d5e11378c9d0b5f3fa92ca2a95dbe52c8f4365f1d90e042047177a3e99`。2032条旧DDR PHY位置约束在实际导出中仅1321条完全保持，120条实例不在导出、591条未完全相同（520条site改变、71条仅primitive改变），不能称为PHY完整锁定。最终时序以本次实际PNR/STA为准，不能借用旧布局裕量。

本轮ARM已重启，boot_id=`77a37b0d-0b26-4a84-8eb1-94421c28f87d`，原SRAM版不再保留；显示程序检查到BAR0 magic=54321000后退出，没有启动DMA。SSH已恢复。FTDI在远程USB后端出现，但接入因`Maximum In-Use Devices Exceeded for your License`被拒绝，尚未下载候选、也没有本轮板测收益。证据在`checks/2026-10-29-live60/weight2-phy-diagnostic`。

后续释放摄像头名额并接入FTDI后，Windows两个接口驱动OK，但PDS连续在`cfg_scan_chain`之前打开电缆失败（JtagServer-0006/0306）；没有进入`cfg_program`。只读D2XX查询先为0个设备，后恢复2个但接口标记已打开，最新为A占用、B空闲。ARM随后又重启为`e7422cf4-2ae3-47bc-a831-600171baabb7`，并出现本任务未启动的fpga-probe进程，已请求协调板卡/下载器独占，未停止该外部进程或操作其DMA。

为修正实际像素选择器关键路径，新增可关闭的`WARP_SAMPLE_PIPELINE`：将128-bit缓存bank选择与16-bit像素选择分成两拍，权重/有效位同延一拍，原`bilin`数学不变。默认0保留原路径；`build.ps1 -SamplePipeline 1`构建对照。小帧、长背压、旧坐标流水模式、关闭该级的原路径和完整PCIe五项仿真通过；相同原生1080p标定2073600像素全帧最大误差0、PSNR无限、checksum=aef8e443、1656065cycle。证据在`checks/2026-10-29-live60/sample-pipeline-proof`。该离线模型不包含真实DDR争用，尚无新流水级最终时序或实板结论；独立构建`build/live60-weight2-sample`已完成映射，正在布局布线。

17:14核查发现上述物理实现进程已不存在，日志最后修改于17:05:50，无完成标记及PNR ADF；原因未确认，不能算作时序失败或仍在运行。保留中断记录，基于相同SHA256映射数据库，在`build/live60-weight2-sample-normal4`以normal seed4重新实现，移除追加的2032条旧PHY位置提示以检查拥塞影响，原始必需引脚/PHY约束仍保留。该次尚待最终STA。

映射阶段资源对照（尚非最终布线结果）：合格基线LUT19203、FF27829、DRM109.5、APM199；读权重2+像素选择流水级为LUT19324、FF28922、DRM109.5、APM199，增加121 LUT和1093 FF，不增加DRM/APM。记录和原报告SHA256在`sample-pipeline-proof/mapped_resources.json`。

最新有效板测（相同原生1080p标定）：128KiB FIFO、双采集写缓存、setup +0.265ns的位流，配合ARM可选256B复制、直接RGB565送显及原始/缓存槽所有权解耦，10500帧用时175.018319s，处理/采集59.993720fps、DMA/消费59.999433fps。FIFO失败、采集discard、无效输入、marker、超时和协议错误均为0，逐帧观测无遗漏；最大warp **17.057669ms**、DMA13.542640ms，仍未达到≤17ms。该次未逐帧记录source，因此不能证明连续10000个源帧；进程完整EOS为submitted=rendered=75261、dropped=0，包含测量窗外运行。完整证据在`checks/2026-10-28-live60/capture2-fifo13-s8/fifo13_decouple_10k*`，EOS尾部日志已归档为`fifo13_decouple_eos_tail.log`。

仅启用256B复制与直接送显、未解耦所有权时：10500帧/175.034298s=59.988243fps，最大warp17.073371ms、DMA13.541391ms，同样无FIFO/协议错误，完整进程EOS为38642/38642/0。源帧存在跳号，验收失败。新增`tools/check_frame_log.py`核对有限`--verbose`测试的源帧连续性、参数代次和KMS EOS；它与FPGA逐帧周期追踪共同使用，不能替代后者。

ARM可选优化和只读测试工具已保存为ARM仓库本地提交`ddfdac9`（未推送）。

ARM重启前连续两次3槽分配失败时，旧进程已正常排空、CMA已释放，不能据此断定泄漏。保存CMA现场后重启，恢复上述合格位流，3槽12,441,792字节分配成功；当时HDMI接收为异常尺寸/帧频，未写标定、未作吞吐验收，等待源端重新建立连接。没有修改CMA启动参数、DDR时钟或PCI枚举拓扑。

读权重2候选：performance seed8/9最终时序失败；normal seed4全部约束满足但setup +0.101ns低于正式+0.197ns门限，均未下载。第一次PHY布局导出试验的2032条位置约束被device-map覆盖，结果与无约束seed8一致，不能计作有效试验。续跑试验未成功，相关可选构建代码已撤回，未生成或下载位流；原完整流程的normal seed8/6最终setup分别为-1.065/-0.347ns，均有时序违例，未下载。256KiB FIFO候选因路由/hold修复耗时过长停止，没有最终时序，也未下载。

后续恢复输入后的有限测试：HDMI为1920×1080、约148.499MHz/60Hz，相同17个标定字，accepted/applied/published=1。22000条已验证帧日志中，代次1的连续段为frame1140–22005、source69419–90284，共20866帧/347.758175s=59.998590fps；该段frame和source均逐一增加、无重复，KMS完整EOS为22000/22000/0，源帧/送显检查通过。启动及标定切换前的6个断点已保留，不计入这段连续测试。重叠的精简计数追踪10500帧/174.986363s，0采集/FIFO/marker/超时/协议错误、无漏观测，最大warp17.090910ms、DMA13.539425ms，因此严格周期验收仍失败。精简采样没有消除FPGA周期上限，不能宣称它解决了瓶颈。日志、标定及快照见`capture2-fifo13-s8/fifo13_resume_*`。ARM实际程序SHA256为`eebf19155f61e4264433b6513db29cc1b4f01faec470ecea3c0106f17b286d9d`。

2026-10-28板测：电脑和FPGA均确认1920×1080、60Hz，像素时钟约148.5MHz。首次v9通过全部时序（最差setup +0.382ns，相比WP1 +0.397ns退化0.015ns）后下载，DONE=1、CRC=0。该历史位流SHA256为`9af5f5ae71e81f9057109da36205b82c29223490a54daddf73d8527021ac82c3`。

加载本轮原生1080p标定后，accepted/applied/published均为1，17个定点字与输入文件一致。整链路约40fps：120帧逐帧追踪用时3.00392s，warp最大16.37074ms、DMA最大13.32373ms，无漏观测、协议错误为0，但采集丢弃60帧，判定验收失败。headless也约40fps；KMS一次退出核对submitted=rendered=75171、dropped=0，该长运行包含加载参数前后的不同阶段，不能当作60fps/10k通过证据。原始记录保存在`checks/2026-10-28-live60/board-baseline`，后续追踪在ARM `/userdata/warpchecks_20261028`。

随后用户明确允许临时诊断下载：`build/live60-rxcompact-s6`满足全部PDS时序，但setup +0.064ns低于正式交付要求+0.197ns。此版已下载，DONE=1、CRC=0，SHA256=`51d4aae14e14b402e2d1427057dc9b07cd9cdfc109be5ec75c2a5e1fa6a12b4e`。证据在`checks/2026-10-28-live60/rxdiag-s6`；不能将这个临时例外视作正式时序验收通过。

RXD1已实测确认：每秒输入约60帧、处理/消费约40帧、采集丢弃20帧；`fifo_failed_frames`同增20，`invalid_input_frames`、`geometry_failed_frames`、`marker_errors`、`capture_timeouts`均不增加，last_failure=0x31。采集FIFO溢出是该阶段的实际丢帧原因。最长单次连续writer背压约4.648us；此值不能代替FIFO累计占用或平均服务速率。

128KiB FIFO配单采集写缓存的`build/live60-fifo13-startfix`已通过全部时序，最差setup +0.309ns，下载后DONE=1、CRC=0。原生标定600帧追踪：10.4178522s、57.59345fps、24次丢弃与24次FIFO失败，最大warp 17.081592ms、DMA 13.574624ms，协议错误/无效输入/marker错误/超时均为0。验收失败，说明单纯增加缓存尚未消除服务速率不足。完整证据在`checks/2026-10-28-live60/fifo13-single`。

正在验证两组256B采集写缓存。旧`burst_serial`的FILL与DATA互斥；`burst_double`以独立填充/消费所有权标记允许填充下一突发与当前写入重叠，整组16beat预填满后才发AW，只有实际LAST接受后释放bank。没有增加原生突发长度或更改无WVALID接口。单元测试已覆盖长背压、首个W与AW同拍、换槽、数据顺序、4KiB边界与非法请求；真实PCIe小帧模型通过。32KiB双缓存候选`build/live60-capture2`全部约束通过、setup +0.209ns；128KiB双缓存候选`build/live60-capture2-fifo13`全部PDS约束通过但setup仅+0.188ns，正式门限拒绝下载。双缓存实板收益仍待测，不宣称已达60fps。

32KiB双缓存候选已下载，DONE=1、CRC=0，并恢复相同17个标定字。600帧追踪为44.30788fps、214次采集丢弃、213次FIFO失败、最大warp 16.800853ms、DMA 13.532736ms，无漏观测和协议错误。快照区间边界可能跨越一次FIFO失败与对应discard，不能强求两个阶段差分每次相等；完整计数保存在`checks/2026-10-28-live60/capture2`。此版仍验收失败。正在使用相同RTL为128KiB组合比较布局seed，并比较256KiB配置；仅下载达到正式时序门限的构建。

128KiB双缓存seed8（`build/live60-capture2-fifo13-s8`）已通过全部时序、最差setup +0.265ns，位流SHA256=`002dfd2466ff5d77c644f13c52121681384e1a11749b7511cccdb7f986451a46`。下载DONE=1、CRC/RBCRC=0，恢复相同标定字；600帧稳定追踪59.042fps、FIFO失败/discard/输入无效/marker/超时/协议错误均为0，最大warp17.092ms、DMA13.560ms。headless600帧58.628fps、最大warp16.776ms；两者均不满足60fps验收。资源为LUT19203、FF27829、DRM109.5/155、APM199/240。证据在`checks/2026-10-28-live60/capture2-fifo13-s8`。

ARM在接近60fps后出现新的约束：两个CPU拷贝线程各接近满载，每帧uncached→cached复制约29–33ms，另加约2ms校验；3槽的等待开始出现。原先低帧率阶段“等待空闲缓冲≈0”的测量仍成立，但不能沿用到此新吞吐。尝试4个1080p DMA槽需要16589056B，板上CMA总计16MiB且另有2336KiB占用，分配失败，程序拒绝不对齐地址、没有启动该DMA；恢复3槽后正常，未重启也无泄漏证据。没有修改驱动、CMA或启动参数。

ARM把校验合并到复制的两种试验分别只有57.505/47.805fps，尽管校验与字节单测正确，仍无吞吐收益，代码已撤回。固定拷贝线程核心的短测57.112fps，也已恢复原调度。可选KMS直接从已校验缓存复制到独立GstBuffer，省掉中间RGB565副本；首600帧约60.13fps，但10500帧长测为58.301fps、180.099s、最大warp17.074ms、DMA13.557ms，FIFO/discard/协议错误为0，源帧有跳号，验收失败。没有用重复显示旧帧补足帧率，也未将短测当作60fps通过。

本轮使用用户新提供的1920×1080标定，原文件SHA256为 `a00d33db68853eb619e11d5dbd6cc151382b81230fae5f7dad54a89635540586`。本轮before/after必须使用这份参数，不能把此前1280×720缩放标定的31.2ms直接当作同条件基线。

| 同标定实板候选 | FIFO / 采集写bank | 新帧 / 时间 | warp最大 / DMA最大 | FIFO失败 / discard | 全设计setup最差 | 验收 |
|---|---|---|---|---|---|---|
| v9精确在线双像素 | 32KiB / 1 | 120 / 3.003921s，39.948fps | 16.363 / 13.325ms | RXD1不可用 / 60 | +0.382ns | 失败 |
| FIFO13-startfix | 128KiB / 1 | 600 / 10.417852s，57.593fps | 17.082 / 13.575ms | 24 / 24 | +0.309ns | 失败 |
| capture2 | 32KiB / 2 | 600 / 13.541610s，44.308fps | 16.801 / 13.533ms | 213 / 214 | +0.209ns | 失败 |
| capture2-fifo13 seed8 | 128KiB / 2 | 600 / 10.162199s，59.042fps | 17.092 / 13.560ms | 0 / 0 | +0.265ns | 失败 |
| capture2-fifo13 seed4 | 128KiB / 2 | 未下载 | 未测 | 未测 | +0.188ns | 正式裕量门限拒绝 |

采集写流仍约249MB/s，即便帧被丢弃，现有错误排空逻辑也会把该帧的剩余部分填零写完；不能用采集写字节数除以4,147,200就断言成功捕获了60帧。capture2的源图约251–257MB/s、主机约179–184MB/s、输出约178–183MB/s，平均源/host突发约3.99/15.36beat，实际峰值warp/host/shared在途数16/8/16。峰值在途不代表持续并发，也不代表有效带宽已满。

控制器配置另一个待测因素：`ipcore/ddr3_100h/ddr3.v:303`为BANK+ROW+COLUMN，且`ddrlink.v`将byte地址右移一位后送入x16原生接口；结合row=15、column=10、bank=3，现有低于64MiB的帧/表区域都映到物理bank0。这是代码与[HMIC_S官方指南2.5.1、图2-17](https://www.pangomicro.com/en/uploads/17503246_1729499157.pdf)的地址解释，尚未用板测证明它造成了多少损失。本轮候选没有更改该映射、DDR参数或内存基址。

可选读调度A/B：`WARP_READ_WEIGHT=1`保留原按命令轮询；2在两个读者均待发时按source/source/host顺序接受请求，缺席者直接跳过，host最多等待两笔source地址握手。返回仍使用原16深所有权队列、ID0按序路由，无新tag格式或返回重排。仅快速路径可选启用；顶层默认仍为1，`build.ps1 -WarpReadWeight 2`构建对照。权重1/2、返回延迟/同拍首返回、队列回绕、地址背压、读者暂时缺席和完整PCIe小帧仿真已通过，16128个RGB565像素精确匹配，证据在`checks/2026-10-28-live60/read-weight-proof`。尚无权重2板测收益，不能将其写成已达标。

## 调度与精度

1. `fetch.v`保留串行实现，增加按序8笔在途预读。每次AR前预留完整突发容量；128个128-bit返回槽覆盖8×16beat，在没有RREADY的接口上承受消费者无限背压。保留4KiB边界分割、实际突发≤16beat、ID=0返回顺序及原DMA描述符接口。`HOST_READ_OUTSTANDING=1`恢复旧读取逻辑。
2. `hdmi_map_pipe.v`由 `tools/gen_map_pipe.py`生成，将原Brown/仿射计算展开为38拍、II=1的流水线，复制为两个坐标通道。每一级仍是原32-bit有符号定点截断，逆焦距Q2.30，源坐标Q20.12；没有径向近似、坐标压缩或插值精度变化。
3. `warp_fast.v`以两个像素/拍复用同一 `bilin.v`。源缓存按tile所有者拆开，载入tile写端口与正在处理tile的两个读端口互不覆盖。源缓存范围仍是每tile至多512×128像素，保持原越界黑色规则。
4. 将4个相邻32×8 tile的输出转置到两个2KiB条带scratch，按行合并至16beat写入；尾部不足128像素的条带及不足8行的帧尾仍精确处理，写突发不跨4KiB边界。最后一个实际DDR写beat接受后才发布帧、释放资源。
5. 第二版用独立坐标生成、源预取和渲染控制器重叠三个阶段。map_generated / published / ack三个所有权标记防止坐标或源缓存提前复用；不增加源缓存容量。
6. `COORD_PIPELINE=1`在坐标RAM之后增加寄存级，分开BRAM输出与边界判断/地址路由；0恢复旧fast路径时序。原生1080p标定全帧对比2073600像素最大误差0、checksum=aef8e443，1652529cycle（12.591ms接口模型），证据在`checks/2026-10-28-live60/coord-pipeline-proof`。该离线结果不包含真实DDR争用。

`WARP_FAST=0`保留原二维DDR表路径；旧建表器、原tile引擎和串行/重叠开关均保留。新路径每帧坐标表DDR读写量为0，完整Brown模型在线计算，17个BAR参数与原子提交协议不变。RAW/输出帧槽基址、RGB565、CAM3帧尾和校验和也保持不变。

## 配置与构建

```powershell
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 8 -BuildDir build/live60 -RtlSnapshot
# 采集FIFO默认128KiB；恢复32KiB作A/B：
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 8 -BuildDir build/fifo32-ab -CaptureFifoBits 11 -RtlSnapshot
# 单采集写缓存A/B（默认2，原生突发仍为16beat）：
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/capture-serial -CaptureWriteBanks 1 -RtlSnapshot
# 恢复二维表处理，或完全旧调度：
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/table-ab -LegacyWarp
./FPGA_AADCS/HDMI_Warp/build.ps1 -Seed 4 -BuildDir build/serial-ab -WarpSerial -HostReads 1
```

`-RtlSnapshot`将本次实现的RTL复制到构建目录并记录SHA256，PDS全程读取该副本。后续修改checkout不会污染正在运行的实现。IP和约束也必须保持本次构建所用版本。

构建/下载默认调用`tools/check_timing.py`，要求全部约束满足且全设计Slow Corner setup最差值≥+0.197ns（WP1 +0.397ns减去允许退化0.2ns）。临时诊断例外需明确记录，不能以“PDS全绿”替代正式裕量要求。

默认EDID为FPGA LIVE60，首选1080p60，同时保留1080p50/30/25/24、720p60/50/30/25/24。由 `tools/live_edid.py --max-fps 60`生成，含150MHz最大TMDS声明与正确校验和；`--max-fps 30`可重建旧默认。KEY1其他6个历史profile保留。HDMI输入时钟约束原本就是148.5MHz，未放宽时序约束。

BAR0原PRF0区域不变；TIL1配置word bit16表示精确在线双像素路径，bits15:8仍为输出槽数2、bit0仍表示计算/写回重叠。新ARM只读工具识别online_map / pixels_per_clock，不修改捕获或显示行为。

## 已完成离线验证

| 检查 | 结果 |
|---|---|
| 主机8笔预读、返回存储耗尽、长期消费背压、4KiB分割、多次环形回绕、同拍首返回 | 通过；延迟模型峰值8在途；即时返回模型通过 |
| 坐标流水线 | 300组随机参数和2560个连续/插入空拍坐标，精确匹配原定点模型 |
| 第一版双像素，连续两帧并修改源图 | 所有RGB565像素及原raster checksum一致 |
| 第一版1500-cycle周期写背压 | 输出满等待实际发生，无提前done或缓存提前复用 |
| 第一版真实PCIe模型 | 16128像素全部一致，含动态64×40→96×44、尾部tile、原子参数切换、随机DDR/PCIe停顿 |
| 原标定全1080p第一版A/B | 每路径2073600像素精确匹配；最大误差0、PSNR=∞、checksum均aef8e443 |

第一版全帧接口模型：串行2704090cycle，在线双像素2134057cycle。后者按131.25MHz折算16.260ms，**这是没有真实DDR争用的接口模型，不是实板60fps证明**。因此继续实施第二版生成/预取重叠，以获得板上余量。原始数据留在 `checks/2026-10-27-live60/v1`；约50MB测试hex仅保存在忽略的build目录。

第一版device-map资源：APM199/240、DRM150.5/155、LUT18635/66600、FF25819/133200。推断的1写2读RAM被工具复制；改为明确的TRUE_DUAL_PORT原语后，源缓存不再复制，v5使用DRM86.5/155、APM199/240。该原语的全部2048地址、独立双端口读和3次换图已经与本机PDS官方功能模型比较，12288次读取一致。完整系统仿真使用等价行为缓存，原语另作组件验证；尚不能把该组合验证当成板测。

v5整帧使用本轮原生1080p标定，1650341cycle（131.25MHz折算12.574ms），2073600像素全部精确一致，checksum=aef8e443。结果和输入/源码哈希保存在 `checks/2026-10-27-live60/v5`。相对原路径的画质最大误差为0、PSNR为无穷；这仍是DDR接口模型的结果。

v4最终时序失败：DDR setup -0.078ns、PCIe pclk -0.016ns。v5增加RAM输出寄存级后，原读路径违例消除；最终DDR写地址路径setup仍为-0.180ns，HDMI配置复位恢复时间为-1.569ns。两个候选均未下载。v6b增加源缓存写入寄存级，利用原发布状态机已有的排空周期；同时用寄存器驱动配置复位，保持计数归零的同一拍释放，不放宽时钟或复位时序约束。`REGISTER_CFG_RESET=0`保留旧复位逻辑，顶层二维表回退也选择旧逻辑。v6最初快照因声明顺序问题在综合前取消，实际修正版目录为v6b。

PDS官方原语模型属于本地安装文件，不复制进Git。`sim/vendor_models.py`只生成忽略目录内的Icarus功能适配，并保存原始/适配文件哈希；它不模拟硬件建立保持时间。

## ARM显示路径

新工具能读取TIL1在线映射和2像素/拍标记。原GTK显示与全部捕获/DMA/校验接口保留；`--native565`可省去ARGB展开，`--kms`可选原生RGB565的HDMI硬件图层。KMS通过实际DRM资源查询选择已连接HDMI，沿用桌面扫描模式，不猜连接器编号、不接管DSI；底层GStreamer `kmssink skip-vsync=true`用于避免原子提交后再等待一次垂直同步。

每次KMS提交持有独立图像副本，不会在GPU/扫描输出仍使用时覆盖生产缓冲。最多2个appsrc队列缓冲并施加背压；结束时发送EOS排空，记录submitted/rendered/dropped总数。此模式需要可选的gstreamer-app和libdrm开发包；缺失时仍可构建原GTK程序。

独立显示能力测试：真实窗口绘制路径在持续60次/秒提交时出现周期性卡顿，Xorg有flip timeout日志。禁用合成器、单HDMI布局、停止更新标题、持续GTK tick均未解决，因此没有保留这些无效绕行改动。KMS 900帧测试在1280×720扫描下提交约59.968fps、无落后一周期的提交、无上报丢帧。改为实际1920×1080@60扫描后，10800次提交约59.964fps、无上报丢帧；该旧测试程序还未作EOS尾帧总数核对，且绝对60Hz调度累计产生lateness，不能作为端到端10k帧验收通过。当前改为带EOS排空和总数核对的实现，等待与最终FPGA位流共同验收。

板上已用新KMS程序显示旧WP1位流：输入30fps、消费约30fps，稳定区间无新增源帧跳号，DMA约21.85ms，处理约30.60ms，错误标志0、无新增discard；这只验证ARM新显示接入，不代表FPGA已达60fps。

单独主机预读候选 `build/host-prefetch-v2`虽然完成实现，但旧tile包围盒路径setup WNS=-0.007ns，未通过，**没有下载该候选位流**。该记录不作为功能或60fps验收成功证据。

## 板测验收

待最终位流满足全部约束，且全设计setup WNS相对WP1 +0.397ns恶化不超过0.2ns后，再下载和读取DONE/CRC。先在30Hz输入下验证新位流/新参数代次、完整校验和及各流计数，再把电脑**有源信号**切为1920×1080、60Hz。

同时核对输入频率、源帧号、采集/处理/消费/DMA完成差分、图像及参数代次；至少10000个新帧，不用重复显示旧帧凑fps。32-bit计数器按1秒采样累加，检查无新增skipped、异常discard和错误标志。headless吞吐与GUI显示分别验证。生成/搬运流水线的稳态帧周期与从输入像素到屏幕的端到端时延分别记录，不混为一谈。

最终对比表、位流哈希、板测记录和ARM显示结果待实测填写；当前不能宣称60fps目标完成。
