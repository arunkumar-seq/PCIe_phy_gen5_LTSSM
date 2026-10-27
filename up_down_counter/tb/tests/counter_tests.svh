class counter_base_test extends uvm_test;
  `uvm_component_utils(counter_base_test)
  counter_env env;
  virtual counter_if #(WIDTH) vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env=counter_env::type_id::create("env", this);
    if (!uvm_config_db#(virtual counter_if #(WIDTH))::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Test interface not configured")
  endfunction
  virtual task run_sequences();
    counter_reset_seq r=counter_reset_seq::type_id::create("reset_seq");
    counter_directed_seq d=counter_directed_seq::type_id::create("directed_seq");
    counter_wrap_seq w=counter_wrap_seq::type_id::create("wrap_seq");
    counter_random_seq s=counter_random_seq::type_id::create("random_seq");
    r.start(env.agent.sequencer);
    d.start(env.agent.sequencer);
    w.start(env.agent.sequencer);
    s.start(env.agent.sequencer);
  endtask
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_sequences();
    // Drain monitor/analysis callbacks for the last driven transaction.
    repeat (2) @(vif.mon_cb);
    phase.drop_objection(this);
  endtask
endclass

`define COUNTER_TEST(CLASS, SEQ) class CLASS extends counter_base_test;   `uvm_component_utils(CLASS)   function new(string name, uvm_component parent); super.new(name,parent); endfunction   virtual task run_sequences();     SEQ s=SEQ::type_id::create("seq");     s.start(env.agent.sequencer);   endtask endclass

`COUNTER_TEST(counter_reset_test, counter_reset_seq)
`COUNTER_TEST(counter_directed_test, counter_directed_seq)
`COUNTER_TEST(counter_wrap_test, counter_wrap_seq)
`COUNTER_TEST(counter_random_test, counter_random_seq)
`undef COUNTER_TEST
