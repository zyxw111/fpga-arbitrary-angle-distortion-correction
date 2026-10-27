# Warp 吞吐诊断（Phase 0）

日期：2026-10-27。范围：只增加被动观测、只读寄存器与测试/文档，不实施 WP1–WP5，不改变坐标、插值、像素、DMA 描述符或帧缓冲所有权。

## 1. 版本与证据口径

| 对象 | 位置 / 状态 |
|---|---|
| FPGA 活跃工程 | `F:/AADCS_git_zyxw/FPGA_AADCS/HDMI_Warp/hdmi_warp.pds`，PG2L100H-6 FBG484，HDMIK V1.1 |
| FPGA 仓库 | `https://github.com/zyxw111/fpga-arbitrary-angle-distortion-correction.git`，本地 `zyxw-gpt`，HEAD `e546b9920ea095ada55b97f65c307f4ace6e1c49` |
| ARM 仓库 | `F:/git_clone/RK3568-PCIE`，`https://github.com/Polaris-PT/RK3568-PCIE.git`，本地 `main`，HEAD `e952e01066e29227d18204c8331e16c407b0ca02` |
| 当前源码 | 两个仓库均已有上一轮尚未提交的 CAM3 / 并发预取 / ARM 流水处理改动；本报告基于工作区，不能仅用 HEAD 复现 |
| 诊断前板上位流 | `FPGA_AADCS/HDMI_Warp/build/generate_bitstream/hdmi_warp_top.sbit`；SHA256 `2faf8a38a7a7951c370346d4c79aecbce9d514dec60a7cba816ddd858e8b256d` |
| 交付目录旧位流 | `firmware/fpga/hdmi-warp/hdmi_warp_top.sbit` 仍为旧 CAM2，不能代表当前 CAM3 工作区 |
| Phase 0 构建 | v1独立目录 `FPGA_AADCS/HDMI_Warp/build/perf-phase0`；修正DMA观测接线的v2在 `build/perf-phase0-v2`；不覆盖诊断前位流 |

用户给出的 **31 ms 等待 + 21 ms DMA ≈ 52 ms / 19 fps** 作为历史实测基线接受。当前工作区已包含此前做出的并发改动，因此不能把旧基线的“全系统并发度为 1”直接套到当前每个 DDR 客户端。

证据等级在下文分别标注为：代码事实、已有板测、仿真、理论估算、待测。未完成的板测不能写成达标。

仓库另有 `FPGA_AADCS/Distortion_video/board_video.pds`、根目录 `joint-pnr-help.pds` 和旧内部图案路径。`Distortion_video/source/rtl/distortion_coord_pipeline.v:8` 为每拍一个坐标的并行流水实现；`Distortion_video/source/rtl/warp.v:3–7` 明确要求外部读像素器每拍返回四邻居，**自身未实现DDR缓存/调度/PCIe**。其Q28/Q30等定点定义也不同于当前HDMI路径，不能当作已经接通DDR的即插即用替代。本阶段未搬入或改动它。旧模块虽可能出现在编译列表，实际采用路径以当前HDMI顶层实例树为准。

## 2. 定位索引（文件:行号）

下列 FPGA 路径以 `FPGA_AADCS/HDMI_Warp/` 为根；ARM 路径以 ARM 仓库为根。

