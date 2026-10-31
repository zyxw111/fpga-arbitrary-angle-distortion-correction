"""Full-resolution fixed-point preview and independent OpenCV comparison.

Needs numpy/OpenCV, unlike the build/configuration scripts. Outputs are software
reference images, never represented as captures from the physical board.
"""
import argparse
import json
from pathlib import Path
import sys
import cv2
import numpy as np
from configure import ROOT,parameters
sys.path.insert(0,str(ROOT/'sim'))
from model import quantize,fixed_map

def bgr(words):
    w=words.astype(np.uint32)
    return np.stack(((w&31)*255//31,((w>>5)&63)*255//63,((w>>11)&31)*255//31),axis=-1).astype(np.uint8)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('config',nargs='?',type=Path,default=ROOT/'config/warp.json')
    args=ap.parse_args();c=json.loads(args.config.read_text(encoding='utf-8-sig'))
    v=parameters(c);q=quantize(v);iw=c['input_width'];ih=c['input_height'];w=c['output_width'];h=c['output_height']
    out=ROOT/'build/preview'/args.config.stem;out.mkdir(parents=True,exist_ok=True)
    yy,xx=np.mgrid[:ih,:iw]
    image=np.stack((xx*255//max(iw-1,1),yy*255//max(ih-1,1),(xx+yy)*255//(iw+ih-2)),axis=-1).astype(np.uint8)
    for x in range(0,iw,40):cv2.line(image,(x,0),(x,ih-1),(255,255,255),1)
    for y in range(0,ih,40):cv2.line(image,(0,y),(iw-1,y),(255,255,255),1)
    cv2.circle(image,(iw//2,ih//2),min(iw,ih)//3,(0,0,255),3)
    cv2.putText(image,'SOFTWARE REFERENCE',(16,28),cv2.FONT_HERSHEY_SIMPLEX,.6,(255,255,255),1)
    words=((image[:,:,2].astype(np.uint16)>>3)<<11)|((image[:,:,1].astype(np.uint16)>>2)<<5)|(image[:,:,0]>>3)
    mx=np.empty((h,w),dtype=np.int32);my=np.empty_like(mx)
    for y in range(h):
        for x in range(w):mx[y,x],my[y,x]=fixed_map(x,y,q)
    y,x=np.mgrid[:h,:w]
    ax=v['a00']*x+v['a01']*y+v['a02'];ay=v['a10']*x+v['a11']*y+v['a12']
    nx=(ax-v['cx'])/v['fx'];ny=(ay-v['cy'])/v['fy'];r=nx*nx+ny*ny
    s=1+v['k1']*r+v['k2']*r*r+v['k3']*r*r*r
    fx=(nx*s+2*v['p1']*nx*ny+v['p2']*(r+2*nx*nx))*v['fx']+v['cx']
    fy=(ny*s+v['p1']*(r+2*ny*ny)+2*v['p2']*nx*ny)*v['fy']+v['cy']
    coord_error=max(float(np.max(np.abs(mx/4096-fx))),float(np.max(np.abs(my/4096-fy))))
    if coord_error>1/16:raise AssertionError(f'Coordinate error {coord_error}')
    x0=mx//4096;y0=my//4096;dx=(mx%4096).astype(np.int64);dy=(my%4096).astype(np.int64)
    pixels=[]
    for ox,oy in ((0,0),(1,0),(0,1),(1,1)):
        valid=(x0+ox>=0)&(x0+ox<iw)&(y0+oy>=0)&(y0+oy<ih)
        pixels.append(np.where(valid,words[np.clip(y0+oy,0,ih-1),np.clip(x0+ox,0,iw-1)],0).astype(np.int64))
    weights=((4096-dx)*(4096-dy),dx*(4096-dy),(4096-dx)*dy,dx*dy)
    result=np.zeros((h,w),dtype=np.uint16)
    for shift,mask in ((11,31),(5,63),(0,31)):
        values=(sum(((p>>shift)&mask)*a for p,a in zip(pixels,weights))+(1<<23))>>24
        result|=values.astype(np.uint16)<<shift
    reference=cv2.remap(bgr(words),fx.astype(np.float32),fy.astype(np.float32),cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
    decoded=bgr(result);error=np.abs(decoded.astype(np.int16)-reference.astype(np.int16))
    if args.config.stem=='warp' and all(c[k]==0 for k in ('angle_degrees','k1','k2','k3','p1','p2','translate_x','translate_y')) and c['scale']==1:
        assert np.array_equal(result,words[40:440,:640]),'Identity center crop mismatch'
    for name,value in [('input.png',bgr(words)),('fpga_fixed_reference.png',decoded),('opencv_float_reference.png',reference)]:
        if not cv2.imwrite(str(out/name),value):raise OSError(name)
    result.astype('<u2').tofile(out/'frame.rgb565')
    report=dict(config=str(args.config),max_coordinate_error_pixels=coord_error,
                mean_bgr_difference_vs_opencv=float(error.mean()),p99_bgr_difference_vs_opencv=float(np.percentile(error,99)),
                note='Software references. OpenCV uses quantized interpolation weights; RTL rounds RGB565 channels.')
    (out/'metrics.json').write_text(json.dumps(report,indent=2))
    print('PASS software preview:',report,flush=True)

if __name__=='__main__': main()
