# 002：导入 RK3568 通信示例

日期：2026-10-08

## 修改内容

- 在 rk3568_AADCS/apps 导入原厂 I2C、FSPI、PCIe DMA 示例源码及 Makefile。
- 新建软件 README 和 configs/baseline.md。
- 创建 build_apps.sh、deploy.sh、test_interface.sh 三个零字节空脚本。
- 创建固件目录说明。

## 文件与验证状态

- 六个源码和 Makefile 文件与原始资料的 SHA-256 一致。
- 未复制原厂可执行文件、系统镜像、SDK 压缩包或工具安装包。
- 未导入驱动和设备树。
- 尚未编译和上板验证，尚未形成 FPGA 与 RK3568 配套发布版本。