| 功能 | 代码位置 | 定位结论 |
|---|---|---|
| 顶层连接 / 默认尺寸 | `source/rtl/hdmi_warp_top.v:3`、`:188`、`:218` | HDMI → 原图 DDR → warp → 结果 DDR → PCIe；手写 RTL，无 HLS |
| HDMI 输入 / 格式验证 | `source/rtl/video_rx.v:1`；`source/rtl/hdmi_live.v:51` | RGB 输入转 RGB565；当前宽度须为 32 倍数、总像素为 128 倍数，上限 1920×1080 |
| 逆映射 / 定点运算 | `source/rtl/hdmi_map.v:1`、`:80`、`:97` | 逆仿射 + Brown 径向及切向畸变；内部 Q16.16，逆焦距 Q2.30，输出有符号 Q20.12 |
| 表生成 / 存储 | `source/rtl/warp_lut.v:1`、`:20`、`:42` | 参数代次或尺寸变化时重建；每像素 X/Y 各 32 bit；按 32×8 tile 排列 |
| 表 / 源图预取 | `source/rtl/warp_tiles.v:35`、`:83`、`:98` | 每 tile 表读取 128 个 128-bit beat；源图按包围矩形逐行预载 |
| 请求解耦 | `source/rtl/tile_fetch.v:11`、`:17`、`:39` | 元数据队列 16 深；AR 握手后即推进下一地址，不等本笔 RLAST |
| 源图片上缓存 | `source/rtl/warp_tiles.v:22`、`:23`、`:94`、`:161` | 四奇偶 bank / 双 tile 缓冲；单 tile 源足迹限制约 512×128 |
| 插值 / 输出写入 | `source/rtl/bilin.v:3`；`source/rtl/warp_tiles.v:176`、`:218` | RGB565 四抽头双线性；输出每个 32-pixel tile 行发一个 4-beat 写突发 |
| DDR 调度 | `source/rtl/video_ddr_arb.v:20`、`:57` | 3 写客户、2 读客户；读 owner FIFO 16 深；写单 owner 持有到 LAST |
| DDR IP 封装 / 位宽 | `source/rtl/ddrlink.v:6`、`:14`、`:42` | x16 物理 DDR，128-bit 用户总线；上层 byte 地址转换为 x16 存储地址；固定 ID=0 |
| 采集 / 表写入 | `source/rtl/burst.v:30`、`:36` | 16-beat 预缓冲；每笔 256 B，无 WVALID / B 通道 |
| 输出读回到页缓冲 | `source/rtl/fetch.v:14`、`:69`、`:76` | ADDR → RECV → SEND，整笔接收并排空后才发下一笔；此处仍单 outstanding |
| 页缓冲 / CDC | `source/rtl/bridge.v:1`；`source/rtl/hdmi_live.v:153` | 最多 4096 B 页预备后才发送，不是整个帧的第二份 DDR 拷贝 |
| FPGA 帧缓冲所有权 | `source/rtl/hdmi_live.v:19`、`:103`、`:146`、`:202` | 原图 3 槽、输出 3 槽；处理、采集、搬出分别持有独立槽 |
| DMA / 门铃 / 拆页 | `source/rtl/frame_dma.v:12`、`:45`、`:66` | 整帧门铃，按目标地址 4 KiB 边界拆页，逐页等完成；不是 AXI VDMA |
| PCIe 状态读接口 | `source/pcie_dma/ips2l_pcie_dma.v:187`；`source/rtl/hostlink.v:67` | BAR0 按 128-bit bank 返回状态；BAR1 原有写控制保留 |
| ARM DMA 内存 | `src/fpga_capture.c:208`、`:270`、`:848` | 驱动申请连续 DMA 内存，运行时得到 bus address；不能写死 ARM DDR 地址 |
| ARM 搬出 / 校验 | `src/cam2.c:120`、`:188`、`:206` | DMA 结束后缓存拷贝，再做原 checksum；COPY 与 DMA 耗时是不同口径 |
| ARM 帧所有权 | `src/cam3_pipeline.c:7`、`:33`、`:61` | FREE → DMA → COPY → VERIFY → READY → HELD；DMA / CPU worker 分离 |
| ARM 显示 | `src/main.c`、`src/window.c` | RGB565 → ARGB / Cairo 显示还有独立成本，不可用接收 fps 代替屏幕新帧 fps |
| 时钟 | `hdmi_warp.fdc:1`；DDR IP `pnr/ddr_test.fdc:8`；`build/report_timing/hdmi_warp_top.rtr:20` | DDR 用户 131.25 MHz；PCIe约束125/250MHz，实际用户时钟随链路模式变化，见下文；HDMI外部时钟可变 |

ARM仓库 `ref/pango_pci_driver.c:352,524,608` 有 `dma_alloc_coherent` 参考代码，但尚未证明它就是当前 `/dev/pcie_dma_memcpy` 的分配/mmap实现。当前misc驱动的缓存页属性与DMA同步语义仍待核对，不能据参考驱动直接改pgprot或删除CPU缓存拷贝。

## 3. 内存映射与字节数

所有 FPGA 地址均是 **byte 地址**。下表中的 end 为不含该地址的结束位置。当前 RGB565=2 B/px；1080p 为 4,147,200 B，非 6.2 MB。

| 区域 | 基地址 | 容量 / 有效大小（1080p） | B/px | 访问顺序 |
|---|---|---|---:|---|
| 原图槽 0 / 1 / 2 | `0x0000000 / 0x0400000 / 0x0800000` | 每槽 4 MiB；每帧有效 `0x3F4800`=4,147,200 B | 2 | HDMI 光栅顺序写；warp 源矩形按行读，tile 间可能重复 |
| 输出槽 0 / 1 / 2 | `0x1000000 / 0x1400000 / 0x1800000` | 每槽 4 MiB；每帧有效 4,147,200 B | 2 | 32×8 tile 顺序写入最终光栅地址；host 光栅顺序读 |
| 二维 XY 表 | `0x2000000` | `W×ceil(H/8)×8×8` B；1080p=16,588,800 B，end=`0x2FD2000` | 8 | tile 顺序连续；每 tile 2048 B；稳定参数时每处理一帧读一次，不每帧重建 |
| 表双缓冲（片上） | 无 DDR 地址 | 256×128 bit=4096 B | 8 | 每 bank 对应一个 32×8 tile 的 XY 对 |
| 源图双缓冲（片上） | 无 DDR 地址 | 4 bank ×4096×128 bit=262,144 B | 2 | 按源像素 x/y 奇偶分 bank，服务四邻居插值 |
| 输出 tile scratch（片上） | 无 DDR 地址 | 32×128 bit=512 B | 2 | 算完 tile 后逐行写 DDR |
| PCIe 页缓冲（片上） | 无独立 DDR 地址 | 最大 4096 B / 页 | 2 + 页尾 | DDR 读入、跨域、PCIe 读出；页尾插入最终 16 B footer |
| ARM DMA ring | **驱动运行时分配** | 当前 3 槽；stride=4,147,264 B；总 12,441,792 B | 2 + 每帧 16 B footer | FPGA posted write；ARM CPU 读取；示例日志 bus=`0x7EB00000`，不可当成固定地址 |
| ARM cached ring | `malloc` 等运行时地址 | 与 DMA ring 对应的像素缓存 | 2 | CPU 从 DMA 映射复制，校验后发布；这里才有额外 CPU 拷贝 |
| ARM 显示缓冲 | 运行时地址 | ARGB 每像素 4 B，多显示槽 | 4 | RGB565 转换 / 缩放 / Cairo 绘制 |

