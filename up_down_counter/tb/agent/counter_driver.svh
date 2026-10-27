class counter_driver extends uvm_driver #(counter_item);
  `uvm_component_utils(counter_driver)
  virtual counter_if #(WIDTH) vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual counter_if #(WIDTH))::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Driver interface not configured")
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      @(vif.drv_cb);
      vif.drv_cb.valid      <= 1;
      vif.drv_cb.rst_n      <= req.rst_n;
      vif.drv_cb.clear      <= req.clear;
      vif.drv_cb.load       <= req.load;
      vif.drv_cb.enable     <= req.enable;
      vif.drv_cb.up         <= req.up;
      vif.drv_cb.load_value <= req.load_value;
      @(vif.mon_cb);
      seq_item_port.item_done();
    end
  endtask
endclass
