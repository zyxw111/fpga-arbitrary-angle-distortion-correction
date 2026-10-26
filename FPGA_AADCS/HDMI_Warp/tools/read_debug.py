"""Decode named sink or pixel probes in a saved Fabric Debugger WDF."""
from pathlib import Path
import argparse,re,json
ap=argparse.ArgumentParser();ap.add_argument('path',type=Path);ap.add_argument('--sample',type=int,default=512);a=ap.parse_args()
b=a.path.read_bytes()
def vector(prefix,width):
 data=0
 for bit in range(width):
  name=f'{prefix}[{bit}]'.encode('utf-16-be');pos=0
  while True:
   pos=b.find(name,pos)
   if pos<0:raise ValueError(f'Missing capture data: {prefix}[{bit}]')
   start=pos+len(name)
   match=re.search(rb'(?:\x00[01xX]){1024}',b[start:start+2100])
   if match is not None and match.start()<32:break
   pos=start
  samples=match.group().decode('utf-16-be');value=samples[a.sample]
  if value not in '01':raise ValueError(f'Unknown sample {prefix}[{bit}]')
  data|=int(value)<<bit
 return data
v=vector('debug_sink',256);w=[(v>>(32*i))&0xffffffff for i in range(8)];f=w[0]
result=dict(flags=f'{f:08x}',edid_written=bool(f&2),receiver_ready=bool(f&4),video_present=bool(f&16),
 i2c_error=(f>>8)&255,controller_state=f>>25,pll_lock=bool(f&(1<<16)),ddr_lock=bool(f&(1<<17)),
 ddr_init=bool(f&(1<<18)),rdlh_link=bool(f&(1<<19)),smlh_link=bool(f&(1<<20)),
 frame_ready=bool(f&(1<<23)),pixel_hz=w[1],width=w[2]&65535,height=w[2]>>16,
 source_frames=w[3],last_register=f'{w[4]&65535:04x}',last_read=f'{(w[4]>>16)&255:02x}',
 good_frames=w[5],dropped_frames=w[6],last_drop_reason=w[7])
print(json.dumps(result,indent=2))
