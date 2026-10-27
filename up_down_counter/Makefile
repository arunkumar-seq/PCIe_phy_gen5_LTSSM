SHELL := /bin/bash
.DEFAULT_GOAL := help
VLIB ?= vlib
VLOG ?= vlog
VSIM ?= vsim
IVERILOG ?= iverilog
VVP ?= vvp
WIDTH ?= 8
TEST ?= counter_base_test
SEED ?= 1
NUM_ITEMS ?= 1000
# UVM source is compiled locally, avoiding vendor-specific library mappings/DPI.
# Set UVM_HOME explicitly, or set QUESTA_HOME to the simulator install root.
UVM_HOME ?= $(if $(QUESTA_HOME),$(QUESTA_HOME)/verilog_src/uvm-1.2,)
BUILD := sim/build
SOURCES := rtl/up_down_counter.sv tb/top/counter_if.sv tb/counter_pkg.sv tb/top/tb_top.sv
TESTS := counter_reset_test counter_directed_test counter_wrap_test counter_random_test counter_base_test
.PHONY: help compile run regression smoke clean
help:
	@echo 'make run [TEST=counter_base_test SEED=1 WIDTH=8 NUM_ITEMS=1000]'
	@echo 'make regression   # five UVM tests, independent logs and failure exit codes'
	@echo 'make smoke        # standalone RTL test using Icarus; no UVM required'
	@echo 'make clean        # remove only generated simulation build files'
compile:
	@test -n "$(UVM_HOME)" -a -f "$(UVM_HOME)/src/uvm_pkg.sv" || { echo 'Set UVM_HOME to a UVM 1.2 (or IEEE UVM) source directory containing src/uvm_pkg.sv'; exit 1; }
	@mkdir -p $(BUILD)
	@test -d $(BUILD)/work || $(VLIB) $(BUILD)/work
	$(VLOG) -sv -timescale 1ns/1ps -work $(BUILD)/work +define+UVM_NO_DPI +define+COUNTER_WIDTH=$(WIDTH) +incdir+tb +incdir+$(UVM_HOME)/src $(UVM_HOME)/src/uvm_pkg.sv $(SOURCES)
run: compile
	$(VSIM) -c -lib $(BUILD)/work tb_top -sv_seed $(SEED) +UVM_TESTNAME=$(TEST) +NUM_ITEMS=$(NUM_ITEMS) -l $(BUILD)/$(TEST)_seed$(SEED).log -do sim/run.do
regression: compile
	@set -e; for test in $(TESTS); do \
	  $(VSIM) -c -lib $(BUILD)/work tb_top -sv_seed $(SEED) \
	    +UVM_TESTNAME=$$test +NUM_ITEMS=$(NUM_ITEMS) \
	    -l $(BUILD)/$${test}_seed$(SEED).log -do sim/run.do; \
	done
smoke:
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -s counter_rtl_smoke -Pcounter_rtl_smoke.WIDTH=$(WIDTH) -o $(BUILD)/smoke.vvp rtl/up_down_counter.sv tb/rtl_smoke/counter_rtl_smoke.sv
	$(VVP) $(BUILD)/smoke.vvp
clean:
	rm -rf $(BUILD)
