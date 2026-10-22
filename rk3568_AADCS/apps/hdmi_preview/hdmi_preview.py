#!/usr/bin/env python3
"""Display checked CAM2 frames using the existing coherent-DMA capture tool.

Initial bring-up viewer: one capture-tool invocation per frame. This deliberately
shares its tested driver ABI/checksum logic, and is not a high-frame-rate viewer.
Requires numpy and an OpenCV build with GUI support on the RK3568 desktop.
"""
import argparse
from pathlib import Path
import subprocess
import tempfile
import cv2
import numpy as np

def decode(data):
    if len(data)!=640*400*2: raise ValueError('Expected 512000 bytes of RGB565 LE')
    pixels=np.frombuffer(data,dtype='<u2').reshape(400,640)
    # OpenCV expects BGR; match the receiver's RGB565 lane/byte order.
    return np.stack(((pixels&31)*255//31,((pixels>>5)&63)*255//63,
                     ((pixels>>11)&31)*255//31),axis=-1).astype(np.uint8)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--capture',default='./ov5640-capture')
    ap.add_argument('--pci',default='/sys/bus/pci/devices/0002:21:00.0')
    ap.add_argument('--dma',default='/dev/pcie_dma_memcpy')
    ap.add_argument('--input',type=Path,help='Decode an already captured RGB565 file')
    ap.add_argument('--png',type=Path,help='Save one frame and exit without opening a window')
    args=ap.parse_args()
    try:
        with tempfile.TemporaryDirectory(prefix='hdmi-preview-') as work:
            raw=Path(work)/'frame.rgb565'
            while True:
                if args.input: data=args.input.read_bytes()
                else:
                    subprocess.run([args.capture,'--pci',args.pci,'--dma',args.dma,
                        '--frames','1','--timeout-ms','20000','--output',str(raw)],check=True)
                    data=raw.read_bytes()
                image=decode(data)
                if args.png:
                    if not cv2.imwrite(str(args.png),image): raise OSError('PNG save failed')
                    print('PASS decoded CAM2 RGB565:',args.png);break
                cv2.imshow('HDMI -> FPGA warp -> PCIe -> RK3568',image)
                key=cv2.waitKey(0 if args.input else 1)&255
                if args.input or key in (27,ord('q')): break
    finally:
        if not args.png: cv2.destroyAllWindows()

if __name__=='__main__': main()
