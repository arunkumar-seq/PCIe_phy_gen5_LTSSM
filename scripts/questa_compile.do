#-----------------------------------------------------------------------------
# scripts/questa_compile.do
#
# QuestaSim / ModelSim compile script for the PCIe Gen5 PHY.
#
#   * library      : <repo>/sim/work
#   * design       : every synthesizable file in rtl/ plus rtl/pcieTB.v, the
#                    simulation-only bench for the PCIe top (rtl/PCIE.v)
#   * language     : plain `vlog`.  rtl/*.v is Verilog-2001 only - the sole
#                    occurrences of the SystemVerilog keyword `logic` in the
#                    directory are inside comments (Descrambler.v:72,
#                    Scrambler.v:95) - so `-sv` is NOT required.  This matches
#                    tb/top/top.mk, the project's own build, which is the flow
#                    that produced the user's working transcript.
#
# Paths are resolved from this script's own location (`info script`), so it can
# be invoked from the repo root, from scripts/, from sim/, or from the QuestaSim
# GUI console without any cd.  This matters on Windows, where `make` may run from
# a Cygwin shell with a different notion of the working directory.
#
# Optional knob (SIM-015, see rtl/Timer.v):
#     set ::TIMER_PRESCALE 12      ;# before sourcing, or
#     make compile FAST_TIMERS=1   ;# from the Makefile
# defines SIM_TIMER_PRESCALE so every LTSSM timeout is 2**12 = 4096x shorter.
# Without it the design is compiled exactly as before (no define, no change).
#-----------------------------------------------------------------------------

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set REPO_ROOT  [file normalize [file join $SCRIPT_DIR ..]]
set RTL_DIR    [file join $REPO_ROOT rtl]
set SIM_DIR    [file join $REPO_ROOT sim]
set WORK_DIR   [file join $SIM_DIR work]

file mkdir $SIM_DIR

#-----------------------------------------------------------------------------
# Library
#-----------------------------------------------------------------------------
# vdel/vlib/vmap are wrapped in catch so a first-ever run (no work library, no
# modelsim.ini entry yet) does not abort the script.
catch {vdel -lib $WORK_DIR -all}
vlib $WORK_DIR
vmap work $WORK_DIR

#-----------------------------------------------------------------------------
# Compile-time defines
#-----------------------------------------------------------------------------
set VLOG_DEFINES ""
if {[info exists ::TIMER_PRESCALE] && [string length [string trim $::TIMER_PRESCALE]] > 0} {
    set VLOG_DEFINES "+define+SIM_TIMER_PRESCALE=[string trim $::TIMER_PRESCALE]"
    echo "questa_compile: SIM-015 timer prescale ENABLED (SIM_TIMER_PRESCALE=[string trim $::TIMER_PRESCALE])"
} else {
    echo "questa_compile: SIM-015 timer prescale disabled (true-scale PCIe timers)"
}

#-----------------------------------------------------------------------------
# Source list
#-----------------------------------------------------------------------------
# Every rtl/*.v file elaborates cleanly (slang: 0 errors over all 55 files and
# all 10 top-level candidates), so the directory can simply be globbed - this is
# also what tb/top/top.mk does with `../../rtl/*.v`.
#
# rtl/tb.v and rtl/LMC_tb.v are compiled to nothing on purpose: they are
# pre-refactor scratch benches kept verbatim behind `ifdef guards (SIM-012 and
# SIM-013).  Define INCLUDE_LEGACY_OS_CHECKER_TB / INCLUDE_LEGACY_LMC_TB to
# bring them back.
set rtl_files [lsort [glob -nocomplain -directory $RTL_DIR *.v]]
if {[llength $rtl_files] == 0} {
    error "questa_compile: no .v files found in $RTL_DIR"
}

echo "questa_compile: RTL_DIR = $RTL_DIR"
echo "questa_compile: [llength $rtl_files] source files"

#-----------------------------------------------------------------------------
# Compile
#-----------------------------------------------------------------------------
# -mfcu is deliberately NOT used: the design relies on one module per file and
# separate compilation units keep vlog's error messages pointing at one file.
set vlog_status 0
foreach f $rtl_files {
    echo "  vlog [file tail $f]"
    if {[catch {eval vlog -work work $VLOG_DEFINES [list $f]} msg]} {
        echo "** vlog FAILED for [file tail $f]: $msg"
        set vlog_status 1
    }
}

# Emit a single, greppable result marker. `make` cannot rely on vsim's exit code
# here (a Tcl `error` inside a -do script is reported but vsim still exits 0 when
# the script ends with `quit -f`), so the Makefile and scripts/run_questa.sh
# grep for this line instead. Do not change the marker text.
if {$vlog_status} {
    echo "questa_compile: COMPILE FAILED - see the messages above."
    echo "QUESTA_COMPILE_RESULT=FAILED"
} else {
    echo "questa_compile: OK - work library at $WORK_DIR"
    echo "questa_compile: next step -> do [file join $SCRIPT_DIR questa_run.do]"
    echo "QUESTA_COMPILE_RESULT=OK"
}