16 B footer 是页发送时合成的 `{magic, frame_id, checksum, generation}`，不占 FPGA 输出帧 DDR 的额外 16 B，也不包含 XY 表。

## 4. DDR / PCIe 参数表

| 参数 | 当前实现 / 证据 | 限制 |
|---|---|---|
| 物理 DDR 位宽 | x16，`ddrlink.v:12`，`ipcore/ddr3_100h/ddr3.v:20` | 不等同 RK3568 系统 DDR |
| 当前 DDR 数据速率 | 配置对应约 1050 MT/s；用户 131.25 MHz ×128 bit | 理论峰值约 2.1 GB/s，不能按 x32 DDR3-1600 的 6.4 GB/s 验收 |
| 用户数据位宽 | 128 bit=16 B/beat | 原生接口无 RREADY、WVALID、B 响应 |
| ARLEN / AWLEN | 4 bit，编码 beats−1 | 最大 **16 beat=256 B/笔**；不能直接设为 256 beat |
| IP行/列/Bank配置 | `ddr3.v:14–20`：row=15、column=10、bank=3、DQ=16 | 按此配置单bank行容量为2KiB；不能采用“8KiB/笔正好一DRAM行”的假设；实际颗粒型号另核对 |
| 表读取 | 逻辑任务 128 beat/tile，拆为 8 笔 16-beat AR | “逻辑块 128 beat”不能充当“原生平均突发 128 beat” |
| 源图读取 | 每行 1–64 word，按 ≤16 beat 且不跨 4 KiB 拆分 | 边界处短突发；字节数随映射足迹变化 |
| 结果写入 | AWLEN=3，即 **4 beat=64 B**，`warp_tiles.v:178` | 写仲裁与短写突发也是潜在损耗，原建议未重点覆盖 |
| 采集 / 建表写入 | AWLEN=15，即 16 beat | 先填满 16-beat buffer 再发 AW |
| ID 数量 | 对外固定 **一个 ID=0**，4-bit ID 引脚并未使用 16 个 ID | RID 未接入；无基于 RID 的乱序重排实现 |
| outstanding 上限 | warp 请求队列 16；共享读 owner FIFO 16；host_reader 1 | 16 是 RTL 上限 / 仿真峰值，实际板上峰值由 PRF0 测量；两个客户共享总上限 |
| PCIe 时序约束 / 总线 | pclk_div2约束125 MHz /128 bit；pclk约束250 MHz | 约束不等于实际运行频率；有效速率需测，不能用内部总线峰值代替链路吞吐 |
| 板上PCIe协商（2026-10-27只读） | `lspci -s 0002:21:00.0 -vv`：**2.5GT/s ×2，MaxPayload=128 B，MaxReadReq=512 B** | Gen1 ×2，8b/10b后约500 MB/s，尚未扣TLP/DLLP等开销；不是内部128-bit×125MHz=2GB/s的端到端吞吐 |
| PRF0时钟比值（板上） | 空闲采样：DDR增132,120,576周期时host增62,914,698周期，按DDR131.25MHz推算host约62.5MHz | PCIe用户时钟当前约为约束的一半；只读工具用该比值换算DMA周期，不硬套125MHz；这是计数器比值推算，不是示波器独立测频 |
| DMA 最大单页 | 4096 B，受目的地址 4 KiB 边界进一步限制 | 页准备、TX 完成、下一页启动目前串行 |
| DMA 地址 | 当前门铃 32-bit bus address；容量 / token 原格式 | 保持 `0x280/0x284/0x288` 和旧供应商页命令兼容 |
| HLS / VDMA / URAM | 手写 Verilog；无 AXI VDMA；工程使用 DRM / Distributed RAM | 不应用 HLS pragma，也不假设存在 Xilinx URAM |

## 5. 31 ms 与 21 ms：含义与已有证据

