"""Check the PDS final report against the agreed setup margin before download."""
import argparse
import json
from pathlib import Path
import re


def inspect(path, minimum=0.197):
    report = Path(path).read_text(encoding='utf-8', errors='replace')
    section = report.split('Setup Summary(Slow Corner):', 1)
    rows = []
    if len(section) == 2:
        for line in section[1].split('Hold Summary(Slow Corner):', 1)[0].splitlines():
            fields = line.split()
            if len(fields) == 6 and re.fullmatch(r'-?\d+\.\d+', fields[2]):
                rows.append(dict(launch=fields[0], capture=fields[1], wns_ns=float(fields[2])))
    all_met = 'Design Summary : All Constraints Met.' in report
    worst = min((r['wns_ns'] for r in rows), default=None)
    return dict(report=str(Path(path).resolve()), all_constraints_met=all_met,
                minimum_setup_ns=minimum, worst_setup_ns=worst,
                pass_timing=all_met and worst is not None and worst >= minimum,
                setup_clocks=rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report', type=Path)
    parser.add_argument('--minimum', type=float, default=0.197,
                        help='WP1 +0.397ns minus the permitted 0.2ns degradation')
    args = parser.parse_args()
    result = inspect(args.report, args.minimum)
    print(json.dumps(result, indent=2))
    raise SystemExit(0 if result['pass_timing'] else 1)


if __name__ == '__main__':
    main()
