#-----------------------------------------------------------------------------
# scripts/questa_run.do
#
# Sets up waveforms and runs the pcieTB bench for a BOUNDED window.
#
# Sourced from a vsim session that has already loaded the design, e.g.
#
#   batch : vsim -c   -t ns -voptargs=+acc work.pcieTB -do "do scripts/questa_run.do; quit -f"
#   GUI   : vsim -gui -t ns -voptargs=+acc work.pcieTB -do "do scripts/questa_run.do"
#
# (the Makefile targets `make sim` and `make wave` issue exactly these).
#
# WHY A BOUNDED RUN AND NOT `run -all`
# ------------------------------------
# rtl/pcieTB.v contains no $finish/$stop: after injecting its 62-beat TLP the
# bench simply stops driving stimulus while `always #5 CLK = ~CLK` keeps the
# clock running forever.  `run -all` therefore never returns.  That is exactly
# what the user's QuestaSim transcript shows - `vsim -c -do "run -all; quit -f;"`
# ran for 4m22s of wall clock, produced no messages after time 0, and had to be
# interrupted by hand ("Break key hit / Break at ... pipe_driver_bfm.sv line
# 800").  So this script always runs a fixed, overridable window instead.
#
# HOW LONG A WINDOW IS NEEDED
# ---------------------------
# modelsim.ini sets `Resolution = ns`, and the bench clocks at `#5` => a 10 ns
# Pclk period.  The LTSSM timeouts are modelled at true PCIe scale (see rtl/
# Timer.v and SIM-015): t12ms = 750000 base cycles, scaled by generation and
# PIPE width.  With GEN1..GEN5_PIPEWIDTH = 8:
#
#     Gen1 Detect.Quiet : 750000 << 0 << 2 =  3,000,000 cycles  =  30 ms sim
#     Gen5 12 ms timer  : 750000 << 4 << 2 = 48,000,000 cycles  = 480 ms sim
#
# Detect.Quiet and Detect.Active each use t12ms, so simply leaving Detect needs
# ~6,000,000 cycles (~60 ms of simulated time).  The default 200 us window below
# is therefore a SMOKE TEST: it proves the design elaborates, clocks, comes out
# of reset and starts the FSM - it is NOT long enough to reach L0 at true timer
# scale.  Two ways to see full link training:
#
#   * FAST_TIMERS=1 (SIM-015): compile with SIM_TIMER_PRESCALE=12, which divides
#     every timeout by 4096.  Detect.Quiet becomes ~732 cycles, so 200 us covers
#     Detect -> Polling -> Configuration -> L0 many times over.  Recommended for
#     debugging the FSM with waveforms.
#   * or raise the window, e.g. `make sim RUN_TIME="80 ms"` (slow: tens of
#     millions of cycles).
#
# Overridable from the Makefile / command line, before sourcing this script:
#   set ::RUN_TIME "200 us"       ;# simulation window
#   set ::WLF_FILE  "..."         ;# waveform database to write (batch)
#   set ::DO_WAVES  0|1           ;# skip the wave setup for a faster run
#-----------------------------------------------------------------------------

set SCRIPT_DIR [file dirname [file normalize [info script]]]
set REPO_ROOT  [file normalize [file join $SCRIPT_DIR ..]]
set SIM_DIR    [file join $REPO_ROOT sim]
file mkdir $SIM_DIR

if {![info exists ::RUN_TIME]} { set ::RUN_TIME "200 us" }
if {![info exists ::WLF_FILE]} { set ::WLF_FILE [file join $SIM_DIR pcieTB.wlf] }
if {![info exists ::DO_WAVES]} { set ::DO_WAVES 1 }

# Keep every signal visible.  QuestaSim optimizes the design by default (vopt),
# which removes internal nets - without this the mainLTSSM substate/handshake
# signals that questa_wave.do adds would not exist.  `+acc` keeps full access
# while still optimizing; `-novopt` (used by tb/sim/Makefile's run_design target)
# is the older, slower equivalent.
if {[catch {quietly set _vopt [vsim -h]}]} { }

echo "questa_run: design   = [lindex [getLoadedDesigns] 0]"
echo "questa_run: RUN_TIME = $::RUN_TIME"

#-----------------------------------------------------------------------------
# Waveforms
#-----------------------------------------------------------------------------
if {$::DO_WAVES} {
    # -logfile keeps the transcript even when the run is launched from a Makefile
    do [file join $SCRIPT_DIR questa_wave.do]
}

#-----------------------------------------------------------------------------
# Run
#-----------------------------------------------------------------------------
echo "questa_run: running $::RUN_TIME ..."
run $::RUN_TIME
echo "questa_run: finished at [format %d $now] (simulation time)"

#-----------------------------------------------------------------------------
# Report where the LTSSM ended up - this is what decides pass/fail by eye
#-----------------------------------------------------------------------------
proc q_report {} {
    foreach {label path} {
        "pl_linkUp    " /pcieTB/pl_linkUp
        "pl_speedmode " /pcieTB/pl_speedmode
        "pl_state_sts " /pcieTB/pl_state_sts
        "substateTx   " /pcieTB/pcie/mainltssm/substateTx
        "substateRx   " /pcieTB/pcie/mainltssm/substateRx
        "currentState " /pcieTB/pcie/mainltssm/currentState
        "GEN          " /pcieTB/pcie/mainltssm/GEN
        "txPollingDone" /pcieTB/pcie/mainltssm/txPollingDone
        "rxPollingDone" /pcieTB/pcie/mainltssm/rxPollingDone
    } {
        if {[catch {quietly set v [examine -radix unsigned $path]}]} {
            echo "  $label = <not visible>"
        } else {
            echo "  $label = $v"
        }
    }
}
echo "questa_run: LTSSM state at end of run"
catch {q_report}

#-----------------------------------------------------------------------------
# Persist the waveform database (batch mode: reopen later with
#   vsim -view sim/pcieTB.wlf   or   make wave-view)
#-----------------------------------------------------------------------------
if {[catch {write format wave -window .main_pane.wave -overwrite $::WLF_FILE} msg]} {
    # In -c (batch) mode there is no wave window; write the whole database.
    catch {write format wave -overwrite $::WLF_FILE}
}
if {[file exists $::WLF_FILE]} {
    echo "questa_run: waveform database written to $::WLF_FILE"
} else {
    echo "questa_run: NOTE - no waveform database written (no wave window in batch mode)."
    echo "questa_run:       use `make wave` for an interactive GUI run."
}
