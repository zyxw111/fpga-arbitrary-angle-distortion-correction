# 2026-10-30 当前上板版本

PG2L100H / HDMIK V1.1；HDMI LIVE60 → 精确定点 Brown/仿射/双线性 → FPGA DDR → PCIe → RK3568。

位流 SHA256：`37cf17a1df91b044ba026a99b1c7cdcd45aa40843980eb998fc7bf17cc23409e`。全部最终时序约束满足，最差 setup +0.271ns；门限 +0.197ns。资源 LUT19154、FF28955、DRM109.5、APM199。当前标定下2073600像素离线比较最大误差0；数学RTL与全帧证明哈希一致，见 checks 的 quality_proof_binding.json。

在 HDMI_Warp 目录下载本目录保存的已测位流：

```powershell
./program.ps1 -BuildDir releases/live60-20261030
```

此命令仅下载SRAM，未写Flash。重启后若BAR0变为54321000，需重新下载，ARM接收命令不能代替配置FPGA。下载后应识别CAM2/WRP1；HDMI异常时重新插拔电脑→HDMIK输入线，确认有源1920×1080/60Hz。曾出现输入有效但采集计数不增长的启动状态，同一位流重新配置后恢复；原因尚未定位。

从源码重建（独立新目录，保留全部A/B开关）：

```powershell
./build_live60.ps1 -BuildDir build/live60-release
```

此入口包含read weight2、SAMPLE_PIPELINE1、COUNT_PIPELINE1、128KiB采集FIFO、双采集写缓存、8笔host读预取，并在映射后加入针对实际DDR PHY路径的位置提示。必须以重建后的独立最终STA为准；重建流程不自动下载。可重复执行构建不保证生成与保存位流相同的布局或时间戳。

ARM配套在RK3568-PCIE的dev分支，运行选项及标定方法见该仓库docs/live60_display.md。物理ARM显示需DISPLAY=:0、LightDM权限及1920×1080@60模式。默认参数保留原路径，使用本文构建入口才选择本次优化组合。

实测：22000帧全部送显，连续21989源帧约60.000864fps；另一轮14000帧稳态缺失4个源帧，最长连续7010帧。因此保留偶发源帧丢失限制，不能承诺持续零丢帧。后者10500帧硬件追踪59.98003fps、max warp16.87446ms / DMA14.27254ms，无漏观测及FIFO/协议错误；前者18000帧追踪漏观测warp1/DMA2，不能用其最大值证明每帧上限。完整数值和远程原始证据路径见manifest.json。
