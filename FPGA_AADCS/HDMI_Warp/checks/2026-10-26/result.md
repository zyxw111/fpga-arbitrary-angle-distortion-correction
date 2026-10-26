# HDMI 诱骗 / 在线矫正 / PCIe / ARM 显示实测

日期：2026-10-26。FPGA 仓库 F:/AADCS_git_zyxw，分支 zyxw-gpt。
ARM 仓库 F:/git_clone/RK3568-PCIE，原采集/显示基线 6cf5ab5。
USB 远程助手 2.0 EasyTier：JTAG 500 kHz；SSH 转发 10.144.144.2:2222。
以下记录均针对本次新位流，不借用旧 dummy 或 10/23 的结果作为本次证明。

## 验证对象

- 芯片 PG2L100H-6IFBG484，HDMIK V1.1 / MS7200。
- 源码入口 ../../hdmi_warp.pds，顶层 hdmi_warp_top。
- 普通位流 build/generate_bitstream/hdmi_warp_top.sbit，不含 DebugCore。
- SHA256：65aae5b356e69984e55b6c5122a8d762a594587ddc7cabeb0a3b9ad7cd674513。
- 同步至仓库 firmware/fpga/hdmi-warp/hdmi_warp_top.sbit；旧快照另存本地 .cache。
- 输入 DDR 地址 0，输出 DDR 地址 0x800000，避免 1080p 输入覆盖输出。

## 编译与离线验证

- PDS 全流程成功，`Design Summary : All Constraints Met.`，见 timing-summary.txt。
  DDR 用户域 setup 余量 0.620 ns，HDMI 像素域 148.5 MHz 下余量 0.788 ns。
  接收状态邮箱跨域采用独立同步释放；DDR 校验/异常更新分级，解决动态尺寸比较带来的路径。
- 资源：APM 25/240，CLMA 2689/11675，CLMS 1111/4975，DRM 18.5/155。
- 七档 EDID 的校验和、SHA256 和全部 1792 个 RAM 字节与 v2.0 源一致。
- HDMIK V1.1 全部 34 项引脚约束符合独立参考表。生产版仅保留 25 项实际输入，
  HS 和 RGB565 不使用的 8 个低位被优化；保留引脚均与布局结果一致。
- 默认 1080p→640×400 的 256000 个坐标与独立整数模型逐点一致。
- 完整仿真覆盖 hdmi_map、hdmi_stream、hdmi_init、hdmi_monitor、profile_control、
  clock_meter、video_rx、warp_control、hdmi_rx_stream、hdmi_pcie、hdmi_v2_pcie。
  video_rx 覆盖 VGA/720p/1080p 和模式/极性/频率变化、坏帧、CDC、复位。
- 最后一次 DDR 校验分级修改后，重新跑两个完整 PCIe 数据链用例，见 final-pcie-regression.json。
  每个用例均为 34 个描述符、132 个 TLP、7680 个精确像素/三帧，期间真实 BAR1 写改变
  仿射和 Brown 系数，并核对生效/帧代号、BAR0 回读、主机停读和 TX 随机反压。
  完整日志为 tb_*.txt。仿真 PHY 使用模型，不能代替实测。

## 上板与 ARM 显示

- 本次 SRAM 下载成功，Program 76.9 秒；DONE=1、init_complete=1、CRC/RBCRC 错误为 0，
  状态寄存器 0x081ffca0。见 program.txt。
- 原 fpga-probe 自动恢复 JTAG 下载后清零的 BAR，不移除或重新枚举 PCIe。
- 检测输入 1920×1080，像素时钟约 148499300 Hz。输出为 640×400、stride1280、
  每帧 512000 字节、RGB565 LE。
- 首次三帧全部 CAM2 校验成功、signal=yes，完成 375 个 DMA 描述符。
  第一帧取已有快照 86.27 ms，后两帧 198.71/190.65 ms；不是持续帧率保证。
- `hdmi-fit.png` 是通过真实 PCIe 取回的源桌面等比例输出，非合成测试图。
- 原 fpga-view 已在 ARM 的 :0 上启动并实际绘制，见 arm-demo.png。
  GUI 日志约 2～3 fps，持续状态见 arm-final.txt。

## 在线调参实测

- 独立工具 tools/warpctl.py、warp_math.py 部署至 /userdata/fpga-view/tools/。
  三项测试在 ARM Python3.11 上全通过，包括真实 Linux mmap/对齐 uint32 的模拟资源访问。
- 参数代号 1：检测尺寸生成零畸变等比例配置。
- 参数代号 2：窗口运行时 apply k1=-0.12、k2=0.02、旋转12°；accepted/applied/published
  均推进至2，ARM 屏幕可见变化。arm-demo.png 保存实际变换显示。
- 参数代号 3：恢复 /userdata/warp-hdmi-fit.json 的零畸变/零旋转；窗口继续显示。
  最近记录 accepted/applied/published=3，已发布 561 帧、异常丢帧0，处理/主机/I²C错误均0。
- 演示配置 /userdata/warp-hdmi-demo.json、基线配置 /userdata/warp-hdmi-fit.json 保留供切换。
  apply 不传 --config 时从零畸变适配配置开始，不继承上一组参数。

## 保持与边界

ARM 原有二进制未替换，其 SHA256 前后相同：

| 文件 | SHA256 |
|---|---|
| fpga-view | 7f02199d20ceb558b9b638fc3391769b0f0c3fe5c49ac1ef23e76da92175128e |
| fpga-probe | b2b6f7ce72cfeaf21224c7258d55c832ac0f38799a40c81d56f780ad65beca08 |
| run.sh | dbfaa513508b4ded52602f9a65486325daa25ef9c60078afb728ed57ff42ea11 |

本次验证 1080p HDMI 输入、640×400 快照输出；没有声称 1080p30 矫正输出，也没有逐档
上板回归所有 EDID 模式。MS7200 外部延迟/板间走线规格不全，未以虚构输入预算宣称板级签核。
畸变算法的系数变化和数据链已验证，真实镜头矫正精度仍取决于用户标定数据。
位流只在 SRAM，断电后需重新下载。未将本次改动提交或推送远程。
