class counter_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(counter_scoreboard)
  uvm_analysis_imp #(counter_item, counter_scoreboard) analysis_export;
  bit [WIDTH-1:0] expected;
  bit initialized;
  int unsigned checked, mismatches, up_cycles, down_cycles;
  integer trace_fd;
  string trace_path;
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!$value$plusargs("COUNTER_CSV=%s", trace_path))
      trace_path = "sim/build/counter_trace.csv";
    trace_fd = $fopen(trace_path, "w");
    if (!trace_fd) `uvm_fatal("TRACE_OPEN", $sformatf("Cannot open counter CSV: %s", trace_path))
    $fdisplay(trace_fd, "sample,time_ns,operation,rst_n,clear,load,enable,up,load_value,expected,actual,result");
    `uvm_info("TRACE_FILE", $sformatf("Cycle-by-cycle CSV: %s", trace_path), UVM_LOW)
  endfunction
  function new(string name, uvm_component parent);
    super.new(name, parent); analysis_export = new("analysis_export", this);
  endfunction
  function void write(counter_item tr);
    string operation;
    if (!tr.rst_n) operation = "RESET";
    else if (tr.clear) operation = "CLEAR";
    else if (tr.load) operation = "LOAD";
    else if (!tr.enable) operation = "HOLD";
    else if (tr.up) begin operation = "UP"; up_cycles++; end
    else begin operation = "DOWN"; down_cycles++; end
    if (!tr.rst_n || tr.clear) begin
      expected = '0;
      initialized = 1;
    end else if (tr.load) begin
      expected = tr.load_value;
      initialized = 1;
    end else if (initialized && tr.enable) begin
      if (tr.up) expected = expected + 1'b1;
      else       expected = expected - 1'b1;
    end
    if (!initialized) begin
      `uvm_error("UNINITIALIZED", "First sample must reset, clear, or load the counter")
      return;
    end
    checked++;
    // Package timescale is 1ns/1ps, so $realtime is expressed in ns here.
    $fdisplay(trace_fd, "%0d,%0.3f,%s,%b,%b,%b,%b,%b,%0d,%0d,%0d,%s",
      checked, $realtime, operation, tr.rst_n, tr.clear, tr.load,
      tr.enable, tr.up, tr.load_value, expected, tr.count,
      (tr.count === expected) ? "PASS" : "FAIL");
    $fflush(trace_fd);
    if (tr.count !== expected) begin
      mismatches++;
      `uvm_error("MISMATCH", $sformatf("sample=%0d rst_n=%b clear=%b load=%b en=%b up=%b load_value=0x%0h expected=0x%0h actual=0x%0h",
        checked, tr.rst_n, tr.clear, tr.load, tr.enable, tr.up, tr.load_value, expected, tr.count))
    end
  endfunction
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (checked == 0) `uvm_error("NO_TRAFFIC", "No samples checked")
  endfunction
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCOREBOARD", $sformatf("Checked %0d samples; mismatches=%0d; UP cycles=%0d; DOWN cycles=%0d", checked, mismatches, up_cycles, down_cycles), UVM_LOW)
  endfunction
  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (trace_fd) $fclose(trace_fd);
  endfunction
endclass
