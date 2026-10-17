# RK3568 主机侧接收验证结果

**收件方**：FPGA 侧（`fpga-arbitrary-angle-distortion-correction`）
**日期**：2026-10-17
**被测分支**：`zyxw`（`50725bd`，`aadcs_pcie_top` / PG2L100H-6IFBG484）
**被测位流**：`firmware/fpga/pcie-test/aadcs_pcie_top.sbit`
**上位机程序**：本仓库的 `fpga-view` / `fpga-probe`（`7d36a01`）

> 本文档建议放到 FPGA 仓库的 `docs/changes/005-rk3568-host-verification.md`，
> 与 002/003/004 编号衔接。

---

## 1. 结论

| 环节 | 结果 | 证据 |
| --- | --- | --- |
| PCIe 链路 | ✅ 通 | `PCIe Gen.1 x2 link up`，端点 `0755:0755` |
| BAR1 描述符写 | ✅ 生效 | 写描述符后 DMA 缓冲被覆盖（§2.1） |
| FPGA → 主机内存 DMA | ✅ 在写 | 同上；主机侧缓冲读写自检 2560/2560 通过 |
| **载荷内容** | ❌ **不符合任何已实现的测试模式** | §2.2–§2.4 |
| 主机侧显示链路 | ✅ 正常 | 31 fps 渲染，`--test-pattern` 像素级验证通过 |

**一句话**：控制器、描述符接口和 DMA 写入通路都已经打通，
**问题在数据源没有送出应有内容**。FPGA 每次写入的都是一模一样的 16 字节，
且整帧 512000 字节中 75.5% 根本没有被写过。

---

## 2. 关键证据

### 2.1 主机侧自检：DMA 缓冲读写正常

本仓库新增的工具 `tools/diag/dmawrite_test.c` 先把缓冲整片写成 `0x5a5a5a5a`，
再按 `fpga_capture.c` 完全相同的寄存器顺序和节拍发描述符，最后数残留标记：

```
DMA buffer: bus 0x7e8c8000, 10240 bytes
host wrote 0x5a5a5a5a everywhere; markers found: 2560/2560     ← 主机读写正常
issuing 8 descriptors of 1280 bytes (cmd=0x0100013f)
after the descriptors: markers found: 640/2560  ->  the FPGA DID write
```

2560 个标记全部可读写，说明映射、缓存一致性和主机侧代码没问题；
发完描述符后只剩 640 个，**证明 FPGA 确实收到了描述符并写入了主机内存**。

> 这一步很关键：它能区分"描述符没送达"和"FPGA 写错了字节"。
> 采集侧的任何一个统计量都区分不了这两者——两种情况看起来都是"一帧莫名其妙的数据"。

### 2.2 整帧内容：只有两种 16 字节块

用 `peek -B 1 mwr 400 1280` 抓完整一帧（512000 字节 = 400 行 × 1280 字节）后统计：

| 16 字节块 | 出现次数 | 占比 | 含义 |
| --- | --- | --- | --- |
| `aa aa aa aa aa aa aa aa aa aa aa aa aa aa aa aa` | 24160 | 75.5% | 内核 DMA 缓冲的初始填充值，**从没被写过** |
| `fa 36 32 6b 2e d0 08 2a ff fb 77 ae 01 10 02 d0` | 7840 | 24.5% | FPGA 写入的恒定值 |

整帧只有这两种块，**没有任何位置出现过别的数据**。

恒定值的四种读法：

| 表示 | 值 |
| --- | --- |
| 线上字节（小端顺序） | `fa 36 32 6b 2e d0 08 2a ff fb 77 ae 01 10 02 d0` |
| 4 × 32-bit 小端字 | `6B3236FA` `2A08D02E` `AE77FBFF` `D0021001` |
| 8 × 16-bit lane（`read_data[i*16 +: 16]`） | `36FA` `6B32` `D02E` `2A08` `FBFF` `AE77` `1001` `D002` |
| 主机按 `--swap` 解码后的像素 | `FA36` `326B` `2ED0` `082A` `FFFB` `77AE` `0110` `02D0` |