| 口径 | 耗时 / fps | 实际工作 | 证据 / 限制 |
|---|---|---|---|
| 用户历史基线 | ready 等待约 31 ms，DMA 约 21 ms，合计约 52 ms /19 fps | ready 是 ARM 等待可消费输出；DMA 段搬 **输出图像** 到 ARM DDR | 接受实测。ready 等待不等于 warp 内部纯计算周期；可能与上一帧处理 / 当前采集 / 排队重叠 |
| 1080p 输出 DMA 字节 | 4,147,216 B（像素+footer）/约21 ms | FPGA 输出 DDR → 页缓冲 → PCIe → ARM DMA 缓冲 | 约 197.5 MB/s，**不是 16.6 MB 表+6.2 MB RGB 图像 /21 ms** |
| 二维表稳态读取 | 16,588,800 B /处理帧 | FPGA DDR → warp maps scratch | 属于本地 warp 访存；不穿过 PCIe 输出 DMA |
| 源图读取 | 待 PRF0 实测 | 每 tile 包围矩形，可能重复读源像素 | 不应静默按“一帧仅读一次”填实际值 |
| 新预取版本，无显示 | 180 帧，稳态约 30.0 fps；DMA约20.8–21.0 ms、CPU copy约30.3 ms、checksum约1.9–2.0 ms、ready-wait约12.1 ms、slot-wait约0 | DMA、CPU 工作与下一帧处理已经部分重叠 | `checks/2026-10-27-live30/queued-identity.log`。source 帧序号稳态每次+1，跳帧累计值不再增加；不等于完成10k帧验收 |
| 带 GUI / 已有 SIMD copy 版本 | 300 帧平均29.1 fps；DMA约21 ms、copy约40–52 ms；显示日志存在低于30的新帧绘制区间 | ARM 缓存拷贝 / 校验 / 转换 / GUI 竞争仍明显 | 板上 `/tmp/cam3-simd-test.log` 只读复查；不是本次 Phase 0 修改算法所得结果 |
| Phase0 v1 / identity，无GUI | 900帧平均30.0fps；DMA约20.8–21.0ms、copy约21–23ms | 已有NEON版本，不含新数据通路优化 | 基准回灌及同一诊断位流复测均恢复30fps；`checks/2026-10-27-phase0/baseline-capture.log`、`identity-retry.log` |
| Phase0 v1 / 原标定，无GUI（历史对照） | warp34.548–34.582ms；12.016s内约28.962fps | 与v2的warp数据相符；v1的host DMA字段存在接线缺陷，不使用 | `brown.jsonl`、`board-summary-v1.json` |
| Phase0 v2 / 原标定，无GUI（最终） | 1800帧完成；12.016s窗口warp348帧约28.962fps、消费349帧约29.045fps；warp34.559–34.589ms；硬件DMA20.659–20.905ms | 区间边界含在途帧，348/349之差不直接判丢帧；ARM日志DMA约21ms、copy约22–23ms、ready-wait约13.5ms | `v2-headless.jsonl`、`v2-headless.log`、`board-summary-v2-headless.json`；源skipped仍约每秒+1，不达无跳帧目标 |
| Phase0 v2 / 原标定，GUI（最终） | 8.021s窗口处理29.048fps、消费28.924fps；warp34.512–34.622ms；DMA20.688–20.926ms | 完整GUI日志中copy约43–56ms、绘制fps存在低谷；8秒窗口输出槽等待为0，不代表整个长跑均为0 | `v2-gui.jsonl`、`v2-gui.log`、`board-summary-v2-gui.json`；ARM当前保持GUI实时显示；绘制次数不等于不同源帧数 |
| 启动 / 切参数建表 | 单独统计，不能混入稳态平均 | 顺序固定点映射产生全表并写 DDR | `P_BUILD` 累计周期 / LUT 写 beat；期间可能跳过实时输入帧 |

### 对“21 ms 是什么”的明确回答

它是 **目前实现下的必要跨设备输出搬运 + 可优化的读等待 / 页间协议等待**。它不是另一份全帧 XY 表拷贝，也不能整体标成零价值开销。ARM 后续 DMA→cached ring 的 CPU copy 是另一段可优化成本。

当前 warp 的输出是 **FPGA 本地 DDR master**，ARM 消费者缓冲位于 **RK3568 DDR，需 PCIe master 写入**；两者不是同一地址空间。不能把 `output_base` 改成 ARM bus address 就实现直写。

未来可评估：保留现有门铃 / buffer ownership，内部将 tile 输出重组为 PCIe 可发送顺序，再写入指定 ARM 槽；或继续本地输出 DDR，重叠 warp 第N+1帧与 DMA 第N帧。前者需要完整处理源随机访问、tile顺序、CPU/设备所有权、footer与完成语义，属于 **WP1 数据通路变更，本阶段未实施**。

### 原标定12秒采样：实际流量与等待（v2最终数据）

