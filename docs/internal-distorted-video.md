# FPGA 内部畸变视频源

本地 zyxw-gpt 分支的当前默认功能：在 FPGA 内生成连续的畸变图像，作为虚拟摄像头输入，
经过原摄像头接收器、外部 DDR 和 PCIe DMA，最终由主机接收到 RK3568 DDR。
不需要连接 OV5640，也不等待 SCCB 应答。FPGA 仍是 PG2L100H-6IFBG484。

## 工程和来源

唯一入口为 `FPGA_AADCS/Distortion_video/board_video.pds`，顶层 `boardtop`。
`boardtop.INTERNAL_CAMERA=1` 为默认内部源；设置为 0 后重新构建可恢复真实 OV5640 通路。
两种配置共用同一个源工程，不额外创建 PDS。当前交付目录只保存默认内部源位流。

图像直接复用旧工程 `E:/Downloads/Distortion/Distortion/prj/Distortion_video/source/rtl/chart.v`。
本仓库已有相同文件，核对 SHA-256 为
`674c071107c2bad5bd18b3481140cfb4e008d8b57fa1056cd3d20befaae9920f`，本次不改动图像模型。
该模块以固定点流水线生成模拟镜头畸变：弯曲白色网格、红色中心线、绿色矩形和彩色背景。
它是人工测试图案，不能代替真实相机标定。

新增 `synthetic_camera.v` 负责连续光栅、帧/行同步和 DVP 字节发送。
左下角额外显示八个 8×8 的色块，按低位在左编码帧号低 8 位：黄色=1，蓝色=0；
每 256 个源帧循环，用于观察源视频是否继续运行。其余像素与旧图像模型一致。

## 通路和时序

```text
25 MHz 板内时钟 → chart 畸变图像 → RGB565 DVP 虚拟摄像头
                                         ↓
原 camera_stream 接收器 → 异步 FIFO → FPGA DDR 完整帧写入/读回校验
                                         ↓
4 KiB 页缓存 → 厂商 PCIe DMA → RK3568 DDR
```

- 有效图像：640×400，RGB565 小端，每帧 512,000 字节。
- 每像素两个 PCLK，先低字节再高字节，HREF 高期间连续发送。
- 总时序：每行 800 像素周期、每帧 520 行；25 MHz 下每帧 832,000 时钟，约 30.048 fps。
- VSYNC 高有效，位于帧消隐区；不会与 HREF 重叠。
- 连续源不受 ARM/DMA 请求或采集器复位的反压控制；KEY0 全局复位会重新开始视频。
- 继续使用原单帧快照缓冲：主机读取期间 DDR 内的完整帧保持不变，读完才采下一完整源帧。
  等待期间经过的源帧被跳过；源的约 30 fps 不等于 ARM 每秒收到 30 帧。

当前发送的是**畸变原图**。此板级通路尚未接入畸变/任意角度矫正处理，
之前保留的算法模块仍可用于下一阶段。本次不将已生成畸变图像写成已完成矫正。

默认内部源模式下，外部 PCLK/HREF/VSYNC/DATA 不参与采集，SCL/SDA 为高阻，
PWDN 保持低，EX_RST 保持低。无需摄像头、额外跳线或额外时钟。
物理摄像头配置的接线和电气约定见 [OV5640 文档](ov5640-camera.md)。

## ARM 兼容与状态

保留 CAM2 magic `0x43414d32`、版本 `0x00020000` 和全部 DMA 描述符约定。
2026-10-23 联调已在 `F:/git_clone/RK3568-PCIE` 加入 CAM2 接收/显示，并安装到板卡 `/userdata/fpga-view`。已验证的实时显示命令：

```sh
sh /userdata/fpga-view/run.sh --mode cam2 --fit
```

当前已启动一个显示实例，重复启动采集会被设备锁拒绝。此前的命令行保存程序仍保留：

```sh
chmod +x ./ov5640-capture
sudo ./ov5640-capture --frames 1 --output frame.rgb565 --ppm frame.ppm
sudo ./ov5640-capture --frames 30
```

