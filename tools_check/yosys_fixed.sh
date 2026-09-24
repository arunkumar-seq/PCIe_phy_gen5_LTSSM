#!/usr/bin/env bash
# Focused yosys validation of ONLY the modules that received RTL fixes this pass.
# Far faster than a full-closure run: each invocation elaborates one top.
#
#   BUGFIX-046  -> TX_LTSSM        BUGFIX-047 -> OS_GENERATOR
#   FSM-005/006 -> mainLTSSM       FSM-007    -> LMC
#   SIM-015     -> Timer
#
#   usage: bash tools_check/yosys_fixed.sh TX_LTSSM OS_GENERATOR mainLTSSM LMC Timer
#
# Works on a throwaway /tmp copy with the osDecoder.v:181 non-constant loop bound
# replaced by a constant, because yosys refuses to READ that file at all and it is
# in the closure. The repository file is never modified - see
# docs/RTL_CHANGELOG.md section 5.1.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
RTL="$REPO/rtl"
export NODE_PATH="$HERE/node_modules"

SRC=/tmp/yosys_fixed_src
OUT=/tmp/yosys_fixed
rm -rf "$SRC" "$OUT"; mkdir -p "$SRC" "$OUT"

# Simulation-only benches: yosys executes $stop/$finish/$random in initial blocks
# at read time and aborts, so they must not be read.
EXCLUDE=" pcieTB.v tb.v tx_test.v LMC_tb.v LPIF_tb.v Descrambler_tb.v PIPERxDataTb.v rxltssmTB.v topmodule.v "
FILES=()
for f in "$RTL"/*.v; do
  b=$(basename "$f")
  case "$EXCLUDE" in *" $b "*) continue;; esac
  cp "$f" "$SRC/$b"; FILES+=("$b")
done
echo "synthesizable files: ${#FILES[@]}"

# sweep-only patch of the non-constant loop bound (see header)
python3 - "$SRC/osDecoder.v" <<'PY'
import sys
p = sys.argv[1]; s = open(p, newline='').read()
for a, b in (("j<128<<numberOfShifts", "j<512 /*SWEEP-ONLY*/"),
             ("j < 128<<numberOfShifts", "j < 512 /*SWEEP-ONLY*/")):
    if a in s:
        s = s.replace(a, b); break
else:
    sys.exit("osDecoder patch anchor not found")
open(p, "w", newline='').write(s)
print("osDecoder.v loop bound patched (sweep copy only)")
PY

READCMD=""; for b in "${FILES[@]}"; do READCMD+="read_verilog \"$b\"; "; done
ABS=();     for b in "${FILES[@]}"; do ABS+=("$SRC/$b"); done

if [ $# -eq 0 ]; then set -- TX_LTSSM OS_GENERATOR mainLTSSM LMC Timer; fi

printf '%-16s %-12s %-9s %-6s %-7s %s\n' MODULE RESULT PROBLEMS ADFF LATCH DETAIL
for mod in "$@"; do
  log="$OUT/$mod.log"
  ( cd "$SRC" && timeout 2000 node "$HERE/run_yosys.mjs" \
      "$READCMD hierarchy -top $mod; proc; opt_clean; check -noinit; stat" \
      "${ABS[@]}" ) >"$log" 2>&1
  rc=$?
  if   grep -q "Multiple edge sensitive events" "$log"; then res="PROC_DFF"
  elif grep -q "ERROR:" "$log";                         then res="ERROR"
  elif [ $rc -ne 0 ];                                   then res="FAIL(rc=$rc)"
  else                                                       res="ok"; fi
  prob=$(grep -oE "Found and reported [0-9]+ problem" "$log" | grep -oE "[0-9]+" | head -1)
  adff=$(grep -oE '\$adff +[0-9]+'  "$log" | grep -oE "[0-9]+" | head -1)
  lat=$( grep -oE '\$dlatch +[0-9]+' "$log" | grep -oE "[0-9]+" | head -1)
  det=$(grep -oE "(Multiple edge sensitive events found for this signal|Latch inferred for signal [^ ]*|found logic loop|ERROR: .{0,55})" "$log" | sort -u | head -2 | tr '\n' ';')
  printf '%-16s %-12s %-9s %-6s %-7s %s\n' "$mod" "$res" "${prob:--}" "${adff:-0}" "${lat:-0}" "${det:0:88}"
done
echo "FOCUSED SWEEP DONE"
