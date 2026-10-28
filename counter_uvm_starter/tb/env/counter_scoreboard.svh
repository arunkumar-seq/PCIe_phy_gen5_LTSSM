class counter_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(counter_scoreboard)
  uvm_analysis_imp #(counter_item, counter_scoreboard) analysis_export;
  bit [7:0] expected = 0;
  bit saw_reset = 0;
  int samples = 0;
  int up_cycles = 0;
  int down_cycles = 0;
  int mismatches = 0;
  integer csv;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    analysis_export = new("analysis_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    csv = $fopen("sim/counter.csv", "w");
    if (!csv) `uvm_fatal("CSV", "Cannot open sim/counter.csv; use root run.do")
    $fdisplay(csv, "sample,time_ns,operation,enable,up,expected,actual,result");
  endfunction

  // Called for every monitored cycle through the analysis connection.
  function void write(counter_item item);
    string operation;
    if (!item.rst_n) begin
      expected = 0;
      saw_reset = 1;
      operation = "RESET";
    end else if (!item.enable) begin
      operation = "HOLD"; // Keep previous expected value.
    end else if (item.up) begin
      expected = expected + 1'b1;
      up_cycles++;
      operation = "UP";
    end else begin
      expected = expected - 1'b1;
      down_cycles++;
      operation = "DOWN";
    end
    if (!saw_reset) `uvm_error("RESET", "First observed cycle must reset the DUT")
    samples++;
    if (item.count !== expected) begin
      mismatches++;
      `uvm_error("MISMATCH", $sformatf("expected=%0d actual=%0d", expected, item.count))
    end
    `uvm_info("COUNTER", $sformatf("cycle=%0d %-5s expected=%0d actual=%0d %s",
      samples, operation, expected, item.count,
      (item.count === expected) ? "PASS" : "FAIL"), UVM_LOW)
    $fdisplay(csv, "%0d,%0.3f,%s,%b,%b,%0d,%0d,%s", samples, $realtime,
      operation, item.enable, item.up, expected, item.count,
      (item.count === expected) ? "PASS" : "FAIL");
    $fflush(csv);
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    // This starter intentionally verifies ONE exact 23-cycle scenario.
    if (samples != 23 || up_cycles != 12 || down_cycles != 6)
      `uvm_error("TRAFFIC", $sformatf("Need 23 samples, 12 UP, 6 DOWN; got %0d, %0d, %0d",
        samples, up_cycles, down_cycles))
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SUMMARY", $sformatf("samples=%0d UP=%0d DOWN=%0d mismatches=%0d",
      samples, up_cycles, down_cycles, mismatches), UVM_LOW)
  endfunction

  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (csv) $fclose(csv);
  endfunction
endclass
