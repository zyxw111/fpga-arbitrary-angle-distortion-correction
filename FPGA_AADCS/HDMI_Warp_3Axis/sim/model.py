"""Independent float mapping and explicit integer quantization reference."""
import math

ORDER=('a00','a01','a02','a10','a11','a12','fx','fy','cx','cy',
       'inv_fx','inv_fy','k1','k2','k3','p1','p2')

def quantize(values):
    return {k:round(v*(1<<(30 if k.startswith('inv_') else 16))) for k,v in values.items()}

def float_map(x,y,v):
    ax=v['a00']*x+v['a01']*y+v['a02']
    ay=v['a10']*x+v['a11']*y+v['a12']
    nx=(ax-v['cx'])/v['fx']; ny=(ay-v['cy'])/v['fy']
    r2=nx*nx+ny*ny
    s=1+v['k1']*r2+v['k2']*r2**2+v['k3']*r2**3
    dx=nx*s+2*v['p1']*nx*ny+v['p2']*(r2+2*nx*nx)
    dy=ny*s+v['p1']*(r2+2*ny*ny)+2*v['p2']*nx*ny
    return dx*v['fx']+v['cx'],dy*v['fy']+v['cy']

def fixed_map(x,y,c):
    def mul(a,b): return (a*b)>>16
    ax=x*c['a00']+y*c['a01']+c['a02']
    ay=x*c['a10']+y*c['a11']+c['a12']
    nx=((ax-c['cx'])*c['inv_fx'])>>30
    ny=((ay-c['cy'])*c['inv_fy'])>>30
    x2=mul(nx,nx);y2=mul(ny,ny);xy=mul(nx,ny);r2=x2+y2
    r4=mul(r2,r2);r6=mul(r4,r2)
    scale=65536+mul(c['k1'],r2)+mul(c['k2'],r4)+mul(c['k3'],r6)
    dx=mul(nx,scale)+mul(c['p1'],2*xy)+mul(c['p2'],r2+2*x2)
    dy=mul(ny,scale)+mul(c['p1'],r2+2*y2)+mul(c['p2'],2*xy)
    return (mul(dx,c['fx'])+c['cx'])>>4,(mul(dy,c['fy'])+c['cy'])>>4

def pattern(x,y,w,h):
    return ((x%32)<<11)|((y%64)<<5)|((x+y)%32) if 0<=x<w and 0<=y<h else 0

def sample(mx,my,w,h,pattern_fn=pattern):
    x=mx//4096;y=my//4096;dx=mx%4096;dy=my%4096
    weights=((4096-dx)*(4096-dy),dx*(4096-dy),(4096-dx)*dy,dx*dy)
    pix=[pattern_fn(x,y,w,h),pattern_fn(x+1,y,w,h),pattern_fn(x,y+1,w,h),pattern_fn(x+1,y+1,w,h)]
    result=0
    for shift,mask in ((11,31),(5,63),(0,31)):
        result|=((sum(((p>>shift)&mask)*a for p,a in zip(pix,weights))+(1<<23))>>24)<<shift
    return result
