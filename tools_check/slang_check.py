#!/usr/bin/env python3
"""slang-based elaboration gate for the PCIe Gen5 PHY RTL.

Usage:
  python3 tools/slang_check.py --top PCIe --rtl-dir rtl [--exclude a.v b.v] [files...]

Why not `slang` on the command line: pyslang 11's Driver.parseCommandLine(str)
only loads the LAST positional file, so input files are pushed through
`sourceLoader.addFiles()` instead.  QuestaSim is only available on the user's
Windows machine, so this is the in-sandbox stand-in for the compile gate.
"""
import argparse
import glob
import os
import re
import sys

import pyslang

ast = pyslang.ast
drv = pyslang.driver


def build(files, top, single_unit=False, defines=()):
    d = drv.Driver()
    d.addStandardArgs()
    opts = f"--top={top}"
    if single_unit:
        opts += " --single-unit"
    for macro in defines:
        opts += f" -D{macro}"
    if not d.parseCommandLine(opts):
        raise SystemExit(f"parseCommandLine failed for: {opts!r}")
    # NOTE: files must be registered BEFORE processOptions() - it fails with
    # "no input files" otherwise.
    for f in files:
        d.sourceLoader.addFiles(f)
    if not d.processOptions():
        raise SystemExit("processOptions failed")
    if not d.parseAllSources():
        raise SystemExit("parseAllSources failed (file not found?)")
    return d, d.createCompilation()


def report(comp, show=60, sev_filter=None):
    diags = comp.getAllDiagnostics()
    engine = pyslang.DiagnosticEngine(comp.sourceManager)
    client = pyslang.TextDiagnosticClient()
    engine.addClient(client)
    for dg in diags:
        engine.issue(dg)
    text = re.sub(r"\x1b\[[0-9;]*m", "", client.getString())
    lines = text.splitlines()
    errs = [l.strip() for l in lines if re.search(r"\berror:", l)]
    warns = [l.strip() for l in lines if re.search(r"\bwarning:", l)]
    if sev_filter:
        pat = re.compile(sev_filter)
        errs = [l for l in errs if pat.search(l)]
        warns = [l for l in warns if pat.search(l)]
    print(f"== ERRORS: {len(errs)}   WARNINGS: {len(warns)}")
    for l in errs[:show]:
        print("  E:", l)
    if len(errs) > show:
        print(f"  ... {len(errs) - show} more errors")
    for l in warns[:show]:
        print("  W:", l)
    if len(warns) > show:
        print(f"  ... {len(warns) - show} more warnings")
    return len(errs), len(warns)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--top", default="PCIe")
    ap.add_argument("--rtl-dir", default=None)
    ap.add_argument("--exclude", nargs="*", default=[])
    ap.add_argument("--show", type=int, default=60)
    ap.add_argument("--grep", default=None, help="only print diagnostics matching this regex")
    ap.add_argument("--single-unit", action="store_true")
    ap.add_argument("--define", action="append", default=[],
                    help="macro to define, e.g. SIM_TIMER_PRESCALE=12")
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()

    files = list(args.files)
    if args.rtl_dir:
        files += sorted(glob.glob(os.path.join(args.rtl_dir, "*.v")))
    ex = {os.path.basename(e) for e in args.exclude}
    files = [f for f in files if os.path.basename(f) not in ex]
    if not files:
        print("no input files", file=sys.stderr)
        return 2

    print(f"== files: {len(files)}  top: {args.top}")
    _d, comp = build(files, args.top, args.single_unit, args.define)
    # slang's --top only *selects* among uninstantiated candidate tops, so
    # report what was really elaborated: every candidate top and hence the
    # whole transitive hierarchy below each one.
    tops = [str(t.name) for t in comp.getRoot().topInstances]
    print(f"== elaborated top instances ({len(tops)}): {' '.join(sorted(tops))}")
    ne, _nw = report(comp, args.show, args.grep)
    return 1 if ne else 0


if __name__ == "__main__":
    sys.exit(main())
