class counter_env extends uvm_env;
  `uvm_component_utils(counter_env)
  counter_agent agent;
  counter_scoreboard scoreboard;
  counter_coverage coverage;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = counter_agent::type_id::create("agent", this);
    scoreboard = counter_scoreboard::type_id::create("scoreboard", this);
    coverage = counter_coverage::type_id::create("coverage", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    agent.monitor.ap.connect(scoreboard.analysis_export);
    agent.monitor.ap.connect(coverage.analysis_export);
  endfunction
endclass
