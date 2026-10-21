# RK3568 摄像头接收程序

`ov5640-capture` 是与本次 CAM2 FPGA 位流配套的 ARM64 Linux 静态程序，源码位于
`rk3568_AADCS/apps/ov5640_capture/`。构建信息和校验值见 `build-info.json`。

需要板上已有 `/dev/pcie_dma_memcpy` 驱动，支持厂家例程的 SETUP/SHUTDOWN ioctl、
coherent DMA mmap 和 32 位 DMA 总线地址。静态链接不替代内核驱动。

将程序复制到 RK3568 后运行：

```sh
chmod +x ./ov5640-capture
sudo ./ov5640-capture --frames 1 --output frame.rgb565 --ppm frame.ppm
```

默认 PCIe 设备为 `0002:21:00.0`，可用 `--pci /sys/bus/pci/devices/实际BDF` 修改。
它将 640×400 RGB565 图像 DMA 到 RK3568 DDR，并可保存原始文件和 PPM；不启动显示窗口。

接线、配套位流、状态寄存器和故障处理见 [摄像头使用说明](../../docs/ov5640-camera.md)。
本次完成交叉编译、二进制格式检查和协议单元测试，尚未在 ARM 实机运行。
