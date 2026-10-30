"""Offline regression: explicit exit codes, fresh artifacts, input hashes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import time
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'tools'))
from configure import parameters,render
from model import ORDER,quantize,float_map,fixed_map,sample

def run(cmd,timeout=180):
    log_path=ROOT/'build/sim/current.log'
    with log_path.open('w',encoding='utf-8') as log:
        p=subprocess.run([str(s) for s in cmd],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
    text=log_path.read_text(encoding='utf-8',errors='replace')
    if p.returncode: raise RuntimeError(text)
    return text

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--bin',type=Path,default=Path('F:/AADCS_git/.cache/tools/iverilog/bin'))
    ap.add_argument('--tests',nargs='+',default=['warp_perf','hdmi_map','hdmi_stream','hdmi_init','hdmi_monitor','hdmi_pcie','profile_control','clock_meter','video_rx','warp_control','hdmi_rx_stream','hdmi_v2_pcie','warp_tiles','hdmi_live_pcie'])
    args=ap.parse_args(); core=args.bin.resolve().parent/'lib/ivl'
    os.environ['PATH']=str(args.bin.resolve())+os.pathsep+os.environ['PATH']
    out=ROOT/'build/sim';out.mkdir(parents=True,exist_ok=True)
    rng=random.Random(20261022);vectors=[]
    base=json.loads((ROOT/'config/warp.json').read_text(encoding='utf-8-sig'))
    for n in range(300):
        c=base.copy();c.update(output_width=640,output_height=400,angle_degrees=rng.uniform(-35,35),scale=rng.uniform(.8,1.3),
            k1=rng.uniform(-.3,.1),k2=.04,k3=-.01,p1=.002,p2=-.003,fy=480.)
        values=parameters(c);q=quantize(values);x=rng.randrange(640);y=rng.randrange(400)
        mx,my=float_map(x,y,values)
        vectors.extend([x,y]+[q[k] for k in ORDER]+[*fixed_map(x,y,q),round(mx*4096),round(my*4096)])
    (out/'map_vectors.hex').write_text('\n'.join(f'{v&0xffffffff:08x}' for v in vectors)+'\n')
    c=base.copy();c.update(input_width=64,input_height=64,output_width=64,output_height=40,
        fx=64.,fy=64.,cx=32.,cy=32.,angle_degrees=12.,k1=-.16,k2=.04,k3=-.01,p1=.002,p2=-.003)
    values=parameters(c,host_check=False);q=quantize(values)
    (out/'test_config.v').write_text(render(values))
    golden=[sample(*fixed_map(x,y,q),64,64) for y in range(40) for x in range(64)]
    (out/'hdmi_golden.hex').write_text('\n'.join(f'{v:04x}' for v in golden)+'\n')
    native=[sample(*fixed_map(x,y,q),64,40) for y in range(40) for x in range(64)]
    (out/'native_golden.hex').write_text('\n'.join(f'{v:04x}' for v in native)+'\n')
    def changed_pattern(x,y,w,h):
        return (((x+3)%32)<<11)|(((y+7)%64)<<5)|((x+y+11)%32) if 0<=x<w and 0<=y<h else 0
    changed=[sample(*fixed_map(x,y,q),64,40,changed_pattern) for y in range(40) for x in range(64)]
    (out/'native_golden_changed.hex').write_text('\n'.join(f'{v:04x}' for v in changed)+'\n')
    large=[sample(*fixed_map(x,y,q),96,44) for y in range(44) for x in range(96)]
    (out/'live_large_golden.hex').write_text('\n'.join(f'{v:04x}' for v in large)+'\n')
    qp=q.copy();qp['a02']+=3*65536
    large=[sample(*fixed_map(x,y,qp),96,44) for y in range(44) for x in range(96)]
    (out/'live_large_changed.hex').write_text('\n'.join(f'{v:04x}' for v in large)+'\n')
    lut=[]
    for ty in range(0,40,8):
        for tx in range(0,64,32):
            for y in range(ty,ty+8):
                for x in range(tx,tx+32):
                    mx,my=fixed_map(x,y,q)
                    lut.append(((my&0xffffffff)<<32)|(mx&0xffffffff))
    (out/'native_lut.hex').write_text('\n'.join(f'{lut[i+1]:016x}{lut[i]:016x}' for i in range(0,len(lut),2))+'\n')
    for phase in (1,2):
        qp=q.copy();qp['a02']+=3*65536
        if phase==2:qp['k1']+=round(.05*65536)
        image=[sample(*fixed_map(x,y,qp),64,64) for y in range(40) for x in range(64)]
        (out/f'hdmi_golden{phase}.hex').write_text('\n'.join(f'{v:04x}' for v in image)+'\n')
    results=[]
    for name in args.tests:
        t0=time.monotonic();top='tb_'+name
        sources=[p for p in sorted((ROOT/'source/rtl').glob('*.v')) if p.stem!='hdmi_config']
        sources += [out/'test_config.v',ROOT/'sim'/f'{top}.sv']
        if name=='warp_dual_cache':
            from vendor_models import drm36k_model
            sources += [drm36k_model(out)]
        if name.startswith('video_ddr_weight'):
            sources += [ROOT/'sim/ddrmodel.sv']
            if name!='video_ddr_weight':sources += [ROOT/'sim/tb_video_ddr_weight.sv']
        if name in ('fetch_queue','fetch_immediate'):
            sources += [ROOT/'sim/ddrmodel.sv']
            if name=='fetch_immediate':sources += [ROOT/'sim/tb_fetch_queue.sv']
        if name in ('burst_double','burst_legacy'):
            sources += [ROOT/'sim/ddrmodel.sv']
            if name=='burst_legacy':sources += [ROOT/'sim/tb_burst_double.sv']
        if name.startswith('warp_tiles'):
            sources += [ROOT/'sim/ddrmodel.sv']
            if name!='warp_tiles':sources += [ROOT/'sim/tb_warp_tiles.sv']
        if name.startswith('warp_fast'):
            sources += [ROOT/'sim/ddrmodel.sv']
            if name!='warp_fast':sources += [ROOT/'sim/tb_warp_fast.sv']
        if name in ('hdmi_live_perf_off','hdmi_live_serial','hdmi_live_fast','hdmi_live_weight','hdmi_live_sample','hdmi_live_count_pipe'):
            sources += [ROOT/'sim/tb_hdmi_live_pcie.sv']
        if name in ('hdmi_pcie','hdmi_v2_pcie','hdmi_live_pcie','hdmi_live_perf_off','hdmi_live_serial','hdmi_live_fast','hdmi_live_weight','hdmi_live_sample','hdmi_live_count_pipe'):
            sources += [ROOT/'sim/ddrmodel.sv',ROOT/'sim/pcie_ram_model.sv']
            sources += [p for p in (ROOT/'source/pcie_dma').rglob('*.v') if 'ips2l_pcie_dma_ram' not in str(p)]
        pre=out/f'{top}.pre.v';artifact=out/f'{top}.vvp';artifact.unlink(missing_ok=True)
        cfg=out/f'{top}.cfg'
        lines=[f'root:{top}',f'basedir:{core.as_posix()}','generation:2012',
               'generation:assertions','generation:xtypes','generation:io-range-error',
               'generation:icarus-misc','ignore_missing_modules:false',
               f'out:{artifact.as_posix()}','iwidth:32','widthcap:65536']
        lines += [f'module:{(core/(n+".vpi")).as_posix()}' for n in
                  ('system','vhdl_sys','vhdl_textio','v2005_math','va_math','v2009')]
        cfg.write_text('\n'.join(lines)+'\n')
        input_paths=sources + [ROOT/'config/warp.json',ROOT/'sim/ms7200_expected.hex',out/'hdmi_golden.hex',out/'map_vectors.hex']
        inputs={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in input_paths}
        log=run([core/'ivlpp.exe','-L','-o',pre,*sources])
        log+=run([core/'ivl.exe','-C',core/'vvp.conf','-C',cfg,pre])
        log+=run([args.bin.resolve()/'vvp.exe',artifact],timeout=1200 if name=='video_rx' else 420 if name.startswith('warp_fast') or name.startswith('hdmi_live') else 180)
        (out/f'{top}.log').write_text(log)
        if 'PASS' not in log:raise RuntimeError(log)
        print(next(line for line in log.splitlines() if 'PASS' in line),flush=True)
        if any(hashlib.sha256(p.read_bytes()).hexdigest()!=inputs[str(p.relative_to(ROOT))] for p in input_paths):
            raise RuntimeError('Simulation input changed during run; rerun against fixed sources')
        results.append(dict(test=name,status='PASS',seconds=round(time.monotonic()-t0,3),inputs=inputs))
    (out/'summary.json').write_text(json.dumps(results,indent=2))
    print('PASS HDMI regression',flush=True)

if __name__=='__main__': main()
