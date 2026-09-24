#!/usr/bin/env bash
# Per-module yosys synthesis sweep for the PCIe Gen5 PHY.
#
# The full-design `hierarchy -top PCIe` OOMs the yowasp-wasm build, so every
# module is elaborated on its own: read all *synthesizable* rtl files, prune to
# one top with `hierarchy -top <mod>`, then proc / opt_clean / check -noinit.
#
# Simulation-only benches are excluded from the read list: yosys executes
# $stop/$finish/$random found in initial blocks at read time and aborts
# (e.g. "LPIF_tb.v:124: ERROR: System task `$stop' executed.").
set -u
REPO=${REPO:-$(cd "$(dirname "$0")/.." && pwd)}
RTL="$REPO/rtl"
RUNNER="$(cd "$(dirname "$0")" && pwd)/run_yosys.mjs"
# Resolve @yowasp/yosys from this directory's node_modules (installed with
# `npm i @yowasp/yosys` inside tools_check/). Without this, yowasp re-downloads
# its ~77 MB wasm blob on every single yosys invocation.
export NODE_PATH="$(cd "$(dirname "$0")" && pwd)/node_modules"
OUT=${OUT:-/tmp/yosys_sweep}
mkdir -p "$OUT"

# Simulation-only benches (not part of any synthesis closure).
EXCLUDE=" pcieTB.v tb.v tx_test.v LMC_tb.v LPIF_tb.v Descrambler_tb.v PIPERxDataTb.v rxltssmTB.v "
# Modules skipped as tops: whole-design (OOMs the wasm build) or bench modules
# that live inside otherwise-synthesizable files.
SKIP_TOP=" PCIe RX_TB_Integration emadTB osDecoderTB "

FILES=()
while IFS= read -r f; do
  b=$(basename "$f")
  case "$EXCLUDE" in *" $b "*) continue;; esac
  FILES+=("$f")
done < <(ls "$RTL"/*.v)

READCMD=""
for f in "${FILES[@]}"; do READCMD+="\"$(basename "$f")\" "; done

# module -> defining file
MODS=()
while IFS= read -r line; do
  mod=$(sed -E 's/.*module +([A-Za-z_][A-Za-z0-9_$]*).*/\1/' <<<"$line" | tr -d '\r')
  MODS+=("$mod")
done < <(grep -h "^ *module" "${FILES[@]}")

printf '%-28s %-9s %-9s %-8s %-6s %s\n' MODULE RESULT PROBLEMS LATCHES LOOPS NOTE
for mod in $(printf '%s\n' "${MODS[@]}" | sort -u); do
  case "$SKIP_TOP" in *" $mod "*) printf '%-28s %-9s\n' "$mod" "SKIPPED"; continue;; esac
  log="$OUT/$mod.log"
  timeout 900 node "$RUNNER" \
    "read_verilog $READCMD; hierarchy -top $mod; proc; opt_clean; check -noinit" \
    "${FILES[@]}" >"$log" 2>&1
  rc=$?
  if   grep -q "Multiple edge sensitive events" "$log"; then res="PROC_DFF"
  elif grep -qE "ERROR" "$log";                          then res="ERROR"
  elif [ $rc -ne 0 ];                                    then res="FAIL"
  else                                                        res="ok"; fi
  prob=$(grep -oE "Found and reported [0-9]+ problems" "$log" | grep -oE "[0-9]+" | head -1)
  [ -z "${prob:-}" ] && prob="-"
  lat=$(grep -c "Latch inferred" "$log" 2>/dev/null || echo 0)
  loop=$(grep -c "found logic loop" "$log" 2>/dev/null || echo 0)
  note=$(grep -oE "(Latch inferred for signal [^ ]*|found logic loop|unprocessed 'init' attribute|is not constant)" "$log" | sort -u | head -3 | tr '\n' ';')
  printf '%-28s %-9s %-9s %-8s %-6s %s\n' "$mod" "$res" "$prob" "$lat" "$loop" "${note:0:100}"
done
echo "SWEEP DONE"
