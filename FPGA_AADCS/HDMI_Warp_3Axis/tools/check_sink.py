"""Check the imported sink EDID and the actual HDMIK V1.1 package pins."""
from pathlib import Path
import argparse,re,json,hashlib
ROOT=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--build',type=Path);a=ap.parse_args()
source=(ROOT/'source/rtl/ms7200_ctl.v').read_text()
tables={int(n):body for n,body in re.findall(r"3'd(\d): begin case \(offset\)(.*?)endcase end",source,re.S)}
profiles=json.loads((ROOT/'edid/profiles.json').read_text())
assert len(tables)==len(profiles)==7
for profile in profiles:
 edid=(ROOT/'edid'/profile['file']).read_bytes()
 assert len(edid)==256 and edid[:8]==bytes.fromhex('00ffffffffffff00')
 assert edid[126]==1 and all(sum(edid[i:i+128])%256==0 for i in (0,128))
 assert hashlib.sha256(edid).hexdigest()==profile['sha256']
 table={int(k,16):int(v,16) for k,v in re.findall(r"8'h([0-9a-fA-F]+): get_edid=8'h([0-9a-fA-F]+)",tables[profile['profile']])}
 assert bytes(table[i] for i in range(256))==edid
default=(ROOT/'edid/0-multi.bin').read_bytes()
assert list(default[133:139])==[0x80|34,33,32,62,61,60]
assert int.from_bytes(default[54:56],'little')==7425
assert (default[56]+((default[58]>>4)<<8),default[59]+((default[61]>>4)<<8))==(1920,1080)
print('PASS seven EDID profiles: checksums, SHA256 and all 1792 internal RAM bytes')
if a.build:
 # Independent HDMIK V1.1 reference, including its PCLK/B[1] swap vs V1.0.
 expected=dict(zip(('pixclk_in','vs_in','hs_in','de_in','hd_sda','hd_scl','board_clk_p','board_clk_n','key0_n','key1_n'),
                   ('W19','R17','U17','P16','AA20','AA21','R4','T4','M15','M16')))
 for channel, balls in [('r','AB21 Y18 AB22 Y19 N15 V18 AA19 V19'),
                        ('g','AB20 R18 V17 T18 W17 N17 AA18 P17'),
                        ('b','AB18 P15 U20 R16 V20 N13 W20 N14')]:
  expected.update({f'{channel}_in[{7-i}]':ball for i,ball in enumerate(balls.split())})
 actual={}
 for line in (a.build/'place_route/hdmi_warp_top.prr').read_text().splitlines():
  f=[x.strip() for x in line.split('|')]
  if len(f)>4 and f[2] in ('input','output','inout'):actual[f[1]]=f[3]
 ports=list(expected)
 assert len(ports)==34
 # Production frame capture uses DE/VS. HS only feeds the optional debug record
 # and may disappear when that record's line-period bits are not observed.
 optimized=set(expected)-set(actual)
 unused={'hs_in','r_in[0]','r_in[1]','r_in[2]','g_in[0]','g_in[1]','b_in[0]','b_in[1]','b_in[2]'}
 assert optimized<=unused,optimized
 fdc=(ROOT/'hdmi_warp.fdc').read_text()
 for p in ports:
  assert 'define_attribute {p:'+p+'} {PAP_IO_LOC} {'+expected[p]+'}' in fdc
  if p not in optimized:assert actual.get(p)==expected[p],(p,actual.get(p),expected[p])
 print(f'PASS HDMIK V1.1: all {len(ports)} pin constraints and {len(ports)-len(optimized)} retained physical ports; optimized={sorted(optimized)}')