全帧**只有 9 个不同的像素值**（上面 8 个 + `0xAAAA`，即 `0xAA` 填充）。

### 2.3 与彩条模式逐条比对：0/256000

`pcie_test_source.v` 的 `test_pixel()` 对彩条区的输出被限制为 8 个常量：

```
0xffff 0xffe0 0x07ff 0x07e0 0xf81f 0xf800 0x001f 0x0000
```

把线上 lane 用 `swap16()` 还原成 RTL 里的 `pixel` 后逐个比对：

```
总像素 256000
不同 pixel 值: 9
命中彩条 8 色常量: 0/256000
全 0 像素: 0/256000
```

**一个都没命中。**

> ⚠️ 还原这一步不能省。RTL 发的是 `{pixel[7:0], pixel[15:8]}`，
> 直接拿线上 lane 和上面的常量比会得出错误的结论
> （两者只有 `0xffff`、`0x0000` 这类回文值恰好相同）。
> 我们第一次就是这么比错的，已修正。

渐变区（`py >= HEIGHT*3/4`）的约束是 `{px[4:0], px[5:0], px[4:0]}`，
即 **R 与 B 必须相等**（都是 `px[4:0]`）。实测的 8 个值：
`FA36`(R=31,B=22)、`326B`、`2ED0`、`082A`、`FFFB`(R=31,B=27)、`77AE`、`0110`、`02D0`
**没有一个满足 R == B**。

### 2.4 与计数模式比对：四个字不连续

计数模式输出 `{ramp_word+3, ramp_word+2, ramp_word+1, ramp_word}`，
所以一个 128-bit 字拆成的 4 个 32-bit 字**必须连续**（差值为 1,1,1）：

```
前 4 个 32-bit 字: 6b3236fa 2a08d02e ae77fbff d0021001
相邻差: -1093232332, 2221878225, 562697218      （计数模式应为 1, 1, 1）
```

**不连续，不是计数模式。**

### 2.5 时间线：数据曾经是变化的

链路刚恢复后**第一次**运行 `fpga-probe` 时：

```
frame 0:  21.15 ms  nonzero 425464/512000  distinct 2911  head fb7fef7f  signal=yes
frame 1:  21.25 ms  nonzero 424836/512000  distinct 2905  head 89212420  signal=yes
frame 2:  21.27 ms  nonzero 425057/512000  distinct 2956  head 11f51ecd  signal=yes
frame 3:  21.14 ms  nonzero 425774/512000  distinct 2981  head c4c0a200  signal=yes
```

`distinct` 在 2900 上下且**每帧帧头都在变**——那时数据是**在推进的**。
约 10 秒后就冻结成 §2.2 的恒定值，连续三次采样逐字节相同。

**这条线索很重要**：设计曾经输出过变化的数据，然后停住了。
比起"位流烧错了"，这更像**复位 / 初始化 / 背压**相关的问题。

（另外注意：即使在"变化"的那几帧里也**没有找到 `0x3568CAFE` 帧头**，
`hdr_line=-1`，所以那时也还不是正确的彩条帧。）

---

## 3. 判据推导

两条硬约束都是从 RTL 直接推出来的，列在这里便于交叉核对：

```verilog
// pcie_test_source.v:20-37
if (py >= HEIGHT * 3 / 4)          test_pixel = {px[4:0], px[5:0], px[4:0]};  // R == B
else if (px < WIDTH * 1 / 8)       test_pixel = 16'hffff;
else if (px < WIDTH * 2 / 8)       test_pixel = 16'hffe0;
else if (px < WIDTH * 3 / 8)       test_pixel = 16'h07ff;
else if (px < WIDTH * 4 / 8)       test_pixel = 16'h07e0;
else if (px < WIDTH * 5 / 8)       test_pixel = 16'hf81f;
else if (px < WIDTH * 6 / 8)       test_pixel = 16'hf800;
else if (px < WIDTH * 7 / 8)       test_pixel = 16'h001f;
else                               test_pixel = 16'h0000;

// pcie_test_source.v:46-49（计数模式）
read_data <= {ramp_word + 32'd3, ramp_word + 32'd2,
              ramp_word + 32'd1, ramp_word};
```

