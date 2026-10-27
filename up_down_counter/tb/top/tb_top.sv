`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import counter_pkg::*;
  bit clk=0;
  bit test_passed=0;
  always #5 clk=~clk;
  counter_if #(WIDTH) vif(clk);
  up_down_counter #(.WIDTH(WIDTH)) dut (
    .clk(clk), .rst_n(vif.rst_n), .clear(vif.clear), .load(vif.load),
    .enable(vif.enable), .up(vif.up), .load_value(vif.load_value), .count(vif.count)
  );
  initial begin
    if (WIDTH < 2) $fatal(1, "UVM environment requires WIDTH >= 2");
    uvm_config_db#(virtual counter_if #(WIDTH))::set(null, "uvm_test_top*", "vif", vif);
    // Retain control after UVM report phase so CI can inspect an explicit result.
    uvm_top.finish_on_completion = 0;
    run_test();
    begin
      uvm_report_server reports;
      reports = uvm_report_server::get_server();
      test_passed = (reports.get_severity_count(UVM_ERROR) == 0 &&
                     reports.get_severity_count(UVM_FATAL) == 0);
    end
    $finish;
  end
  // Independent watchdog prevents a hung sequencer/objection from running forever.
  initial begin
    #10ms;
    $fatal(1, "Simulation watchdog expired");
  end
endmodule
