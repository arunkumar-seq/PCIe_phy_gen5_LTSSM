class counter_monitor extends uvm_monitor;
  `uvm_component_utils(counter_monitor)
  virtual counter_if vif;
  uvm_analysis_port #(counter_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Monitor needs a virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    counter_item observed;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.valid === 1'b1) begin
        observed = counter_item::type_id::create("observed");
        observed.rst_n = vif.mon_cb.rst_n;
        observed.enable = vif.mon_cb.enable;
        observed.up = vif.mon_cb.up;
        observed.count = vif.mon_cb.count;
        ap.write(observed); // Publish ACTUAL pin observations.
      end
    end
  endtask
endclass
