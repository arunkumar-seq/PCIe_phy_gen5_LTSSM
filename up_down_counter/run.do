# Windows/Linux native Questa flow. No make or shell is required.
# GUI Transcript: set UVM_HOME {C:/tools/uvm-1.2}; set GUI_MODE 1; do run.do
# Batch CMD:     set "UVM_HOME=C:\tools\uvm-1.2"  then run.bat
# Optional Tcl variables: TEST, WIDTH, SEED, NUM_ITEMS, GUI_MODE.
set PROJECT_ROOT [file normalize [file dirname [info script]]]
cd $PROJECT_ROOT
foreach {name default} {TEST counter_base_test WIDTH 8 SEED 1 NUM_ITEMS 1000 GUI_MODE 0} {
    if {![info exists $name]} {set $name $default}
}
if {![info exists UVM_HOME] && [info exists env(UVM_HOME)]} {
    set UVM_HOME $env(UVM_HOME)
}
if {![info exists UVM_HOME]} {
    # Typical Questa installation: win64/vsim.exe beside verilog_src/uvm-1.2.
    set candidate [file normalize [file join [file dirname [info nameofexecutable]] .. verilog_src uvm-1.2]]
    if {[file exists [file join $candidate src uvm_pkg.sv]]} {set UVM_HOME $candidate}
}
if {![info exists UVM_HOME] || ![file exists [file join $UVM_HOME src uvm_pkg.sv]]} {
    puts stderr "ERROR: Set UVM_HOME to the UVM source folder containing src/uvm_pkg.sv."
    puts stderr {Example: set UVM_HOME {C:/questasim64_2024.3/verilog_src/uvm-1.2}}
    if {!$GUI_MODE} {quit -code 1 -force}
    return
}
if {![string is integer -strict $WIDTH] || $WIDTH < 2 ||
    ![string is integer -strict $NUM_ITEMS] || $NUM_ITEMS < 1} {
    puts stderr "ERROR: WIDTH must be >= 2; NUM_ITEMS must be >= 1."
    if {!$GUI_MODE} {quit -code 1 -force}
    return
}
set BUILD [file join $PROJECT_ROOT sim build]
set WORK [file join $BUILD work]
file mkdir $BUILD
set RUN_NAME ${TEST}_seed${SEED}
set TRACE [file join $BUILD ${RUN_NAME}_counter.csv]
set WAVEFILE [file join $BUILD ${RUN_NAME}.wlf]
# Explicit transcript selection works when this script is sourced in an open GUI.
transcript file [file join $BUILD ${RUN_NAME}.log]
transcript on
puts "Selected test=$TEST width=$WIDTH seed=$SEED random_items=$NUM_ITEMS"
puts "Run files: [file join $BUILD $RUN_NAME].log / .wlf / _counter.csv"
if {[catch {
    if {![file isdirectory $WORK]} {vlib $WORK}
    set args [list -sv -timescale 1ns/1ps -work $WORK +define+UVM_NO_DPI \
        +define+COUNTER_WIDTH=$WIDTH "+incdir+[file join $PROJECT_ROOT tb]" \
        "+incdir+[file join $UVM_HOME src]" [file join $UVM_HOME src uvm_pkg.sv]]
    foreach source {rtl/up_down_counter.sv tb/top/counter_if.sv tb/counter_pkg.sv tb/top/tb_top.sv} {
        lappend args [file join $PROJECT_ROOT $source]
    }
    vlog {*}$args
    vsim -voptargs=+acc -lib $WORK tb_top -sv_seed $SEED \
        +UVM_TESTNAME=$TEST +NUM_ITEMS=$NUM_ITEMS \
        "+COUNTER_CSV=$TRACE" -wlf $WAVEFILE
} message]} {
    puts stderr "BUILD/LOAD FAILED: $message"
    if {!$GUI_MODE} {quit -code 1 -force}
    return
}
# Record from time zero, including batch mode, for later waveform debugging.
log -r /tb_top/vif/*
if {$GUI_MODE} {
    onfinish stop
    add wave -radix unsigned /tb_top/vif/count /tb_top/vif/load_value
    add wave /tb_top/vif/clk /tb_top/vif/rst_n /tb_top/vif/clear /tb_top/vif/load /tb_top/vif/enable /tb_top/vif/up
    run -all
    wave zoom full
    puts "Simulation stopped. Review the UVM summary and /tb_top/test_passed (1 means PASS)."
} else {
    do [file join $PROJECT_ROOT sim run.do]
}
