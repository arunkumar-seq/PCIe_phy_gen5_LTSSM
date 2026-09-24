#=============================================================================
# PCIe Gen5 PHY (LTSSM) - top-level Makefile
#
# Two independent flows live in this repository:
#
#   A) RTL bench flow  (rtl/pcieTB.v -> rtl/PCIE.v)      : make compile|sim|wave
#      Self-contained Verilog bench, no UVM needed. This is the quickest way to
#      see the LTSSM train and to look at waveforms.
#
#   B) UVM environment (tb/, hvl_top + hdl_top)          : make uvm-build|uvm-run
#      Delegates to the project's own tb/sim/Makefile, which is unchanged.
#
# Plus tool checks that need no licence:
#      make lint     slang elaboration gate (python3 + pyslang)
#      make synth    yosys per-module synthesis check (node + @yowasp/yosys)
#
#-----------------------------------------------------------------------------
# WINDOWS
#-----------------------------------------------------------------------------
# `make` is not native to cmd.exe/PowerShell - see configure-make.md for the
# Cygwin install (or use MinGW). QuestaSim's binaries must be on PATH; if they
# are not, point QUESTA_BIN at the directory (with a trailing slash):
#
#     make sim  QUESTA_BIN="C:/questasim64_10.4e/win64/"
#
# Forward slashes work in both Cygwin make and Windows; backslashes do not
# survive make's escaping. The .do scripts resolve their own paths from
# `info script`, so they do not care which directory make was started from.
#
# Targets that only touch files (clean, help) work without any simulator.
#=============================================================================

SHELL := /bin/sh

#--- Tool locations ----------------------------------------------------------
QUESTA_BIN ?=
VLOG       := $(QUESTA_BIN)vlog
VSIM       := $(QUESTA_BIN)vsim
PYTHON     ?= python3
NODE       ?= node

#--- Repository layout -------------------------------------------------------
SCRIPTS    := scripts
SIM_DIR    := sim
RTL_DIR    := rtl
TB_DIR     := tb
TOOLS_DIR  := $(CURDIR)/tools_check

#--- RTL bench flow configuration -------------------------------------------
TOP        ?= pcieTB
# Simulation window. modelsim.ini sets Resolution=ns and pcieTB clocks at `#5`,
# so the Pclk period is 10 ns. See the "HOW LONG A WINDOW IS NEEDED" block in
# scripts/questa_run.do: at true PCIe timer scale Detect.Quiet alone is
# 3,000,000 cycles (30 ms), so 200 us is a SMOKE TEST, not full link training.
RUN_TIME   ?= 200 us
# FAST_TIMERS=1 compiles with +define+SIM_TIMER_PRESCALE=12 (SIM-015, rtl/
# Timer.v): every LTSSM timeout becomes 4096x shorter, so a 200 us window shows
# Detect -> Polling -> Configuration -> L0 many times over. Synthesis and the
# default build are unaffected - the macro simply is not defined.
FAST_TIMERS   ?= 0
TIMER_PRESCALE ?= 12
ifeq ($(FAST_TIMERS),1)
  PRESCALE_TCL := $(TIMER_PRESCALE)
  PRESCALE_TAG := _fast
else
  PRESCALE_TCL :=
  PRESCALE_TAG :=
endif

# Full internal visibility in the waveform window. QuestaSim optimizes the design
# by default (vopt) and drops internal nets; without +acc the mainLTSSM
# substate/handshake signals in scripts/questa_wave.do would not exist.
# `-novopt` (used by tb/sim/Makefile's run_design target) is the older, slower
# equivalent if your version rejects -voptargs.
VOPT_ARGS  ?= -voptargs=+acc
TIME_RES   ?= -t ns

WLF        := $(SIM_DIR)/pcieTB$(PRESCALE_TAG).wlf
COMPILE_LOG:= $(SIM_DIR)/compile$(PRESCALE_TAG).log
SIM_LOG    := $(SIM_DIR)/sim$(PRESCALE_TAG).log

.PHONY: help all compile sim wave wave-view lint synth synth-modules uvm-build uvm-run uvm-design uvm-clean clean distclean check-questa

#-----------------------------------------------------------------------------
help:
	@echo "PCIe Gen5 PHY - available targets"
	@echo ""
	@echo "  RTL bench (rtl/pcieTB.v -> rtl/PCIE.v)"
	@echo "    make compile      vlib/vmap/vlog rtl/*.v into $(SIM_DIR)/work"
	@echo "    make sim          batch run $(RUN_TIME), log -> $(SIM_LOG)"
	@echo "    make wave         GUI run with the waveform groups preloaded"
	@echo "    make wave-view    reopen the waveform database written by 'make sim'"
	@echo "    make sim FAST_TIMERS=1   same, with SIM-015 timers 4096x shorter"
	@echo "    make sim RUN_TIME=\"80 ms\"   true-scale run long enough to reach L0"
	@echo ""
	@echo "  UVM environment (tb/ - delegates to tb/sim/Makefile, unchanged)"
	@echo "    make uvm-build    compile common/agents/env/seq/test/top + rtl"
	@echo "    make uvm-run      vsim -gui with tb/sim/wave.do"
	@echo "    make uvm-design   vsim -novopt with tb/sim/design.do (FSM debug waves)"
	@echo "    make uvm-clean    remove tb/sim/work"
	@echo ""
	@echo "  Licence-free tool checks"
	@echo "    make lint         slang elaboration gate over $(RTL_DIR)/*.v"
	@echo "    make synth        yosys full-closure check on module PCIe"
	@echo "    make synth-modules  same, per-module (slower, better attribution)"
	@echo ""
	@echo "  Housekeeping"
	@echo "    make clean        remove $(SIM_DIR)/ build output and logs"
	@echo "    make distclean    clean + tb/sim/work"
	@echo ""
	@echo "  Windows: make needs Cygwin/MinGW (see configure-make.md). If vlog/vsim are"
	@echo "  not on PATH:  make sim QUESTA_BIN=\"C:/questasim64_10.4e/win64/\""
	@echo ""
	@echo "  Current settings: TOP=$(TOP) RUN_TIME=$(RUN_TIME) FAST_TIMERS=$(FAST_TIMERS)"