| 量 | 测量值 | 解释 |
|---|---:|---|
| map / source / host实际返回 | 481.30 /176.21 /120.25 MB/s | 表、源图、输出读取是三条独立流；十进制MB/s |
| capture / LUT / output实际写入 | 120.28 /0 /120.33 MB/s | 稳态没有重建表 |
| DDR读写总和 | 约1018.36 MB/s | 约当前2.1GB/s理论峰值的48.5%；不是按6.4GB/s得出的<20% |
| map / source / host平均原生AR | 16.00 /3.785 /15.360 beat | **源图短突发**最突出；表原生突发已满16 |
| warp / host / shared最大在途 | 16 /1 /16 | 板上证实warp并发已生效；只证明峰值，未证明稳态占空比 |
| warp活跃 / host页处理活跃 | 约100% /59.55% DDR周期 | warp持续忙；这些窗口重叠，不可相加成单帧延迟 |
| 有raw却无output空槽 / raw队列空 | 0 /0 | 当前无GUI下，处理吞吐受warp限制，不是输出槽不足或输入饿死 |
| warp / host有在途无返回 | 25.10% /19.00% DDR周期 | 可与计算、其他阶段重叠，不可直接相减当可节省毫秒数 |
| 现有错误 / 异常采集丢弃 | 0 /0 | 仍有源帧skipped增长；不能据这两个零宣称10k帧无丢失 |
| 硬件DMA忙 / 完成帧 / 完成页 | 60.36% host周期 /349帧 /353,044页 | v2修正后非零，与21ms软件计时和约29fps相符；页数受目标4KiB对齐和区间边界影响 |

warp活跃比例≈1时，host页处理与warp的重叠比例下界由 `warp_fraction + host_fraction − 1` 得到，接近全部host页处理时间。结合独立frame-slot所有权，说明 **当前生成下一帧与搬出前一帧已经基本重叠**。因此原WP1“仅做ping-pong即可消掉21ms串行段”的收益，在当前版本已不能再次兑现；优先修renderer调度及源图事务组织，再依据真实ARM显示瓶颈评估zero-copy。

源读取量约相当于每处理帧6.08MB（约1.47个完整RGB565源帧的字节数，**不是基于唯一像素集合测出的精确重复率**）。按当前事务/表流量比例扩到60fps，总DDR需求约2.1GB/s，已逼近甚至略超峰值，尚未给刷新/调度留余量。目标60fps不能只看延迟，也要降低实际流量或另行提高DDR能力。

v1新增host DMA计数（word33/34/35/38）被发现为0：PDS在generate作用域中为后声明的`stream_busy`、`page_completed`建立了局部隐式线并绑0。**v1这些字段无效，不代表DMA耗时为0。** v2将父作用域信号声明前移，增加DMA忙/完成/周期单元测试，并对该类PDS宽度/无驱动警告设构建失败；**最终板测已验证DMA20.659–20.905ms、349次完成和353,044页增长**。最终结论采用v2；v1仅保留作排错证据。

## 6. 关键握手链路

### 6.1 当前 warp 预取已解耦（不是每像素随机读）

`tile_fetch.v:17–18,39–48`：

```verilog
assign arvalid = busy && !issued_done && count < 16;
wire push = arvalid && arready;
if (push) begin
    // 入队 row / column / length；推进下一笔地址
    // 不以 rlast 作为发出下一笔请求的条件
end
wire pop = valid && rlast;
```

每 tile：预取 XY → 算包围盒 → 预取源矩形 → 发布 scratch bank；相邻 tile 由双 bank 重叠。插值四邻居在片上读取，不是四次独立 DDR 往返。

### 6.2 输出侧仍是单笔读 / 排空后再发

`fetch.v:14,69–85`：

```verilog
localparam IDLE=0, ADDR=1, RECV=2, SEND=3, HALT=4;
assign arvalid = state == ADDR;
// ADDR 等 arready；RECV 收齐本笔，转 SEND
SEND: if (out_ready) begin
    if ({1'b0,index} == chunk - 1'b1) begin
        // 排空以后，才推进 cursor 并返回 ADDR
    end
end
```

时序：`AR有效 → AR接收 → 等RVALID → 收到RLAST → 排空16-beat buffer → 下一笔AR`。H2 在 **该客户** 成立；应测 host_return_wait、host_ar_stall 和平均突发后决定如何预取。

### 6.3 PCIe 页级也串行

`frame_dma.v:64–71`：

```verilog
CMD: if (inject) begin
    expect_page <= page_completed + 1'b1;
    state <= WAIT;
end
WAIT: if (page_completed == expect_page && !page_busy) begin
    // 当前页完成后，才安排下一页
end
```

整帧门铃减少 ARM 每页提交开销，但没有消除 FPGA 页准备与页发送之间的空隙。保持对外描述符格式，也能在后续 WP 内评估内部页双缓冲。

### 6.4 ARM CPU 拷贝独立存在

`cam2.c:206–215`：

```c
if (s->cached_buffer) {
    copy_pixels(s->cached_buffer, buffer, s->bytes);
    pixels = s->cached_buffer;
}
uint64_t copied = monotonic_us();
// 随后按原语义计算整帧 checksum，验证通过才发布
```

不能删除校验或直接修改 DMA 映射缓存属性来凑 fps；若后续尝试 zero-copy，要先核对内核分配 / cache coherency / 显示接口。

## 7. 假设判定与工作包调整建议

