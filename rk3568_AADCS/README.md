# AADCS RK3568 软件

## 当前内容

本次导入厂家提供的三个通信示例，保留原始源码和 Makefile，尚未编译或上板验证。

| 示例 | 目录 | 源码默认设备 |
| --- | --- | --- |
| I2C | apps/fpga_i2c/src | /dev/i2c-0 |
| FSPI | apps/fpga_fspi/src | /dev/spidev4.0 |
| PCIe DMA | apps/fpga_pcie_dma/src | /dev/pcie_dma_memcpy |

## 原始来源

配套资料：RK3568+PG2L50H100H开发板配套资料。
原始目录：05-开发资料/01-Linux系统/linux_demo/。
对应示例：mes_fpga_i2c_demo、mes_fpga_fspi_demo、mes_fpga_dma_memcpy_demo。
导入日期：2026-10-08。

## 环境与构建

先填写 configs/baseline.md，确认板上系统、SDK 和工具链版本。
原始 Makefile 设置 CC ?= aarch64-buildroot-linux-gnu-gcc。构建时应显式传入实际交叉编译器，例如在示例 src 目录执行：

```sh
make CC=/实际工具链路径/bin/aarch64-buildroot-linux-gnu-gcc
```

此路径为占位示例，必须替换。GNU make 的内置 CC 可能使 ?= 不按预期选择交叉编译器，因此显式指定 CC。
原始输出名称分别为 fpga_i2c、spi_rw、dma_memcpy_demo，请以各 Makefile 的 TARGET 为准。
当前不保证上述程序与板上系统、驱动或 FPGA 工程兼容。

## 驱动与设备树

- drivers/：后续放入实际使用的驱动源码和构建文件。本次未导入驱动。
- device-tree/：后续放入实际板卡使用、由项目维护的 DTS/DTSI 及必要依赖。本次未导入设备树。
- PCIe DMA 示例依赖对应驱动，不能仅靠应用源码运行。
- 设备节点、PCIe 地址和 input 事件编号必须根据实际板上环境确认。

## 脚本

scripts/build_apps.sh、deploy.sh、test_interface.sh 是零字节空文件，尚无功能；环境和接口确认后再实现。

## 固件管理

验证过的应用部署包、必要模块及配置放入仓库根目录 firmware/rk3568/。
本次不复制厂家 bin 文件、系统镜像、完整 SDK 或工具安装包。
