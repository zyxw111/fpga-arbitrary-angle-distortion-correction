"""Strict offline RTL regression; Windows avoids the broken iverilog driver.

Runs the installed ivlpp and ivl stages directly and checks EVERY exit code.
No accepting a stale vvp after a failed compilation. No tool install changes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

DEFAULT_TESTS = ["addr", "bilin", "warp", "pat", "pack", "patpack", "afifo",
                 "stream", "overflow", "vtop", "dmapat", "split", "frame",
                 "burst", "supply", "fetch", "store", "bridge", "faults", "pipeline", "async", "source", "replay", "ddrbist", "ddrlink", "dvp", "sccb", "camseq", "cammon", "camio", "camclock", "demo_bars", "demo_raw", "demo_corrected", "demostream_raw", "demostream_corrected", "demoddr_raw", "demoddr_corrected", "board_bars", "board_raw", "board_corrected", "board_corrupt", "board_invalid", "board_pcie", "board_dynamic", "mode_control", "affine", "camera_pcie", "ov5640_init", "camera_stream"]

def run(cmd, cwd, timeout=120):
    p = subprocess.run([str(x) for x in cmd], cwd=cwd, capture_output=True,
                       text=True, encoding="utf-8", errors="replace", timeout=timeout)
    if p.returncode:
        raise RuntimeError(f"{cmd[0]} exited {p.returncode}\n{p.stdout}\n{p.stderr}")
    return p.stdout + p.stderr

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    ap.add_argument("--bin", type=Path, default=Path("D:/iverilog/bin"))
    ap.add_argument("--tests", nargs="+", default=DEFAULT_TESTS)
    args = ap.parse_args()
    root = args.root.resolve()
    rtl = root / "source/rtl" if (root / "source/rtl").exists() else root / "rtl"
    outdir = root / "build/sim"
    outdir.mkdir(parents=True, exist_ok=True)
    core = args.bin.resolve().parent / "lib/ivl"
    report = []
    for name in args.tests:
        t0 = time.monotonic()
        top = "tb_" + name
        bench = root / "sim" / (top + ".sv")
        if not bench.exists():
            raise FileNotFoundError(bench)
        sources = sorted(rtl.glob("*.v")) + [bench]
        if name in ("fetch", "store", "pipeline", "async", "source", "replay", "ddrbist", "ddrlink"):
            sources.append(root / "sim/ddrmodel.sv")
        if name in ("async", "source"):
            sources.append(root / "sim/tb_pipeline.sv")
        if name.startswith("demo_") or name.startswith("preview_"):
            sources.append(root / "sim/tb_demo_base.sv")
        if name.startswith("demostream_"):
            sources.append(root / "sim/tb_demostream_base.sv")
        if name.startswith("demoddr_"):
            sources += [root / "sim/tb_pipeline.sv", root / "sim/ddrmodel.sv"]
        if name.startswith(("board_", "camera_")):
            sources += [root / "sim/tb_board.sv", root / "sim/ddrmodel.sv"]
        if name in ("board_pcie", "board_dynamic", "camera_pcie"):
            sources.append(root / "sim/pcie_ram_model.sv")
            sources += [p for p in (root / "source/pcie_dma").rglob("*.v") if "ips2l_pcie_dma_ram" not in str(p)]
        extra_inputs = []
        if name.startswith(("demo_", "demostream_", "demoddr_", "preview_", "board_")):
            extra_inputs = sorted((root / "sim/demo_vectors").glob("*.hex"))
        if name == "affine":
            extra_inputs = [root / "sim/affine_vectors.hex"]
        preprocessed = outdir / (top + ".pre.v")
        artifact = outdir / (top + ".vvp")
        artifact.unlink(missing_ok=True)
        config = outdir / (top + ".cfg")
        lines = [f"root:{top}", f"basedir:{core.as_posix()}",
                 "generation:2012", "generation:assertions", "generation:xtypes",
                 "generation:io-range-error", "generation:icarus-misc",
                 "warnings:n", "ignore_missing_modules:false",
                 f"out:{artifact.as_posix()}", "iwidth:32", "widthcap:65536"]
        lines += [f"module:{(core / (n + '.vpi')).as_posix()}" for n in
                  ("system", "vhdl_sys", "vhdl_textio", "v2005_math", "va_math", "v2009")]
        config.write_text("\n".join(lines) + "\n", encoding="utf-8")
        log = run([core / "ivlpp.exe", "-L", "-o", preprocessed, *sources], root)
        log += run([core / "ivl.exe", "-C", core / "vvp.conf", "-C", config,
                    preprocessed], root)
        log += run([args.bin.resolve() / "vvp.exe", artifact], root)
        (outdir / (top + ".log")).write_text(log, encoding="utf-8")
        if "PASS" not in log:
            raise RuntimeError(f"{top}: no explicit PASS")
        record = {"test": top, "seconds": round(time.monotonic()-t0, 3),
                  "status": "PASS", "inputs": {str(p.relative_to(root)):
                      hashlib.sha256(p.read_bytes()).hexdigest() for p in sources + extra_inputs}}
        report.append(record)
        print(next(s for s in log.splitlines() if "PASS" in s), flush=True)
        (outdir / "summary.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"PASS {len(report)} tests; logs and input hashes: {outdir}")

if __name__ == "__main__":
    main()
