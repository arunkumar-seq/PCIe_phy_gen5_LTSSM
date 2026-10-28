`timescale 1ns/1ps
module tb_top;
  import uvm_pkg::*;
  import counter_pkg::*;
  bit clk = 0;
  bit test_passed = 0;
  always #5 clk = ~clk; // 10 ns period.
  counter_if vif(clk);

  // SAME RTL as the full project. This lesson only exercises reset/en/up.
  up_down_counter #(.WIDTH(8)) dut (
    .clk(clk), .rst_n(vif.rst_n), .enable(vif.enable), .up(vif.up),
    .clear(1'b0), .load(1'b0), .load_value(8'd0), .count(vif.count)
  );

  initial begin
    uvm_report_server reports;
    uvm_config_db#(virtual counter_if)::set(null, "uvm_test_top.env.agent.*", "vif", vif);
    uvm_top.finish_on_completion = 0;
    run_test("counter_directed_test"); // The only test in this starter.
    reports = uvm_report_server::get_server();
    test_passed = (reports.get_severity_count(UVM_ERROR) == 0 &&
                   reports.get_severity_count(UVM_FATAL) == 0);
    $finish;
  end

  initial begin
    #10us;
    $fatal(1, "Watchdog: directed test did not finish");
  end
endmodule
