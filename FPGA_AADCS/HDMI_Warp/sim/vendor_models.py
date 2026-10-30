"""Use the installed PDS functional model locally; never vendor its source."""
import hashlib
import json
import os
import re
from pathlib import Path


def drm36k_model(out):
    source=Path(os.environ.get('PDS_ROOT','F:/PDS_2022.2-SP6.4'))/'arch/vendor/pango/verilog/bsim/V_DRM36K_E1.v'
    original=source.read_bytes()
    model=original.replace(b'module V_DRM36K_E1',b'module GTP_DRM36K_E1',1)
    # Every tested primitive sets GRS_EN=FALSE. Resolve the unused simulator
    # global-reset hierarchy without requiring a PDS GUI testbench top.
    model=model.replace(b'GRS_INST.GRSNET',b"1'b1")
    # Icarus cannot parse this model's PDS timing-check extensions. This test
    # checks RAM function/latency; timing signoff uses the actual PDS reports.
    model=re.sub(rb'\bspecify\b.*?\bendspecify\b',b'',model,flags=re.S)
    target=out/'vendor_drm36k.v';target.write_bytes(model)
    (out/'vendor_drm36k.json').write_text(json.dumps(dict(source=str(source),
        source_sha256=hashlib.sha256(original).hexdigest(),
        simulation_sha256=hashlib.sha256(model).hexdigest(),
        changes=['module name alias only','unused GRS binding constant; all instances GRS_EN=FALSE','specify timing checks removed; functional model unchanged']),indent=2)+'\n')
    return target
