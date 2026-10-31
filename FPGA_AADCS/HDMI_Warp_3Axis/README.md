# FPGA三轴棋盘稳像工程（R6）

本工程为PG2L100H-6IFBG484的三轴版本，完整保留Brown镜头畸变采样，并在同一遍映射中加入棋盘平面的横滚、俯仰、偏航、平移及尺度补偿。上位机从完整9×6方格估计40内角点的姿态，通过持久SSH→RK3568→PCIe提交9项逆透视H；未接实体IMU。

源码入口hdmi_warp.pds。原HDMI_Warp目录保留分支基线，不覆盖；M5镜像回退位流在releases/r6-20261031。R6独立时序最差+0.199ns，签核门限+0.197ns；APM189/240、DRM109.5/155。没有增加整帧DDR池，原CAM3视频帧协议保留。

## 构建与下载

使用PDS_2022.2-SP6.4，建议通过没有空格的短路径工作。build_live60.ps1保存R6实际使用的物理位置提示及性能开关，仍必须对每个新构建独立STA。以下第一条重新构建，第二条下载已有R6；下载新构建时更改BuildDir。

```powershell
./build_live60.ps1 -PdsRoot E:/pango/PDS_2022.2-SP6.4 -BuildDir build/new_threeaxis -MirrorBorder
./program.ps1 -PdsRoot E:/pango/PDS_2022.2-SP6.4 -BuildDir releases/r6-20261031 -JtagPort 61234
```

只写SRAM；断电失效。下载前正常停止PC上位机及ARM视频进程；下载后重新启动ARM视频程序恢复PCIe BAR，确认活动HDMI信号1920×1080@60，再连接上位机同步镜头参数。上电默认映射须由上位机初始化为实际相机标定。

## 已验证结果与边界

31个实际HDMI/FPGA/PCIe已知角度棋盘案例通过，含横滚全周代表点、俯仰/偏航±20°和组合姿态；另有真实USB CAMERA的输出抓图。镜头采用上位机calibration/usb_camera_1080p_verified.json（已有720p标定换算到1080p后实拍验证）。

正视约60fps、横滚8°约58fps、15°约55fps、俯仰20°约60fps、偏航20°约59fps、组合(12°,10°,-10°)约56fps。45°/90°横滚会出现采集FIFO溢出并降至约30/20fps，未保证全周60fps。快速运动的参数/曝光尚未严格逐帧配对，仍可能残余抖动；单平面H不消除不同深度视差。

## 接口

BAR0能力0x1c0=H3D1、0x1c4=3、0x1c8=9、0x1cc=81；H影子回读0x180～0x1a0，BAR1写0x340～0x360，原0x250 COMMIT一次原子提交17项Brown/旧配置与9项H。地址避开CAM3 DMA及旧控制器低9位译码别名。完整协议及相机软件见配套三轴完整发布包POSE_PROTOCOL_V2.md。

配套ARM及PC上位机分支：https://github.com/Polaris-PT/RK3568-PCIE/tree/feat/three-axis-perspective-20261031 。实测记录见仓库docs/three-axis-r6-20261031.md。
