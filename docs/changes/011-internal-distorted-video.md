# 2026-10-22：内部畸变图像替代摄像头

在本地 zyxw 的现有统一工程实现虚拟摄像头，复用用户指定的旧 Distortion 图像模型。
新增 synthetic_camera：固定点畸变 chart、连续光栅、低字节优先 DVP、帧号色块。
默认顶层启用内部源，继续经过 camera_stream、DDR 写入/读回和原厂 PCIe DMA；
取消默认模式对物理 SCCB 应答的依赖。真实 OV5640 保留为参数选择的另一个分支。

保留 CAM2 版本和 ARM 接收程序，flags bit5 标识内部源，内部 camera_id=0。
没有改动 ARM 程序，没有接入畸变/仿射矫正，不宣称主机连续接收 30 fps。
修正批处理读取 GUI PDS 状态/输出路径的处理，防止复用源目录的旧构建结果。
新增实际 640×400 输出对旧黄金图像比较、复位/节拍检查，以及原接收器、DDR 模型、
实际 PCIe RX/TX 下的三帧逐像素比较和主机停顿/反压测试。

详细操作与验证范围见 docs/internal-distorted-video.md；只有一个源 PDS 和一套当前位流。

最终结果：52 项 RTL 回归通过；PDS 完成位流生成，时序 All Constraints Met。
当前默认位流 SHA-256：293047d5b075f114f67656670a3ca306b1b411c4869c837f91047913f457052c。
本版未实板下载/ARM 联调。
