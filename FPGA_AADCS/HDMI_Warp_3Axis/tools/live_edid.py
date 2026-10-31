"""Reproducible <=30/60 Hz default EDID. Legacy KEY1 profiles remain unchanged.
VIC reference: https://github.com/torvalds/linux/blob/v6.6/drivers/gpu/drm/drm_edid.c
720p30 uses CTA VIC62; its long horizontal porch cannot fit a base EDID DTD.
The preferred DTD is 1080p30, with all six modes declared as CTA SVDs.
"""
from pathlib import Path
import re,json,hashlib,argparse
ROOT=Path(__file__).resolve().parents[1]

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--max-fps',type=int,choices=(30,60),default=60)
 fps=ap.parse_args().max_fps
 e=bytearray((ROOT/('edid/6-1920x1080_60.bin' if fps==60 else 'edid/4-1920x1080_30.bin')).read_bytes())
 e[10:12]=(0x2060 if fps==60 else 0x2030).to_bytes(2,'little');e[12:16]=(0x600001 if fps==60 else 0x300001).to_bytes(4,'little')
 e[35:38]=bytes(3);e[38:54]=bytes([1,1])*8
 e[72:90]=bytes([0,0,0,0xfc,0])+f'FPGA LIVE{fps}\n'.encode().ljust(13,b' ')
 modes=[16,31,34,33,32,4,19,62,61,60] if fps==60 else [34,33,32,62,61,60]
 blocks=bytes([0x40|len(modes),0x80|modes[0]]+modes[1:]+[0x67,3,0x0c,0,0x10,0,0,30 if fps==60 else 15])
 e[128:]=bytes(128);e[128:132]=bytes([2,3,4+len(blocks),0]);e[132:132+len(blocks)]=blocks
 e[127]=(-sum(e[:127]))&255;e[255]=(-sum(e[128:255]))&255
 assert len(e)==256 and sum(e[:128])%256==sum(e[128:])%256==0
 (ROOT/'edid/0-multi.bin').write_bytes(e)
 (ROOT/'edid/0-multi.hex').write_text(''.join(f'{b:02x}\n' for b in e))
 profiles=json.loads((ROOT/'edid/profiles.json').read_text())
 names=['1920x1080@60','1920x1080@50','1920x1080@30','1920x1080@25','1920x1080@24','1280x720@60','1280x720@50','1280x720@30','1280x720@25','1280x720@24'] if fps==60 else ['1920x1080@30','1920x1080@25','1920x1080@24','1280x720@30','1280x720@25','1280x720@24']
 profiles[0].update(preferred=f'1920x1080@{fps}',modes=names,sha256=hashlib.sha256(e).hexdigest())
 (ROOT/'edid/profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
 p=ROOT/'source/rtl/ms7200_ctl.v';s=p.read_text()
 body='\n'.join(f"8'h{i:02x}: get_edid=8'h{v:02x};" for i,v in enumerate(e))
 s,n=re.subn(r"(3'd0: begin case \(offset\)).*?(default: get_edid=8'h00;)",lambda m:m[1]+'\n'+body+'\n'+m[2],s,count=1,flags=re.S)
 assert n==1;p.write_text(s)
 for name in ('ms7200_expected.hex','ms7200_expected_p0.hex'):
  p=ROOT/'sim'/name;lines=p.read_text().splitlines()
  for i,line in enumerate(lines):
   value=int(line,16);addr=value>>8
   if 0x0d00<=addr<=0x0dff:lines[i]=f'{addr:04x}{e[addr&255]:02x}'
  p.write_text('\n'.join(lines)+'\n')
 print(f'PASS default EDID: preferred 1080p{fps}, both checksums and ROM updated')

if __name__=='__main__':main()