设备 BDF、驱动、coherent mmap 和 32 位 DMA 地址等要求与上一版相同。
旧的 `fpga-view` / `fpga-probe --mode line` 不兼容 CAM2，不应拿旧 line 程序判断本版输出。
这个接收程序保存图像，不启动显示窗口。

BAR0 原寄存器含义保留，0x08 flags 新增 bit5=内部畸变源。
bit3 在内部模式表示源就绪；0x30 的 camera_id=0、初始化错误/索引=0，
不伪造 0x5640 硬件 ID。物理模式下 bit5=0，ID 和初始化状态来自真实摄像头。
0x20/0x24 是已发布/尝试丢弃的采集帧数，不是内部光栅源的所有帧计数。

## 构建、下载和验证

```powershell
./FPGA_AADCS/Distortion_video/build.ps1
python FPGA_AADCS/Distortion_video/sim/regress.py --bin 'F:/AADCS_git/.cache/tools/iverilog/bin'
```

批处理先清除临时 PDS 中的 GUI 执行状态，再把全部构建输出留在 `build/` 内，
避免源 PDS 中残留 GUI 输出路径导致批处理复用外面的旧结果。
位流统一交付在 `firmware/fpga/distortion-video/unified/boardtop.sbit`。
下载方式沿用 `scripts/program_fpga.tcl`（1 MHz、WakeDownReconfigure、仅 SRAM）；
遇到 DONE 未拉高时按此前实测步骤使用 F_RESET 后重试。

2026-10-23 当前交付为带三组 DebugCore 的实机验证版本，复现构建使用 `build.ps1 -Debug`。已修复 PLL 启动与 fetch RAM 推断问题，连续四帧共 1,024,000 像素与参考图像完全一致；ARM 实时显示约 10～11 fps。完整日志、当前位流哈希与截图见 [联调记录](verification/2026-10-23-joint/notes.md)。下面的 2026-10-22 结果是历史记录，其旧位流哈希不再代表当前交付文件。

验证覆盖实际 640×400 DVP 输出对旧黄金图像的逐字节比较、连续帧节拍和中途复位；
以及虚拟摄像头→原接收器→DDR 模型→实际厂商 DMA RX/TX 的端到端像素比较、
主机停顿期间持续产帧及 DDR 快照保持、随机 PCIe 反压。
新位流的构建/仿真证据保存于 `docs/verification/2026-10-22-internal-video/`。
上一版 2026-10-21 的 JTAG 成功日志对应真实摄像头版本。本内部视频源位流于
2026-10-22 完成 SRAM 下载验证，记录见下文；实际 ARM 图像接收仍待联调。

最终离线验证：52 项 RTL 测试通过；PDS 完整构建和位流生成成功，时序报告 All Constraints Met。
[RTL 实际输出预览](verification/2026-10-22-internal-video/synthetic_640x400.png)。

### 2026-10-22 JTAG 下载结果

本内部视频源位流 SHA-256 为
`293047d5b075f114f67656670a3ca306b1b411c4869c837f91047913f457052c`。
仅按 F_RESET 后仍报 DONE 未拉高；降到 500 kHz 也未解决，ISC 组合尝试超时后停止。
整板断电重上电并重启 JTAG Server、刷新下载器枚举后，以 **1 MHz、WakeDownReconfigure**
下载同一份位流成功，耗时 34.5 秒，未修改 RTL 或位流，未写入 Flash/eFuse。

日志确认 `Program execute successfully`，状态寄存器为 `0x0817fca0`，
`done=1`、`done_i=1`、`wakeup_over=1`，CRC/ID/认证/超时错误均为 0。
这确认配置成功；不能据此认定 DDR、PCIe 或 ARM 图像显示已验证。
本次操作同时改变了整板上电状态和 JTAG 服务状态，尚不能将根因唯一归于其中一项。

[完整成功日志](verification/2026-10-22-internal-video/jtag-program-after-power-cycle.txt)。
