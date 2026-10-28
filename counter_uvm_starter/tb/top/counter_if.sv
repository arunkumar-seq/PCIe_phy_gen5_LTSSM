`timescale 1ns/1ps
// Only the controls used by this lesson are brought into the interface.
interface counter_if(input logic clk);
  logic rst_n = 0;
  logic enable = 0;
  logic up = 1;
  logic [7:0] count;
  logic valid = 0; // Testbench marker, NOT a DUT input.

  clocking drv_cb @(negedge clk);
    default output #0;
    output rst_n, enable, up, valid;
  endclocking
  // Observe the result after the DUT's nonblocking assignments.
  clocking mon_cb @(posedge clk);
    default input #0;
    input rst_n, enable, up, count, valid;
  endclocking
endinterface
