class counter_agent extends uvm_agent;
  `uvm_component_utils(counter_agent)
  counter_sequencer sequencer;
  counter_driver driver;
  counter_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = counter_sequencer::type_id::create("sequencer", this);
    driver = counter_driver::type_id::create("driver", this);
    monitor = counter_monitor::type_id::create("monitor", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
