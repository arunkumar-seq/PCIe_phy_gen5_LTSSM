class counter_directed_test extends uvm_test;
  `uvm_component_utils(counter_directed_test)
  counter_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = counter_env::type_id::create("env", this);
  endfunction

  task run_phase(uvm_phase phase);
    counter_directed_seq sequence_under_test;
    phase.raise_objection(this);
    sequence_under_test = counter_directed_seq::type_id::create("sequence_under_test");
    sequence_under_test.start(env.agent.sequencer);
    // Driver completes at the last sampled edge. Give all monitor callbacks
    // time to finish, without adding another clock/sample to this exact test.
    #1ns;
    phase.drop_objection(this);
  endtask
endclass
