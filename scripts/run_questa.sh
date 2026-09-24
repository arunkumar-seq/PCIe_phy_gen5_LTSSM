#!/usr/bin/env bash
#
# scripts/run_questa.sh - one-shot QuestaSim compile + run for the RTL bench.
#
# This is the same thing `make compile sim` does, for shells without make
# (Git Bash / Cygwin / WSL). It is NOT needed if you use the Makefile.
#
#   usage:
#     bash scripts/run_questa.sh                      # batch, 200 us smoke test
#     bash scripts/run_questa.sh --gui                # GUI + waveform groups
#     bash scripts/run_questa.sh --fast               # SIM-015 timers 4096x shorter
#     bash scripts/run_questa.sh --run-time "80 ms"   # long enough to reach L0
#     bash scripts/run_questa.sh --top pcieTB --questa-bin "C:/questasim64_10.4e/win64/"
#
# Exit status is non-zero if compilation fails, so this is safe to use in CI or
# as a make recipe.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

TOP="pcieTB"
RUN_TIME="200 us"
GUI=0
FAST=0
PRESCALE=12
QUESTA_BIN=""

while [ $# -gt 0 ]; do
  case "$1" in
    --gui)          GUI=1; shift ;;
    --fast)         FAST=1; shift ;;
    --top)          TOP="$2"; shift 2 ;;
    --run-time)     RUN_TIME="$2"; shift 2 ;;
    --prescale)     PRESCALE="$2"; FAST=1; shift 2 ;;
    --questa-bin)   QUESTA_BIN="$2"; shift 2 ;;
    -h|--help)      sed -n '2,20p' "$0"; exit 0 ;;
    *)              echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

VSIM="${QUESTA_BIN}vsim"
command -v "$VSIM" >/dev/null 2>&1 || {
  echo "ERROR: '$VSIM' not found on PATH." >&2
  echo "       Pass --questa-bin \"C:/questasim64_10.4e/win64/\" (trailing slash)." >&2
  exit 1
}

SIM_DIR="$REPO/sim"
mkdir -p "$SIM_DIR"
TAG=""
[ "$FAST" = 1 ] && TAG="_fast"
PRESCALE_TCL=""
[ "$FAST" = 1 ] && PRESCALE_TCL="$PRESCALE"

echo "=== compile (prescale='${PRESCALE_TCL}') ==="
"$VSIM" -c -do "set ::TIMER_PRESCALE {$PRESCALE_TCL}; do $HERE/questa_compile.do; quit -f" \
  2>&1 | tee "$SIM_DIR/compile$TAG.log"
grep -q "QUESTA_COMPILE_RESULT=OK" "$SIM_DIR/compile$TAG.log" || {
  echo "COMPILE FAILED - see $SIM_DIR/compile$TAG.log" >&2; exit 1; }

if [ "$GUI" = 1 ]; then
  echo "=== GUI run: $RUN_TIME ==="
  "$VSIM" -gui -t ns -voptargs=+acc "work.$TOP" \
    -do "set ::RUN_TIME {$RUN_TIME}; do $HERE/questa_run.do"
else
  echo "=== batch run: $RUN_TIME ==="
  "$VSIM" -c -t ns -voptargs=+acc "work.$TOP" \
    -do "set ::RUN_TIME {$RUN_TIME}; set ::WLF_FILE {$SIM_DIR/${TOP}${TAG}.wlf}; do $HERE/questa_run.do; quit -f" \
    2>&1 | tee "$SIM_DIR/sim$TAG.log"
  echo "=== done; log: $SIM_DIR/sim$TAG.log ==="
  echo "    reopen waveforms: $VSIM -gui -view $SIM_DIR/${TOP}${TAG}.wlf -do \"do $HERE/questa_wave.do\""
fi
