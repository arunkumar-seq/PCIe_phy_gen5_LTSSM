`timescale 1ns/1ps
package counter_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  // Dependency order: data -> agent children -> agent -> env -> sequence/test.
  `include "agent/counter_item.svh"
  `include "agent/counter_sequencer.svh"
  `include "agent/counter_driver.svh"
  `include "agent/counter_monitor.svh"
  `include "agent/counter_agent.svh"
  `include "env/counter_scoreboard.svh"
  `include "env/counter_env.svh"
  `include "sequences/counter_directed_seq.svh"
  `include "tests/counter_directed_test.svh"
endpackage