| 假设 | 当前判定 | 后续需要的证据 |
|---|---|---|
| H1 多余全帧读回 | 部分成立：本地输出确实要读给 PCIe；ARM 又有 cached copy。但两段含必要传输，不能全删 | DMA阶段周期、页缓冲读量、ARM copy/校验/显示耗时；评估直写能否保持接口及完成语义 |
| H2 并发为1 | warp侧已不成立；输出 host_reader 成立 | 板上 max_warp / max_host / max_total 与读等待占比；仿真已达到16不等于板测稳态≥8 |
| H3 表逐像素随机8B读 | 不成立：已tile顺序128-beat逻辑预取，原生突发最多16beat | map平均原生突发、总表量和warp返回等待；若需表相关全部stall，再细分loader阶段；不把逻辑128beat冒充原生128beat |
| H4 全表可缩成纯径向 | 当前不能直接替换：非零p1/p2及仿射均需保留 | 固定位宽/取整保持；对标定和边界样本逐像素比较；近似必须单独开关 |
| H5 无四抽头片上缓存 | 不成立：四bank / 双缓冲tile已存在 | source实际字节 /输出像素、tile间重复率、render等待及边界；命中率口径须明确定义 |
| 新增定位：tile计算 / 写回串行 | 成立：`warp_tiles.v:218–232` 先R_SCAN、R_DRAIN，后R_AW/R_W，写完才开始下一tile | PRF0 last_warp_cycles；后续若要60fps，须重叠计算与写回或提高处理并行度，不能只增加AR并发 |

当前输出 AW 只有4 beat、页读单在途、页级串行、ARM拷贝及GUI成本，都是应优先测量的方向。不得只盯坐标计算器。

建议后续工作包先按当前瓶颈重新确认：**renderer计算/写回重叠 → 源图预取粒度/相邻tile复用 → 必要时减少坐标流量 → PCIe页流水与ARM显示**。这与原WP1–WP5的顺序不同，故本阶段只给建议，不自动改变已约定的数据通路。若减少坐标流量，优先评估保留逐级舍入的精确流水或无损差分；不能默认用径向近似满足最大1LSB。

**当前renderer还有结构性吞吐下界（代码推算，非板测）：**1080p共有8100个32×8 tile；每tile的256拍R_SCAN之后，还必须完成32个128-bit输出beat，且二者不重叠。即使忽略全部读延迟、drain、地址握手与bank切换，至少 `(256+32)×8100/131250000 ≈ 17.77 ms/帧`，约56.3fps。因此当前调度仅靠增加DDR outstanding，不能达到≤17ms，更不能达到60fps所需≤16.67ms。后续需要将tile计算/输出写回重叠；本阶段不改状态机。

60 fps 预算（理论估算，非板测）：1080p60=124.416 Mpixel/s，131.25 MHz单像素流水需约94.8%有效利用率。保留8B/px表，假设源图每帧仅读一次，采集写+表读+源读+结果写+结果读=**33,177,600 B/帧，约1.991 GB/s**，已接近当前2.1 GB/s峰值；重复源矩形和控制损耗会继续增加。原历史基线的延迟瓶颈成立，不代表目标60fps时仍不受带宽限制。

因此 WP2 的“原生平均≥128beat”和 WP3 的“≥3GB/s”不适用于当前接口。要改为当前IP可实现的指标，或单独批准DDR/IP变更；本阶段不改IP。仅重叠31ms和21ms也不足60fps，21ms输出段本身需缩短。

同样，WP4提出的“坐标误差<0.5px”不能自动推出“像素误差≤1LSB”：高对比边缘可能放大采样位置差异。不能以坐标误差或文献fps替代本工程逐像素验收。

## 8. 新增只读 PRF0 计数器

实现：`source/rtl/warp_perf.v`（独立输入寄存 / always，被动观察客户端握手）、`warp_perf_regs.v`（跨域快照）、顶层 `PERF_ENABLE` 开关。**没有监测信号反馈到任何 ready、地址、像素或控制状态。**

BAR0 `0x200–0x2AF` 原来未定义，新增只读；BAR1同地址的原有参数写路径不变。旧CAM/WRP/DMA寄存器、版本、门铃、footer均不变。`PERF_ENABLE=0` 完全裁掉计数器，新增区返回0；算法路径仍与诊断前相同。

### 8.1 读取格式 / 同步

| BAR0地址 | 字段 |
|---|---|
| `0x200` | magic=`0x50524630`（PRF0） |
| `0x204` | 诊断ABI版本1 |
| `0x208` | snapshot_sequence |
| `0x20C` | DDR用户时钟 Hz，当前131250000 |
| `0x210 + 4*i` | 下表 word i，0≤i<40 |

32个DDR计数器同拍进入 held bundle，request/ack经双寄存器同步，复用 `frame_mailbox`；不对多位二进制计数器逐位打两拍。ARM域收到快照后同时锁存8个host计数器，再发布整个视图。读取前后检查sequence相同，否则重读。

默认 `PERF_SNAPSHOT_BITS=20`，约7.99 ms更新一次；参数集中在顶层，`warp_perf_regs.SNAPSHOT_BITS`为对应等价配置。所有累计32-bit计数器自然回绕，软件按模2^32差分，建议1s采样，最大10s；每次 reset 后重新建立基线。DDR cycle 单次回绕约32.7s，不能拿两次相隔10k帧的读数直接相减。

