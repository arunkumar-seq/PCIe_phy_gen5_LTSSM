`timescale 1ns/1ps
interface counter_if #(parameter int WIDTH = 8) (input logic clk);
  logic rst_n = 1'b0;
  logic clear = 0, load = 0, enable = 0, up = 1;
  logic [WIDTH-1:0] load_value = '0;
  logic [WIDTH-1:0] count;
  logic valid = 0; // Testbench-only marker; not a DUT port.

  // Drive half a cycle ahead of the active DUT edge.
  clocking drv_cb @(negedge clk);
    default output #0;
    output rst_n, clear, load, enable, up, load_value, valid;
  endclocking
  // #0 samples in the observed region, after DUT nonblocking updates.
  clocking mon_cb @(posedge clk);
    default input #0;
    input rst_n, clear, load, enable, up, load_value, count, valid;
  endclocking
endinterface