另外，**彩条区的值只在 `y` 方向分段、与 `x` 无关**（每 1/8 宽度是一个常量），
所以正确帧里同一行的相邻像素会成段重复（每段 40 个 32-bit 字）。
实测数据里完全没有游程，而是 16 字节周期的高频重复。

---

## 4. 建议排查顺序

按"最可能且最容易验证"排序：

1. **确认板上跑的确实是本仓库这份 RTL 编出的位流。**
   重新下载 `firmware/fpga/pcie-test/aadcs_pcie_top.sbit`
   （SHA-256 `b8081230e2f1f4b6c3a4885016f0a13667b36bc8a357bf9da12dd86605ef3b14`），
   下载后**必须按 F_RESET**（见 §5）。
   实测载荷和这份 RTL 的任何一种模式都对不上，当前这个位流本身就值得怀疑。

2. **看 `read_enable`（顶层连到 `o_dma_write_data_req`）有没有真的在翻转。**
   源只在 `read_enable` 有效时推进（`pcie_test_source.v:45`）。
   如果它停了，`read_data` 会保持最后的值——但那个冻结值应该是**合法像素**
   （§3 的 8 个常量之一，或满足 R==B 的渐变值），而实测是 `FA36` 这种非法组合。
   **所以更可能是 `read_data` 从来没有被正确加载过**，而不是"加载后停住"。

3. **确认 `source_reset_n` 真的产生过复位脉冲。**
   它的释放条件是 `ramp_previous == ramp_mode`（`aadcs_pcie_top.v:68`），
   依赖 `key_pipe` / `ramp_previous` 的复位初值配合。
   建议在仿真里打印 `core_rst_n`、`dma_reset_n`、`source_reset_n`、`ramp_mode`、
   `ramp_previous` 的上电波形确认。

4. **观察 LED4（M17，`activity_led`）。** 它由 `source_read` 计数分频驱动，
   能直观反映读活动有没有发生（注意原文说明：短传输时不一定可见闪烁）。

5. **检查 `read_data` 的 8 个 16-bit slice 的加载路径。**
   `pcie_test_source.v:55-61` 在 for 循环里对 `read_data` 做分段非阻塞赋值，
   循环体内同时用阻塞赋值写模块级 `pixel`。仿真语义下 RHS 是立即求值的、
   每段拿到各自的值；但这类写法在综合/时序上值得再看一眼，
   尤其确认它与 Icarus 仿真的结果真的一致。

---

## 5. 按键行为更正（重要）

`FPGA_AADCS/README.md` 写的是「KEY0（M15）：低电平复位 PCIe IP」。
**实测按 KEY0 不起作用**，链路仍然是 `LTSSM is 0x0`：

```
按 KEY0    -> rk-pcie: PCIe Link Fail, LTSSM is 0x0, hw_retries=0
按 F_RESET -> rk-pcie: PCIe Gen.1 x2 link up
```

实测有效的是 **F_RESET**（板级 FPGA 重配置按键）。

根因在 RTL 里能直接读出来（`aadcs_pcie_top.v:87-89`）：

```verilog
.button_rst_n   (key0_n),
.power_up_rst_n (1'b1),     // 恒为 1，没有上电复位脉冲
.perst_n        (1'b1),     // 恒为 1，主机 PERST# 没有接进 IP
```

PCIe 硬核**没有任何自主复位来源**，唯一的外部复位是 KEY0；
而 JTAG 重新配置之后 IP 不会被重新初始化，于是链路死掉。
目前只能靠 F_RESET（或整板断电重上电）恢复。

**这本身是一个设计问题，建议后续处理**：