### 8.2 计数器清单

| word | 名称 / 含义 | 单位 |
|---:|---|---|
| 0 | DDR elapsed | cycle @131.25MHz |
| 1 / 2 / 3 / 4 | capture C_WRITE / LUT P_BUILD / warp P_RUN / host非H_IDLE 累计周期 | cycle；阶段可重叠，不能直接相加成帧周期 |
| 5 | 有raw队列但无空闲output槽，处理未启动 | stall cycle |
| 6 / 7 / 8 | 已返回的map / source / host读取 | 128-bit beat；×16为实际返回字节 |
| 9 / 10 / 11 | capture / LUT / output实际写入握手 | 128-bit beat；当前全字节有效，含采集异常padding |
| 12 / 13 / 14 | map / source / host已接收AR数量 | burst |
| 15 / 16 / 17 | 上述AR声明的beat总数 | beat；与12/13/14差分相除求实际平均突发 |
| 18 / 19 | warp / host AR有效但未被接受 | stall cycle（含仲裁与下游背压） |
| 20 / 21 | warp / host有在途但该拍无返回 | wait cycle；不等同纯DRAM器件延迟 |
| 22 / 23 / 24 | reset以来warp / host / 合计最大在途数 | burst；已握手AR减已接收RLAST |
| 25 / 26 / 27 | 采集成功 / warp发布 / 输出被消费的帧数 | frame |
| 28 | 最近完成warp的P_RUN周期 | cycle，不含采集及建表 |
| 29 | 处理空闲且raw队列为空 | cycle；用于区分输入不足和输出槽阻塞，不代表纯warp计算延迟 |
| 30 | 已申请采集但异常丢弃的帧数 | frame；不含没有申请槽时所有跳过的HDMI帧 |
| 31 | sticky error flags | 低8bit=现有error_code；bit8/9=warp/host无请求返回；bit10=观察到在途超过16 |
| 32 | host elapsed | pclk_div2 cycle，频率由与DDR计数差分的比值推算 |
| 33 | frame_dma busy累计 | pclk_div2 cycle |
| 34 | busy下降沿计数 | DMA结束事件；错误请求也可能结束，需结合现有DMA状态判断成功 |
| 35 | 最近一次frame_dma busy周期 | pclk_div2 cycle；与ARM软件计时边界不同 |
| 36 | source_read次数 | 页缓冲128-bit读请求；×16为页缓冲读取量，**不直接等于已接受TLP有效载荷** |
| 37 | TX VALID且非READY | pclk_div2 cycle |
| 38 | 现有page_completed快照 | page |
| 39 | 没有frame_ready且DMA空闲 | pclk_div2 cycle；可含源等待/建表/启动空档 |

观测采用一拍输入tap；累计事件计数不会增加原路径延迟。max_outstanding是生命周期峰值，不能用一次峰值宣称“稳态始终≥8”；将来WP3如需占空比，另补直方图。未增加cache hit率伪计数：当前tile模型中四抽头驻留是设计约束，跨tile重复DDR读量需要用source流量分析。

### 8.3 工具与验证

ARM新增 `tools/warp_perf.py`：以只读方式映射BAR0，只读取PRF0，不写门铃、不修复BAR、不申请DMA。输出JSONL含原始差分、MB/s、平均突发、最近warp/DMA周期和错误位。

仿真 `tb_warp_perf.sv` 验证16在途、map/source有序归属、即时RLAST、阶段计数、CDC快照、旧bank返回、错误标记和reset。完整PCIe回归分别打开/关闭PERF_ENABLE，使用相同像素golden、footer和随机停顿条件。

## 9. 验证结果、资源与时序

基线报告已保存至 `FPGA_AADCS/HDMI_Warp/checks/2026-10-27-phase0/baseline.rtr`、`baseline.prr`，避免原构建被覆盖。下表必须按完成证据更新，禁止把预期写成通过。

| 项目 | 诊断前基线 | Phase 0 |
|---|---:|---|
| RTL数据通路 | 当前CAM3/tile预取实现 | 不变；仅新增观察tap与BAR0诊断区 |
| 全设计setup WNS（slow） | +0.356 ns | v2 +0.358 ns，差+0.002 ns |
| DDR同域 setup WNS（slow） | +0.356 ns | v2 +0.358 ns |
| PCIe125同域 setup WNS（slow） | +0.394 ns | v2 +0.664 ns，差+0.270 ns |
| HDMI同域 setup WNS（slow） | +0.658 ns | v2 +0.622 ns，差−0.036 ns |
| LUT合计 | 13,631 | v2 15,413（+1,782） |
| FF合计 | 14,194 | v2 18,570（+4,376） |
| DRM / APM | 80.5 /30 | 80.5 /30，不变 |
| PRF0单元仿真 | 无 | PASS，含修正后DMA忙8周期/完成1次/持续8周期检查 |
| ARM只读解码/回绕/撕裂快照测试 | 无 | 4项PASS |
| 完整PCIe像素回归，计数器开/关 | 既有golden | 两者均29,696像素精确比较PASS；关闭路径PDS compile PASS |
| PRF0板测 | 无 | v2 DONE=1/CRC无错；原标定1800帧、12秒无GUI和8秒GUI采样；16/1/16峰值及DMA20.659–20.905ms均已验证 |
| 1080p60 / 10k帧 / PSNR全帧 | 未验收 | Phase 0不声明达标 |

