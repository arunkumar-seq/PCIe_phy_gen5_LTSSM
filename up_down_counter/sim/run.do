# Invoked from up_down_counter/ by Makefile after loading tb_top.
# A watchdog, assertion, elaboration failure, or UVM error must fail automation.
onerror {quit -code 1 -force}
onbreak {quit -code 1 -force}
onfinish stop
log -r /tb_top/vif/*
run -all
if {[examine -radix unsigned /tb_top/test_passed] != 1} {
    quit -code 1 -force
}
quit -code 0 -force
