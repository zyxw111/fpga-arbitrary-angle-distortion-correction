import sys,subprocess,os,json,importlib.util,re,math
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[1];out=root/'build/threeaxis_sim';out.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(root/'tools'));sys.path.insert(0,str(root/'sim'))
from configure import parameters,render
from model import sample
iv=Path(os.environ.get('IVERILOG_ROOT',r'D:\iverilog'))/'bin';core=iv.parent/'lib/ivl';os.environ['PATH']=str(iv)+os.pathsep+os.environ['PATH']
def run(top,sources):
    pre=out/(top+'.pre.v');artifact=out/(top+'.vvp');cfg=out/(top+'.cfg')
    cfg.write_text('\n'.join([f'root:{top}',f'basedir:{core.as_posix()}','generation:2012','generation:assertions','generation:xtypes','generation:io-range-error','generation:icarus-misc','ignore_missing_modules:false',f'out:{artifact.as_posix()}','iwidth:32','widthcap:65536']+[f'module:{(core/(n+".vpi")).as_posix()}' for n in ('system','vhdl_sys','vhdl_textio','v2005_math','va_math','v2009')]))
    logs=[]
    for cmd in [[core/'ivlpp.exe','-L','-o',pre,*sources],[core/'ivl.exe','-C',core/'vvp.conf','-C',cfg,pre],[iv/'vvp.exe',artifact]]:
        p=subprocess.run([str(v) for v in cmd],cwd=root,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
        logs.append(p.stdout.decode('utf-8','replace'))
        if p.returncode:
            (out/(top+'.log')).write_text('\n'.join(logs));raise RuntimeError(logs[-1])
    (out/(top+'.log')).write_text('\n'.join(logs));print(logs[-1],flush=True)
    assert 'PASS' in logs[-1]

# Atomic 26-word CDC: H may never change independently of Brown parameters.
s=(root/'sim/tb_warp_control.sv').read_text().replace('module tb_warp_control;','module tb_warp_control_h3d;')
s=s.replace('wire [543:0] active;','wire [287:0] ah;wire [543:0] active;').replace('.active_config(active),','.active_config(active),.active_h(ah),')
s=s.replace(" if(active!==0 || pending)"," for(i=0;i<9;i=i+1)write(12'h340+4*i,32'h01230000+i);\n if(active!==0 || pending)")
s=s.replace('for(i=0;i<17;i=i+1)if(active',"for(i=0;i<9;i=i+1)if(ah[i*32+:32]!==32'h01230000+i)$fatal(1,\"torn homography %0d\",i);\n for(i=0;i<17;i=i+1)if(active")
tb=out/'tb_warp_control_h3d.sv';tb.write_text(s)
run('tb_warp_control_h3d',[root/'source/rtl/warp_control.v',tb])
run('tb_h3d_csr_isolation',[root/'source/rtl/warp_control.v',root/'source/rtl/frame_dma.v',root/'source/pcie_dma/ips2l_pcie_dma_controller.v',root/'sim/tb_h3d_csr_isolation.sv'])

# Existing stalled DDR + parity cache + RGB565 interpolation + checksum tests,
# now driven by a genuine non-affine inverse H and nonzero Brown distortion.
c=dict(input_width=64,input_height=40,output_width=64,output_height=40,vs_active_high=True,fx=64.,fy=64.,cx=32.,cy=20.,angle_degrees=0.,scale=1.,translate_x=0.,translate_y=0.,k1=-.16,k2=.04,k3=-.01,p1=.002,p2=-.003)
v=parameters(c,host_check=False);config=out/'test_config.v';config.write_text(render(v))
cfg=[round(v[n]*2**(30 if n.startswith('inv_') else 16)) for n in ['a00','a01','a02','a10','a11','a12','fx','fy','cx','cy','inv_fx','inv_fy','k1','k2','k3','p1','p2']]
a,p,y=np.deg2rad([7,6,-4]);Rz=np.array([[np.cos(a),-np.sin(a),0],[np.sin(a),np.cos(a),0],[0,0,1]])
Rx=np.array([[1,0,0],[0,np.cos(p),-np.sin(p)],[0,np.sin(p),np.cos(p)]]);Ry=np.array([[np.cos(y),0,np.sin(y)],[0,1,0],[-np.sin(y),0,np.cos(y)]])
K=np.array([[64.,0,32],[0,64,20],[0,0,1]]);h=np.rint((Rz@Ry@Rx@np.linalg.inv(K))*2**30).astype(np.int64).ravel()
(out/'h.hex').write_text('\n'.join(f'{int(n)&0xffffffff:08x}' for n in h))
def s32(n):n=int(n)&0xffffffff;return n if n<2**31 else n-2**32
def mul(a,b):return s32((int(a)*int(b))>>16)
def fixed(x,y):
    rx,ry,rz=[s32((int(h[i*3])*x+int(h[i*3+1])*y+int(h[i*3+2]))>>14) for i in range(3)]
    nx=(abs(rx)<<16)//rz;ny=(abs(ry)<<16)//rz
    if rx<0:nx=-nx
    if ry<0:ny=-ny
    x2=mul(nx,nx);y2=mul(ny,ny);xy=mul(nx,ny);radius=s32(x2+y2)
    r4=mul(radius,radius);r6=mul(r4,radius)
    scale=s32(65536+mul(cfg[12],radius)+mul(cfg[13],r4)+mul(cfg[14],r6))
    tx=s32(mul(cfg[15],s32(xy<<1))+mul(cfg[16],s32(radius+(x2<<1))))
    ty=s32(mul(cfg[15],s32(radius+(y2<<1)))+mul(cfg[16],s32(xy<<1)))
    return s32(mul(s32(mul(nx,scale)+tx),cfg[6])+cfg[8])>>4,s32(mul(s32(mul(ny,scale)+ty),cfg[7])+cfg[9])>>4
def reflect(v,n):
    lim=(n-1)*4096;t=abs(v) if v<0 else 2*lim-v if v>lim else v
    return min(lim,max(0,t))
def changed(x,y,w,h):return (((x+3)%32)<<11)|(((y+7)%64)<<5)|((x+y+11)%32) if 0<=x<w and 0<=y<h else 0
for mirror in [0,1]:
    for change in [0,1]:
        values=[]
        for yy in range(40):
            for xx in range(64):
                mx,my=fixed(xx,yy)
                if mirror:mx,my=reflect(mx,64),reflect(my,40)
                values.append(sample(mx,my,64,40,changed) if change else sample(mx,my,64,40))
        (out/f'golden_{mirror}_{change}.hex').write_text('\n'.join(f'{n:04x}' for n in values))
s=(root/'sim/tb_warp_fast.sv').read_text().replace('module tb_warp_fast #','module tb_warp_h3d #')
s=s.replace('wire [543:0] bank;',"reg [31:0] hw[0:8];reg [287:0] hm;wire [543:0] bank;")
s=s.replace('dut(.config_bank(bank),','dut(.config_bank(bank),.projection_h(hm),')
s=re.sub(r' warp_lut #.*?\.wready\(wr\[0\]\),\.wlast\(wl\[0\]\)\);'," assign build_error=0;assign wav[0]=0;assign waa[0+:28]=0;assign wal[0+:4]=0;assign wd[0+:128]=0;assign ws[0+:16]=0;",s,flags=re.S)
s=re.sub(r'  wait\(build_ready\).*?\$fatal\(1,"LUT word.*?;', '',s,flags=re.S)
s=s.replace('if(BORDER_MIRROR)$readmemh("build/sim/mirror_golden.hex",golden);','''$readmemh("build/threeaxis_sim/h.hex",hw);for(i=0;i<9;i=i+1)hm[i*32+:32]=hw[i];
  if(BORDER_MIRROR)$readmemh("build/threeaxis_sim/golden_1_0.hex",golden);''')
s=s.replace('build/sim/native_golden.hex','build/threeaxis_sim/golden_0_0.hex').replace('  $readmemh("build/sim/native_lut.hex",lut);','')
s=s.replace('build/sim/mirror_golden_changed.hex','build/threeaxis_sim/golden_1_1.hex').replace('build/sim/native_golden_changed.hex','build/threeaxis_sim/golden_0_1.hex')
s=s.replace('f<2','f<3').replace('   for(i=0;i<320;i=i+1)mem.memory', '''   if(f==2)begin hm=0;hm[256+:32]=-32'sd1073741824;for(i=0;i<2560;i=i+1)golden[i]=0;end
   for(i=0;i<320;i=i+1)mem.memory''')
s=s.replace('!==2)$fatal','!==3)$fatal').replace('if(OVERLAP_WRITE && !BORDER_MIRROR &&','if(OVERLAP_WRITE && !BORDER_MIRROR &&')
tb=out/'tb_warp_h3d.sv';tb.write_text(s)
sources=[p for p in (root/'source/rtl').glob('*.v') if p.stem!='hdmi_config']+[config,tb,root/'sim/ddrmodel.sv']
for name,mirror,stall in [('tb_h3d_sample',0,0),('tb_h3d_mirror_stall',1,1600)]:
    wrapper=out/(name+'.sv');wrapper.write_text('module '+name+';tb_warp_h3d #(.SAMPLE_PIPELINE(1),.BORDER_MIRROR('+str(mirror)+'),.WRITE_STALL('+str(stall)+')) test();endmodule')
    run(name,sources+[wrapper])
print('PASS atomic H/Brown CDC and full 3-axis bilinear DDR sample tests including back-facing masks',flush=True)

# Saved 768 current-lens coordinate vectors (including invalid-ray masks).
vectors=root/'sim/current_lens'
s=(vectors/'tb_h3d.sv').read_text().replace('sim/vectors.hex',(vectors/'vectors.hex').as_posix()).replace('sim/config.hex',(vectors/'config.hex').as_posix())
tb=out/'tb_h3d.sv';tb.write_text(s)
run('tb_h3d',[root/'source/rtl'/name for name in ['homogeneous_ray_pipe.v','ray_divide_pipe.v','ray_project_pipe.v','hdmi_map_h3d_pipe.v','hdmi_map_pipe.v']]+[tb])