时序门槛：所有约束通过，全设计最差setup WNS相对诊断前基线恶化≤0.2ns，并列出关键clock对变化。此次使用保存的诊断前已验证报告作基线；PERF_ENABLE=0路径另做像素仿真与编译检查，不冒充已另跑关闭计数器的布局布线。独立always只是减少耦合，**不是不影响布局/时序的证明**。若不满足，保留旧位流，不上板替换；只调整观测逻辑或关闭计数器。

v1位流SHA256：`469ff26c51556def28fe2d43f185e7b9f16b93bcc9f8480d683fcb4835ce988f`，在 `build/perf-phase0/generate_bitstream/hdmi_warp_top.sbit`。**v2位流**SHA256：`8ee33e2e70e8dec01ad8d78e88cc866c88ce564628b2d4745f011d8dd54fac76`，在 `build/perf-phase0-v2/generate_bitstream/hdmi_warp_top.sbit`；资源与时序表以v2为准。本阶段没有使用Debug Core抓波，数据来自BAR0只读计数器/既有状态与离线仿真。

**板测过程：**v1首次配置后HDMI几何为0/异常值，重新插拔后仍不稳定；回灌基准位流恢复1920×1080/30Hz、900帧平均30.0fps。随后**同一个v1诊断位流**重试也恢复900帧平均30.0fps，首次异常未重复，不能归因为计数器逻辑，也不能宣称已修复HDMI重初始化根因。基准回灌日志下载到100%且DONE=1，但随后JTAG状态读失败；实际ARM数据流证明配置已生效。v1第二次JTAG完整DONE/CRC检查通过。

原标定文件SHA256=`982882c4f23bd89c6b2642d6ad95f56b4baeb094592d7c9c7d685962b241779f`；17字原样恢复、逐字读回一致，accepted=applied=published=1。未改输入EDID/分辨率/帧率，未改插值或坐标参数。v2初次下载被`CableList is empty`阻止；随后用VirtualHere官方客户端接口只重新接入FTDI，恢复正常D2XX枚举，**v2现已成功下载并运行，DONE=1、CRC无错误**。

**最终状态：**1920×1080输入约30Hz，原标定generation=1，ARM GUI保持实时显示（视频帧仍为1080p，预览窗口1280×720 fit）。`v2-final-status.json`保存17字读回；`v2-headless.jsonl`/`v2-gui.jsonl`保存原始快照差分，`board-summary-v2-*.json`为加权汇总。Phase0诊断与观测验证完成；60fps、全1080p画质指标和10k帧验收尚未完成，不在本阶段宣称通过。

## 10. 待确认问题（进入WP前）

1. **60fps端点**：要求FPGA输出到ARM DDR，还是ARM屏幕每秒60个不同源帧也必须同时达标？本报告建议分别验收接收与显示，最终按你的端到端目标验收。
2. **输入**：当前默认EDID限定30Hz，信号源当前1080p30。后续是否允许增加1080p60模式并调整EDID？这属于之后WP，Phase 0不改。
3. **DDR约束**：当前确认为x16/1050MT/s/128-bit/16-beat原生接口。后续以这个硬件为边界重写≥3GB/s、≥128beat等指标，还是允许另立DDR/IP升级工作包？不再重复询问已知板卡型号。
4. **画质基准**：“≤1 LSB”按RGB565每通道量化级，还是转换后的8-bit RGB逐通道误差？建议纯调度改动要求bit-exact（误差0），任何压表近似另开参数并单独审核。
5. **映射集合**：需保证的k1/k2/k3/p1/p2、仿射角度/scale范围及越界黑边规则，以现有实际标定+现有参数合法范围为基准是否足够？不能因部分场景径向对称就丢弃切向或仿射。
6. **参考版本 / 长跑**：以哪个已验证位流+参数作为A/B黄金参考？10k帧测试需稳定信号源、源帧序号和逐帧错误统计；参数/分辨率切换时的启动建表跳帧是否单独计入验收？

已知而无需你重新提供：PG2L100H、HDMIK V1.1、非HLS、当前BRAM/DRM使用、现有标定文件、SSH方式。ARM驱动的CMA/cache属性、PCIe实际协商速率、DDR具体颗粒/控制器在途能力，优先继续从现有代码/板上只读状态查证，不凭建议文档猜。

**Phase 0完成后停在诊断与观测层。WP1–WP5、EDID60Hz、坐标表压缩和DMA重构，等待用户确认后逐包实施、独立提交；本阶段不自动push。**
