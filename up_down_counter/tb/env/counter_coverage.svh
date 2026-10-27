class counter_coverage extends uvm_subscriber #(counter_item);
  `uvm_component_utils(counter_coverage)
  bit [WIDTH-1:0] previous;
  bit have_previous;
  // op: reset, clear, load, hold, up, down. Wrap bins use previous count.
  covergroup cg with function sample(int op, bit direction, bit en,
                                    bit clr, bit ld, bit reset,
                                    bit [WIDTH-1:0] value, int wrap);
    option.per_instance = 1;
    operation: coverpoint op { bins reset_op={0}; bins clear_op={1};
      bins load_op={2}; bins hold_op={3}; bins up_op={4}; bins down_op={5}; }
    count_value: coverpoint value {
      bins zero={'0}; bins maximum={MAX_COUNT}; bins interior={[1:MAX_COUNT-1]};
    }
    wrap_event: coverpoint wrap { bins up_wrap={1}; bins down_wrap={2}; ignore_bins none={0}; }
    dir_cp: coverpoint direction;
    en_cp: coverpoint en;
    clear_cp: coverpoint clr;
    load_cp: coverpoint ld;
    reset_cp: coverpoint reset;
    direction_enable: cross dir_cp, en_cp;
    clear_load: cross clear_cp, load_cp;
    reset_load: cross reset_cp, load_cp;
  endgroup
  function new(string name, uvm_component parent);
    super.new(name, parent); cg = new;
  endfunction
  function void write(counter_item t);
    int op, wrap;
    if (!t.rst_n) op=0;
    else if (t.clear) op=1;
    else if (t.load) op=2;
    else if (!t.enable) op=3;
    else if (t.up) op=4;
    else op=5;
    wrap=0;
    if (have_previous && op==4 && previous==MAX_COUNT) wrap=1;
    if (have_previous && op==5 && previous=='0) wrap=2;
    cg.sample(op, t.up, t.enable, t.clear, t.load, !t.rst_n, t.count, wrap);
    previous=t.count; have_previous=1;
  endfunction
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COVERAGE", $sformatf("Functional coverage: %0.2f%%", cg.get_inst_coverage()), UVM_LOW)
  endfunction
endclass