- 作为 PCIe 端点，`perst_n` 应接主机/插槽的 PERST#；
- `power_up_rst_n` 应有配置完成后的复位脉冲，而不是钉死为 1；
- 现状下**任何一次位流更新都会让链路死掉、必须人工按键**，
  远程 / 现场升级不可能。

---

## 6. 未验证 / 边界

- 本次没有读到 FPGA 内部的任何信号，所有结论都是从**主机侧可见的字节**反推的。
- §2.5 那条"数据曾经在变"只观察到一个很短的时间窗，没有连续记录，不能排除偶发。
- 没有验证计数模式（需要在主机停止采集的情况下按住 KEY1）。
  所以严格来说只证明了**当前这一份载荷不属于计数模式**，
  而不是"计数模式实现有问题"。
- 没有做长时间稳定性测试；没有测 60 fps 或大分辨率下的持续带宽。
- 主机每帧 ~21 ms（640×400），受参考节拍等待限制，不代表链路上限。

---

## 7. 附录

### A. 复现步骤

主机侧程序在本仓库，板卡地址 `10.42.0.162`。

```bash
# 链路（每次 FPGA 重新配置后都要做一次）
ssh root@10.42.0.162 'echo 3c0800000.pcie > /sys/bus/platform/drivers/rk-pcie/bind'
ssh root@10.42.0.162 'lspci -nn'      # 期望看到 0002:21:00.0 [0755:0755]

# 接收程序（会自行打开 Memory Space / Bus Master）
make deploy
make probe
ssh root@10.42.0.162 '/userdata/fpga-view/fpga-probe --mode line --size 640x400 -n 4'

# 判定"FPGA 到底写没写"的实验
LD_LIBRARY_PATH=$PWD/toolchain/usr/lib/x86_64-linux-gnu \
  ./toolchain/usr/bin/aarch64-linux-gnu-gcc-11 --sysroot=$PWD/sysroot \
  -march=armv8.2-a -O2 -D_GNU_SOURCE tools/diag/dmawrite_test.c -o .cache/dmawrite_test
python3 tools/brd.py -p .cache/dmawrite_test /tmp/fpv/
python3 tools/brd.py '/tmp/fpv/dmawrite_test'

# 抓完整原始帧（绕开接收程序的任何转换）
python3 tools/brd.py '/tmp/fpv/peek -B 1 mwr 400 1280 /tmp/fpv/full.bin'
```

### B. 本次测量到的恒定载荷（原始字节）

```
offset 0x00: fa 36 32 6b 2e d0 08 2a ff fb 77 ae 01 10 02 d0
offset 0x10: fa 36 32 6b 2e d0 08 2a ff fb 77 ae 01 10 02 d0
offset 0x20: fa 36 32 6b 2e d0 08 2a ff fb 77 ae 01 10 02 d0
offset 0x30: fa 36 32 6b 2e d0 08 2a ff fb 77 ae 01 10 02 d0
...
```

行与行之间也完全相同；偏移 1280（第 1 行）处的字节和上面一模一样。

### C. 主机侧接口约定（已与实现核对一致）

| 项 | 值 |
| --- | --- |
| BAR | `resource1`，偏移 `0x100` / `0x110` / `0x120` |
| 写入顺序 | 先 `0x110`（低地址），再 `0x120`（高地址），最后 `0x100`（命令） |
| 命令字 | `((dwords-1) & 0x3FF) \| (1<<24)`；1280 字节 → `0x0100013F` |
| 主机缓冲 | `/dev/pcie_dma_memcpy` 的 `DMA_CMD_SETUP`，返回页对齐总线地址 |
| 期望格式 | 640×400 RGB565，1280 B/行，像素字节交换，帧首 16 字节 `0xD5000001…0x3568CAFE` 状态头 |

主机侧已实现且实测可用：打开 Memory Space / Bus Master、BAR 映射、
DMA 缓冲分配与页对齐校验、4 KiB 页边界拆分、按节拍串行发描述符、帧头搜索与旋转对齐。

**接口本身不需要改**——只要数据源送出正确内容，
`--mode line --size 640x400 --swap` 就能直接出图。
