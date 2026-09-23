#!/usr/bin/env bash
# Targeted yosys synthesis check for the modules touched by this session's fixes
# (plus their enclosing closure modules).
#
# Simulation-only benches are excluded: yosys executes $stop/$finish/$random in
# initial blocks at read time and aborts.
#
# SWEEP-ONLY PATCH (does NOT touch the repository): rtl/osDecoder.v:181 has
#     for(j = 0; j < 128<<numberOfShifts; j=j+8)
# where numberOfShifts is a runtime variable, so the loop bound is not a
# constant.  yosys refuses to read the file at all
#     "osDecoder.v:181: ERROR: 2nd expression of procedural for-loop is not
#      constant!"
# which would block every module in the closure (osDecoder is instantiated by RX
# at rtl/Modules Integration.v:107).  To let the REST of the closure be checked,
# this script works on a throwaway copy in /tmp with that one bound replaced by
# a constant.  The repository file is untouched, and the osDecoder/RX results
# below must be read as "clean apart from the known non-constant loop bound".
set -u
REPO=${REPO:-$(cd "$(dirname "$0")/.." && pwd)}
RTL="$REPO/rtl"
RUNNER="$(cd "$(dirname "$0")" && pwd)/run_yosys.mjs"
# Resolve @yowasp/yosys from this directory's node_modules (installed with
# `npm i @yowasp/yosys` inside tools_check/). Without this, yowasp re-downloads
# its ~77 MB wasm blob on every single yosys invocation.
export NODE_PATH="$(cd "$(dirname "$0")" && pwd)/node_modules"
SRC=/tmp/yosys_targeted_src
OUT=/tmp/yosys_targeted
rm -rf "$SRC" "$OUT"; mkdir -p "$SRC" "$OUT"

EXCLUDE=" pcieTB.v tb.v tx_test.v LMC_tb.v LPIF_tb.v Descrambler_tb.v PIPERxDataTb.v rxltssmTB.v topmodule.v "
FILES=()
while IFS= read -r f; do
  b=$(basename "$f")
  case "$EXCLUDE" in *" $b "*) continue;; esac
  cp "$f" "$SRC/$b"
  FILES+=("$SRC/$b")
done < <(ls "$RTL"/*.v)

# sweep-only patch of the non-constant loop bound (see header)
python3 - "$SRC/osDecoder.v" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p,newline='').read()
n=s.replace("j<128<<numberOfShifts","j<512 /*SWEEP-ONLY*/")
assert n!=s, "osDecoder patch anchor not found"
open(p,"w",newline='').write(n)
PY

READCMD=""
for f in "${FILES[@]}"; do READCMD+="\"$(basename "$f")\" "; done

# modules touched this session + their closure containers
MODS="mainLTSSM TX_LTSSM LMC LMC_RX OS_GENERATOR Timer osChecker masterRxLTSSM RX TOP_MODULE Scrambler Descrambler PIPE_Control LPIF_RX_Control_DataFlow Master Master_Tx UnStriping DataHandling"

printf '%-26s %-9s %-9s %-8s %-6s %s\n' MODULE RESULT PROBLEMS LATCHES LOOPS NOTE
for mod in $MODS; do
  log="$OUT/$mod.log"
  timeout 1200 node "$RUNNER" \
    "read_verilog $READCMD; hierarchy -top $mod; proc; opt_clean; check -noinit" \
    "${FILES[@]}" >"$log" 2>&1
  rc=$?
  if   grep -q "Multiple edge sensitive events" "$log"; then res="PROC_DFF"
  elif grep -q "ERROR" "$log";                          then res="ERROR"
  elif [ $rc -ne 0 ];                                   then res="FAIL"
  else                                                       res="ok"; fi
  prob=$(grep -oE "Found and reported [0-9]+ problems" "$log" | grep -oE "[0-9]+" | head -1); [ -z "${prob:-}" ] && prob="-"
  lat=$(grep -c "Latch inferred" "$log" 2>/dev/null); lat=${lat:-0}
  loop=$(grep -c "found logic loop" "$log" 2>/dev/null); loop=${loop:-0}
  adff=$(grep -c "adff" "$log" 2>/dev/null); adff=${adff:-0}
  note=$(grep -oE "(Latch inferred for signal [^ ]*|found logic loop|unprocessed 'init' attribute|is not constant|Module .\\\[^ ]*' not found)" "$log" | sort -u | head -3 | tr '\n' ';')
  err=$(grep -oE "ERROR: .{0,60}" "$log" | head -1)
  printf '%-26s %-9s %-9s %-8s %-6s %s%s\n' "$mod" "$res" "$prob" "$lat" "$loop" "${note:0:70}" "$err"
done
echo "TARGETED SWEEP DONE"
