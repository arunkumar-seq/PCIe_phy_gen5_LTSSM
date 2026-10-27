class counter_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(counter_scoreboard)
  uvm_analysis_imp #(counter_item, counter_scoreboard) analysis_export;
  bit [WIDTH-1:0] expected;
  bit initialized;
  int unsigned checked, mismatches;
  function new(string name, uvm_component parent);
    super.new(name, parent); analysis_export = new("analysis_export", this);
  endfunction
  function void write(counter_item tr);
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
    `uvm_info("SCOREBOARD", $sformatf("Checked %0d samples; mismatches=%0d", checked, mismatches), UVM_LOW)
  endfunction
endclass
