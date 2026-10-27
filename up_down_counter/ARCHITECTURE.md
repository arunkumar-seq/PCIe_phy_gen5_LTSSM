# Source organization and runtime UVM hierarchy

## Downloaded source tree

```text
up_down_counter/
  README.md
  ARCHITECTURE.md
  run.bat                   Windows single-test launcher
  regression.bat            Windows all-tests launcher
  run.do                    Native Questa compile/load/run entry (GUI or batch)
  Makefile                  Optional Linux flow
  rtl/
    up_down_counter.sv
  tb/
    counter_pkg.sv          Class compilation package
    top/
      counter_if.sv        Virtual-interface type and clocking blocks
      tb_top.sv            Static HDL root, clock, DUT and UVM startup
    agent/
      counter_item.svh     Transaction object
      counter_sequencer.svh
      counter_driver.svh
      counter_monitor.svh
      counter_agent.svh
    sequences/
      counter_sequences.svh
    env/
      counter_scoreboard.svh
      counter_coverage.svh
      counter_env.svh
    tests/
      counter_tests.svh
    rtl_smoke/
      counter_rtl_smoke.sv  Independent non-UVM sanity test
  sim/
    run.do                 Batch result/exit-status helper
    build/                 Generated locally; not included in download
  docs/
    Counter_UVM_Beginners_Guide.docx
```

## Runtime components (created by UVM factory)

```text
uvm_root
  uvm_test_top : selected test extends counter_base_test
    env : counter_env
      agent : counter_agent
        sequencer : counter_sequencer  [active mode only]
        driver    : counter_driver     [active mode only]
        monitor   : counter_monitor    [always present]
      scoreboard : counter_scoreboard
      coverage   : counter_coverage
```

## Static HDL hierarchy (elaborated by the simulator)

```text
tb_top
  clk       generated clock
  vif       counter_if #(WIDTH)
  dut       up_down_counter #(WIDTH)
```

Sequence and transaction **objects are not components**: they do not appear as
children in this UVM component tree. `counter_pkg` is a compilation namespace,
not an instance. `counter_if` is a static interface; its virtual handle is passed
through the config DB to class-based components.

## Dataflow

```text
test -> sequence -> sequencer -> driver -> vif pins -> DUT
                                             ^         |
                                             |         v
                              monitor <- vif sampled pins
                                |
                                +-- analysis --> scoreboard
                                +-- analysis --> coverage
```

Compile order: UVM package, DUT RTL, interface, counter package, tb_top.
The package includes class headers in dependency order. Never compile those
`.svh` headers again as independent files. The smoke test is a separate top;
do not add it to the UVM run.
