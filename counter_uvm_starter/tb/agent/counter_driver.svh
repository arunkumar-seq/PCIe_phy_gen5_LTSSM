class counter_driver extends uvm_driver #(counter_item);
  `uvm_component_utils(counter_driver)
  virtual counter_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual counter_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Driver needs a virtual interface")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req); // Wait for a sequence request.
      @(vif.drv_cb);                    // Drive on falling edge.
      vif.drv_cb.rst_n <= req.rst_n;
      vif.drv_cb.enable <= req.enable;
      vif.drv_cb.up <= req.up;
      vif.drv_cb.valid <= 1;
      @(vif.mon_cb);                    // Allow DUT rising edge to complete.
      seq_item_port.item_done();        // Release sequence handshake.
    end
  endtask
endclass
