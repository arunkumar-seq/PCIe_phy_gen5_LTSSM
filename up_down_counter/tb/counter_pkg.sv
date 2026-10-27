`timescale 1ns/1ps
`ifndef COUNTER_WIDTH
  `define COUNTER_WIDTH 8
`endif
package counter_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  parameter int WIDTH = `COUNTER_WIDTH;
  parameter bit [WIDTH-1:0] MAX_COUNT = {WIDTH{1'b1}};
  `include "agent/counter_item.svh"
  `include "agent/counter_sequencer.svh"
  `include "agent/counter_driver.svh"
  `include "agent/counter_monitor.svh"
  `include "agent/counter_agent.svh"
  `include "env/counter_scoreboard.svh"
  `include "env/counter_coverage.svh"
  `include "env/counter_env.svh"
  `include "sequences/counter_sequences.svh"
  `include "tests/counter_tests.svh"
endpackage
