"""Check every output coordinate for the 1920x1080 fit preset."""
import json
from configure import ROOT,parameters
import sys
sys.path.insert(0,str(ROOT/'sim'))
from model import quantize,fixed_map
c=json.loads((ROOT/'config/warp.json').read_text())
assert (c['input_width'],c['input_height'],c['output_width'],c['output_height'])==(1920,1080,640,400)
assert all(c[k]==0 for k in ('k1','k2','k3','p1','p2','angle_degrees','translate_x','translate_y'))
q=quantize(parameters(c))
for y in range(400):
 for x in range(640):
  got=fixed_map(x,y,q)
  want=(x*3*4096,(y*3-60)*4096)
  assert got==want,(x,y,got,want)
print('PASS all 256000 fixed mapping coordinates: 1920x1080 fitted into 640x400, aspect ratio preserved, top/bottom borders black')
