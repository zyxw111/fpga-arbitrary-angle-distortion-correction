"""Full 1080p bit-exact A/B against the original fixed-point calibration.

Preload identical raw RGB565 and tile-ordered Q20.12 maps, then compare every
output pixel and the raster checksum. This is an interface model, not DDR PHY
timing evidence. Artifacts stay under build/full-wp1, separate from regress.py.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
from model import ORDER, fixed_map, pattern, sample

ROOT=Path(__file__).resolve().parent.parent
OUT=ROOT/'build/full-wp1'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate(params):
    record=json.loads(params.read_text(encoding='utf-8-sig'))
    assert record['input_size']==[1920,1080] and record['output_size']==[1920,1080]
    q={k:(v if v<2**31 else v-2**32) for k,v in zip(ORDER,record['words'])}
    key=hashlib.sha256(json.dumps(q,sort_keys=True).encode()).hexdigest()
    mark=OUT/'inputs.json'
    names=['source.hex','map.hex','golden.hex']
    if mark.exists():
        previous=json.loads(mark.read_text())
        if previous.get('key')==key and all((OUT/n).exists() and sha(OUT/n)==previous['hashes'].get(n) for n in names):
            previous['calibration_record_sha256']=sha(params)
            mark.write_text(json.dumps(previous,indent=2)+'\n')
            return previous
    w,h=1920,1080;golden=[0]*(w*h)
    with (OUT/'source.hex').open('w',encoding='ascii') as f:
        for y in range(h):
            for x in range(0,w,8):
                word=sum(pattern(x+i,y,w,h)<<(i*16) for i in range(8))
                f.write(f'{word:032x}\n')
    with (OUT/'map.hex').open('w',encoding='ascii') as f:
        for ty in range(0,h,8):
            for tx in range(0,w,32):
                low=None
                for y in range(ty,ty+8):
                    for x in range(tx,tx+32):
                        mx,my=fixed_map(x,y,q)
                        golden[y*w+x]=sample(mx,my,w,h)
                        pair=((my&0xffffffff)<<32)|(mx&0xffffffff)
                        if low is None:low=pair
                        else:f.write(f'{(pair<<64)|low:032x}\n');low=None
            if ty%128==0:print(f'Generated {ty+8}/{h} rows',flush=True)
    (OUT/'golden.hex').write_text(''.join(f'{v:04x}\n' for v in golden),encoding='ascii')
    result=dict(key=key,calibration_record_sha256=sha(params),words=record['words'],
                hashes={n:sha(OUT/n) for n in names},pixels=w*h)
    mark.write_text(json.dumps(result,indent=2)+'\n')
    return result


def main():
    global OUT
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--params',type=Path,default=ROOT/'checks/2026-10-27-phase0/v2-calibration.json')
    ap.add_argument('--bin',type=Path,default=Path('F:/AADCS_git/.cache/tools/iverilog/bin'))
    ap.add_argument('--modes',nargs='+',choices=['serial','overlap','fast','fast_sample'],default=['serial','overlap'])
    ap.add_argument('--out',type=Path,default=OUT)
    ap.add_argument('--timeout',type=int,default=1800,help='Per command; unrolled dual-coordinate RTL is CPU intensive in Icarus')
    args=ap.parse_args();OUT=args.out.resolve();OUT.mkdir(parents=True,exist_ok=True)
    inputs=generate(args.params);core=args.bin.parent/'lib/ivl'
    (OUT/'config_words.hex').write_text(''.join(f'{w&0xffffffff:08x}\n' for w in inputs['words']),encoding='ascii')
    os.environ['PATH']=str(args.bin)+os.pathsep+os.environ['PATH']
    results=[]
    for mode in args.modes:
        top={'serial':'tb_warp_full_serial','overlap':'tb_warp_full','fast':'tb_warp_full_fast','fast_sample':'tb_warp_full_fast_sample'}[mode]
        sources=[ROOT/'source/rtl'/n for n in ['warp_tiles.v','tile_fetch.v','bilin.v','video_ddr_arb.v']]
        sources += [ROOT/'sim/ddrmodel.sv',ROOT/'sim/tb_warp_full.sv']
        if mode=='serial':sources += [ROOT/'sim/tb_warp_full_serial.sv']
        if mode in ('fast','fast_sample'):sources += [ROOT/'source/rtl/warp_fast.v',ROOT/'source/rtl/hdmi_map_pipe.v',ROOT/'sim'/(top+'.sv')]
        hashes={str(p.relative_to(ROOT)):sha(p) for p in sources}
        artifact=OUT/(top+'.vvp');pre=OUT/(top+'.pre.v');cfg=OUT/(top+'.cfg')
        lines=[f'root:{top}',f'basedir:{core.as_posix()}','generation:2012','generation:assertions',
               'generation:xtypes','generation:io-range-error','generation:icarus-misc',
               'ignore_missing_modules:false',f'out:{artifact.as_posix()}','iwidth:32','widthcap:65536']
        lines += [f'module:{(core/(n+".vpi")).as_posix()}' for n in ['system','vhdl_sys','vhdl_textio','v2005_math','va_math','v2009']]
        cfg.write_text('\n'.join(lines)+'\n')
        commands=[[core/'ivlpp.exe','-L','-o',pre,*sources],
                  [core/'ivl.exe','-C',core/'vvp.conf','-C',cfg,pre],
                  [args.bin/'vvp.exe',artifact,'+SOURCE='+str(OUT/'source.hex'),
                   '+MAP='+str(OUT/'map.hex'),'+GOLDEN='+str(OUT/'golden.hex'),'+PARAMS='+str(OUT/'config_words.hex')]]
        began=time.monotonic();log=OUT/(mode+'.log')
        with log.open('w') as output:
            for command in commands:
                subprocess.run([str(x) for x in command],cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,check=True,timeout=args.timeout)
        text=log.read_text();match=re.search(r'PASS FULL1080 mode=(\d+) pixels=(\d+) max_error=0 cycles=(\d+) checksum=([0-9a-fA-F]+)',text)
        if not match:raise RuntimeError(text[-2000:])
        assert all(sha(p)==hashes[str(p.relative_to(ROOT))] for p in sources),'Source changed during full-frame simulation'
        result=dict(mode=mode,pixels=int(match[2]),max_absolute_error=0,psnr_db='Infinity (bit exact)',
                    cycles=int(match[3]),checksum=match[4],seconds=time.monotonic()-began,source_hashes=hashes)
        results.append(result);print(match[0],flush=True)
        (OUT/'results.json').write_text(json.dumps(dict(inputs=inputs,results=results),indent=2)+'\n')
    if len(results)==2:assert results[0]['checksum']==results[1]['checksum']


if __name__=='__main__':main()
