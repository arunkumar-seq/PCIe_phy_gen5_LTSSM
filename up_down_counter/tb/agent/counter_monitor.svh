class counter_monitor extends uvm_monitor;
  `uvm_component_utils(counter_monitor)
  virtual counter_if #(WIDTH) vif;
  uvm_analysis_port #(counter_item) ap;
  function new(string name, uvm_component parent);
    super.new(name, parent); ap = new("ap", this);
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual counter_if #(WIDTH))::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Monitor interface not configured")
  endfunction
  task run_phase(uvm_phase phase);
    counter_item tr;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid === 1'b1) begin
        tr = counter_item::type_id::create("tr");
        tr.rst_n = vif.mon_cb.rst_n;
        tr.clear = vif.mon_cb.clear;
        tr.load = vif.mon_cb.load;
        tr.enable = vif.mon_cb.enable;
        tr.up = vif.mon_cb.up;
        tr.load_value = vif.mon_cb.load_value;
        tr.count = vif.mon_cb.count;
        ap.write(tr);
      end
    end
  endtask
endclass
