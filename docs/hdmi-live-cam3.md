# HDMI 连续视频 CAM3

目标最高 1920×1080 @30，电脑控制有源分辨率和刷新率，FPGA 矫正后等尺寸 DMA 到 RK3568 DDR。是否达到 30 fps 以板上实测为准。

FPGA 入口 `FPGA_AADCS/HDMI_Warp/hdmi_warp.pds`，分支 `zyxw-gpt`。
ARM 使用独立 RK3568-PCIE 仓库 main 的 CAM2/CAM3 兼容源码，DMA 内核驱动不变。
旧交付目录的 CAM2 位流不等于当前源码构建结果。

原始帧池为 0/4/8 MiB，矫正帧池为 16/20/24 MiB，每槽 4 MiB。
1080p RGB565 为 4,147,200 字节。32 MiB 起存 tile-order XY 映射表（8 字节/输出像素）。
连续采集、双缓冲 32×8 分块插值和整帧 DMA 并行。尺寸或参数代数变化时重建映射表。

## 协议

BAR0 magic 仍为 0x43414D32，version 为 0x00030000。0x10/14/18/1C 为队首帧宽、高、stride、payload bytes；0x20 帧 ID，0x2C 校验值，0x90 参数代数。

| 地址 | 含义 |
|---|---|
| BAR1 0x280 | 32 位整帧 DMA 目的地址，16 字节对齐 |
| BAR1 0x284 | 缓冲容量，至少 payload+16 |
| BAR1 0x288 | 非零新 token，启动整帧 DMA |
| BAR0 0xA0 | 0x4C495633 (LIV3) |
| BAR0 0xA4 | bit0 busy，bits8:1 error |
| BAR0 0xA8 / 0xAC | accepted / completed token |
| BAR0 0xB4 / 0xB8 | 本次帧 ID / 完成页数 |
| BAR0 0xC0 / 0xC4 | 帧周期（像素时钟数）/ 像素时钟 Hz |
| BAR0 0xC8 / 0xCC | 源帧号 / 当前参数代数 |

像素后附 16 字节小端记录：0x46524D33、帧 ID、校验值、参数代数。
硬件拆分不跨 4KB 的页；ARM 等待 completed token，再核对完成记录和整帧校验。
超时保留在途 DMA 所有权，不释放仍可能被 FPGA 写入的缓冲。
旧 CAM2 程序不能使用 CAM3；新程序兼容旧位流。

## ARM

```sh
sh tools/build_native.sh
./stage/fpga-view --mode cam2 --fit -f
# 另一 SSH 会话调参，不启动第二个采集实例：
python3 tools/warpctl.py status
python3 tools/warpctl.py apply --k1 -0.12 --angle-degrees 12
python3 tools/apply_calibration.py calibration/my_camera_params.json --save calibration/my_camera_params.applied.json --watch
```

watch 在输入尺寸改变且队首输出进入新尺寸后重新编译标定，参数写入期间使用共享锁。
标定要求 HDMI 与标定图同宽高比且等比例缩放；裁剪/加黑边需要另外描述。
显示窗口自动重建 ARGB 缓冲，源 RGB565 保持原尺寸；屏幕可等比例缩放。
刷新率变化无需重编译；当前目标范围 ≤30 Hz。

## 验证边界

RTL 测试覆盖连续采集、三帧所有权、DDR/PCIe 随机停顿、4KB 拆页、完成记录、分辨率/参数切换及逐像素参考值。
ARM 测试覆盖尺寸变化、容量、延迟可见、校验失败及超时所有权。
综合、布局布线、时序、下载与实际吞吐分别验证，仿真不能替代 1080p30 上板测量。
