"""Compare board RGB565 frames with the RTL chart fixture and live frame marker."""
from pathlib import Path
import argparse, struct

parser=argparse.ArgumentParser()
parser.add_argument('frames',nargs='+',type=Path)
args=parser.parse_args()
repo=Path(__file__).resolve().parents[3]
gold=[int(x,16) for x in (repo/'FPGA_AADCS/Distortion_video/sim/demo_vectors/raw_640x400.hex').read_text().split()]
assert len(gold)==640*400
for path in args.frames:
    raw=path.read_bytes()
    assert len(raw)==512000,(path,len(raw))
    pixels=struct.unpack('<256000H',raw)
    marker=[pixels[392*640+x*8] for x in range(8)]
    assert all(x in (0x001f,0xffe0) for x in marker),(path,marker)
    frame_low=sum((x==0xffe0)<<i for i,x in enumerate(marker))
    wrong=[]
    for i,got in enumerate(pixels):
        y,x=divmod(i,640)
        want=marker[x//8] if y>=392 and x<64 else gold[i]
        if got!=want:wrong.append((i,got,want))
    assert not wrong,(path,len(wrong),wrong[:8])
    print(f'PASS {path.name}: all 256000 pixels exact; live source frame low byte={frame_low}')
