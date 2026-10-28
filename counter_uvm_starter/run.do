# Run inside Questa GUI: set GUI_MODE 1; set UVM_HOME {...}; do run.do
# Batch: run.bat (UVM_HOME environment variable must be set).
set ROOT [file normalize [file dirname [info script]]]
cd $ROOT
if {![info exists GUI_MODE]} {set GUI_MODE 0}
if {![info exists UVM_HOME] && [info exists env(UVM_HOME)]} {
    set UVM_HOME $env(UVM_HOME)
}
if {![info exists UVM_HOME] || ![file exists [file join $UVM_HOME src uvm_pkg.sv]]} {
    puts stderr {Set UVM_HOME to a UVM source root, e.g. set UVM_HOME {C:/questa/verilog_src/uvm-1.2}}
    if {!$GUI_MODE} {quit -code 1 -force}
    return
}
file mkdir sim
transcript file [file join $ROOT sim run.log]
transcript on
if {[catch {
    if {![file isdirectory sim/work]} {vlib sim/work}
    vlog -sv -timescale 1ns/1ps -work sim/work +define+UVM_NO_DPI \
        "+incdir+[file join $UVM_HOME src]" "+incdir+[file join $ROOT tb]" \
        [file join $UVM_HOME src uvm_pkg.sv] \
        rtl/up_down_counter.sv tb/top/counter_if.sv tb/counter_pkg.sv tb/top/tb_top.sv
    vsim -voptargs=+acc -lib sim/work tb_top -wlf sim/counter.wlf
} message]} {
    puts stderr "Compile/load failed: $message"
    if {!$GUI_MODE} {quit -code 1 -force}
    return
}
# Set explicitly after load as well, so an existing GUI captures this run.
transcript file [file join $ROOT sim run.log]
transcript on
onfinish stop
log -r /tb_top/vif/*
if {$GUI_MODE} {
    add wave /tb_top/vif/clk /tb_top/vif/rst_n /tb_top/vif/enable /tb_top/vif/up
    add wave -radix unsigned /tb_top/vif/count
    run -all
    wave zoom full
    puts "Check test_passed and sim/run.log; per-cycle view is sim/counter.csv."
} else {
    onerror {quit -code 1 -force}
    onbreak {quit -code 1 -force}
    run -all
    if {[examine -radix unsigned /tb_top/test_passed] != 1} {quit -code 1 -force}
    quit -code 0 -force
}