all: compile sim

# NB: no `$(SIM_DIR):` directory target - SIM_DIR is literally `sim`, which would
# collide with the `sim` run target below. The recipes create it themselves.

check-questa:
	@command -v $(VSIM) >/dev/null 2>&1 || { \
	  echo "ERROR: '$(VSIM)' not found on PATH."; \
	  echo "       Install/point at QuestaSim, e.g.  make sim QUESTA_BIN=\"C:/questasim64_10.4e/win64/\""; \
	  exit 1; }

#-----------------------------------------------------------------------------
# A) RTL bench flow
#-----------------------------------------------------------------------------
compile: check-questa
	@mkdir -p $(SIM_DIR)
	@echo "=== QuestaSim compile (TOP=$(TOP)$(PRESCALE_TAG)) ==="
	$(VSIM) -c -do "set ::TIMER_PRESCALE {$(PRESCALE_TCL)}; do $(SCRIPTS)/questa_compile.do; quit -f" \
	  2>&1 | tee $(COMPILE_LOG)
	@grep -q "QUESTA_COMPILE_RESULT=OK" $(COMPILE_LOG) || { \
	  echo ""; echo "make: COMPILE FAILED - see $(COMPILE_LOG)"; exit 1; }
	@echo "=== compile OK ==="

sim: compile
	@echo "=== QuestaSim batch run: $(RUN_TIME)$(PRESCALE_TAG) ==="
	$(VSIM) -c $(TIME_RES) $(VOPT_ARGS) work.$(TOP) \
	  -do "set ::RUN_TIME {$(RUN_TIME)}; set ::WLF_FILE {$(CURDIR)/$(WLF)}; do $(SCRIPTS)/questa_run.do; quit -f" \
	  2>&1 | tee $(SIM_LOG)
	@echo "=== run finished; log: $(SIM_LOG) ==="
	@echo "    Reopen waveforms with:  make wave-view"

wave: compile
	@echo "=== QuestaSim GUI run: $(RUN_TIME)$(PRESCALE_TAG) ==="
	$(VSIM) -gui $(TIME_RES) $(VOPT_ARGS) work.$(TOP) \
	  -do "set ::RUN_TIME {$(RUN_TIME)}; do $(SCRIPTS)/questa_run.do"

wave-view:
	@test -f $(WLF) || { echo "No waveform database at $(WLF) - run 'make sim' first."; exit 1; }
	$(VSIM) -gui -view $(WLF) -do "do $(SCRIPTS)/questa_wave.do"

#-----------------------------------------------------------------------------
# B) UVM environment - delegates to the project's own tb/sim/Makefile
#-----------------------------------------------------------------------------
uvm-build:
	@$(MAKE) -C $(TB_DIR)/sim build

uvm-run:
	@$(MAKE) -C $(TB_DIR)/sim run

uvm-design:
	@$(MAKE) -C $(TB_DIR)/sim run_design

uvm-clean:
	@$(MAKE) -C $(TB_DIR)/sim clean

#-----------------------------------------------------------------------------
# Licence-free checks
#-----------------------------------------------------------------------------
lint:
	@$(PYTHON) $(TOOLS_DIR)/slang_check.py --rtl-dir $(RTL_DIR) --show 30

synth:
	@bash $(TOOLS_DIR)/yosys_closure.sh

# Slower per-module variant (one full parse per module). Superseded by `synth`,
# kept because it attributes each problem to a single module.
synth-modules:
	@bash $(TOOLS_DIR)/yosys_targeted.sh

#-----------------------------------------------------------------------------
# Housekeeping
#-----------------------------------------------------------------------------
clean:
	rm -rf $(SIM_DIR)/work $(SIM_DIR)/*.wlf $(SIM_DIR)/*.log $(SIM_DIR)/transcript
	rm -rf $(SIM_DIR)/wlft* $(SIM_DIR)/vsim.wlf $(SIM_DIR)/vish_stacktrace.vstf
	rm -rf $(SIM_DIR)/vsim_stacktrace.vstf
	@echo "cleaned $(SIM_DIR)/"

distclean: clean uvm-clean
	@echo "cleaned $(SIM_DIR)/ and $(TB_DIR)/sim/work"
