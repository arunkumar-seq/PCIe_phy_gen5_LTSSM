#!/usr/bin/env bash
# Single full-closure yosys synthesis check for rtl/PCIE.v (module `PCIe`).
#
# Why ONE run instead of per-module: yosys has to parse all ~46 synthesizable
# rtl/*.v files (several of them >100 KB) before it can elaborate any top, so a
# per-module sweep pays that parse cost once per module. One
# `hierarchy -top PCIe` run elaborates the entire closure in a single pass and
# gives an authoritative answer for the whole design.
#
# Simulation-only benches are excluded: yosys executes $stop/$finish/$random in
# initial blocks at read time and aborts.
#
# SWEEP-ONLY PATCH (does NOT touch the repository): rtl/osDecoder.v:181 has
#     for (j = 0; j < 128<<numberOfShifts; j = j+8)
# where numberOfShifts is a runtime variable, so the loop bound is not constant.
# yosys refuses to read the file at all, which would block the whole closure
# (osDecoder is instantiated by RX at rtl/Modules Integration.v:107). To let the
# REST of the closure be checked, this script works on a throwaway copy in /tmp
# with that one bound replaced by a constant. The repository file is untouched;
# read the osDecoder result as "clean apart from the known non-constant loop".
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
RTL="$REPO/rtl"
export NODE_PATH="$HERE/node_modules"

SRC=/tmp/yosys_closure_src
OUT=/tmp/yosys_closure
rm -rf "$SRC" "$OUT"; mkdir -p "$SRC" "$OUT"

EXCLUDE=" pcieTB.v tb.v tx_test.v LMC_tb.v LPIF_tb.v Descrambler_tb.v PIPERxDataTb.v rxltssmTB.v topmodule.v "
FILES=()
for f in "$RTL"/*.v; do
  b=$(basename "$f")
  case "$EXCLUDE" in *" $b "*) continue;; esac
  cp "$f" "$SRC/$b"
  FILES+=("$b")
done
echo "synthesizable files read: ${#FILES[@]}"

# sweep-only patch of the non-constant loop bound (see header)
python3 - "$SRC/osDecoder.v" <<'PY'
import sys
p=sys.argv[1]; s=open(p,newline='').read()
n=s.replace("j<128<<numberOfShifts","j<512 /*SWEEP-ONLY*/")
if n==s:
    n=s.replace("j < 128<<numberOfShifts","j < 512 /*SWEEP-ONLY*/")
assert n!=s, "osDecoder patch anchor not found"
open(p,"w",newline='').write(n)
print("osDecoder.v loop bound patched (sweep copy only)")
PY

READCMD=""; for b in "${FILES[@]}"; do READCMD+="read_verilog \"$b\"; "; done

run_step () {  # run_step <label> <yosys commands>
  local label="$1"; shift
  local log="$OUT/$label.log"
  echo "=== $label ==="
  ( cd "$SRC" && timeout 2400 node "$HERE/run_yosys.mjs" "$READCMD$*" "${FILES[@]/#/$SRC/}" ) >"$log" 2>&1
  echo "  exit=$?  log=$log  ($(wc -l <"$log") lines)"
  grep -E "ERROR|Warning: |Latch inferred|found logic loop|Found and reported|Number of cells|\\\$adff|\\\$dff|\\\$dlatch" "$log" | sort | uniq -c | sort -rn | head -12
}

# 1) Elaborate the whole closure and report structural problems.
run_step "hierarchy" "hierarchy -top PCIe -check; check -noinit; stat"

# 2) Lower processes to FF/latch cells, then re-check. proc_dff is the step that
#    aborts on a process with two edge-sensitive events and no liftable async
#    reset (the BUGFIX-047 / FSM-007 / FSM-001 class), so it is run separately.
run_step "proc" "hierarchy -top PCIe; proc_clean; proc_rmdead; proc_prune; proc_init; proc_arst; proc_mux; proc_dlatch; opt_clean; check -noinit; stat"
run_step "proc_dff" "hierarchy -top PCIe; proc; opt_clean; check -noinit; stat"

echo "CLOSURE CHECK DONE"
