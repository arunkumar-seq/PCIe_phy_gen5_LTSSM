# Counter UVM starter kit — one directed test

A small, standalone learning project using the **same unmodified RTL** as the
full `up_down_counter/` project. Start here before studying the full environment.

## What this lesson does (and does not do)

The DUT is fixed to **8 bits** in this testbench. There is exactly one sequence
and one test, with no randomized fields, constraints, coverage, passive-mode
configuration or generated test macros. Each UVM class has its own readable file.

The one directed scenario is:

| Samples | Controls | Count after each rising edge |
| --- | --- | --- |
| 1–2 | Reset asserted | 0, 0 |
| 3 | Reset released, disabled | 0 |
| 4–15 | Enabled, UP | 1, 2, 3, ..., 12 |
| 16–21 | Enabled, DOWN | 11, 10, 9, 8, 7, 6 |
| 22–23 | Disabled | 6, 6 |

The scoreboard compares every sample and requires exactly **23 checked samples,
12 UP cycles and 6 DOWN cycles**. It reports mismatches and makes batch runs
fail if UVM errors/fatals occur. These expected counts are deliberately tied to
this single lesson; update the scoreboard's traffic check when extending it.

This is the simple up/down ramp discussed previously, **not** the full project's
longer directed sequence with load, clear and reversals. Clear and load are tied
to zero in `tb_top`; this starter does not verify those features, priority,
wraparound, random traffic, or reset assertion between active clock edges. Use
the full environment for those topics. No coverage-closure claim is made.

## 1. Runtime hierarchy

```text
tb_top                         static HDL root
  vif : counter_if             signals + clocking blocks
  dut : up_down_counter        original RTL, WIDTH=8

uvm_test_top : counter_directed_test
  env : counter_env
    agent : counter_agent
      sequencer : counter_sequencer
      driver    : counter_driver
      monitor   : counter_monitor
    scoreboard : counter_scoreboard
```

Sequence and item are **objects**, not component-tree children:

```text
test starts sequence -> sequence sends item -> sequencer -> driver -> DUT pins
                                                                |
monitor samples actual controls/count <--------------------------+
  -> analysis port -> scoreboard (predict, compare, print, save CSV)
```

## 2. File map and recommended reading order

| Read | File | Responsibility |
| --- | --- | --- |
| 1 | `rtl/up_down_counter.sv` | Register, reset and control priority; unchanged from full project |
| 2 | `tb/top/counter_if.sv` | Only rst_n, enable, up, count and valid; pin timing |
| 3 | `tb/agent/counter_item.svh` | Three stimulus fields plus monitored count |
| 4 | `tb/sequences/counter_directed_seq.svh` | Explicit 23-cycle scenario; no randomization |
| 5 | `tb/agent/counter_sequencer.svh` | Typed sequence/driver handshake |
| 6 | `tb/agent/counter_driver.svh` | Item fields to actual pins |
| 7 | `tb/agent/counter_monitor.svh` | Actual pins to a fresh observation object |
| 8 | `tb/env/counter_scoreboard.svh` | Independent expected count, comparison and CSV |
| 9 | `tb/agent/counter_agent.svh` | Groups driver, sequencer and monitor; always active |
| 10 | `tb/env/counter_env.svh` | Creates agent/scoreboard and connects analysis port |
| 11 | `tb/tests/counter_directed_test.svh` | Starts the only sequence and controls objection |
| 12 | `tb/counter_pkg.sv` | Imports UVM and includes classes in dependency order |
| 13 | `tb/top/tb_top.sv` | Clock, interface, DUT, config DB and run_test |
| 14 | `run.do`, `run.bat` | Native Questa compile/load/run and Windows launcher |

## 3. Important UVM concepts used here

- **Factory**: `type_id::create` constructs registered classes. The UVM utils
  macro registers each type; no field-automation macros are needed here.
- **build_phase**: creates components or gets the virtual-interface handle.
- **connect_phase**: connects driver to sequencer and monitor to scoreboard.
- **run_phase**: tasks that consume simulation time (clocks and stimulus).
- **Virtual interface**: a class reference to the existing `vif`, not a new
  instance. `uvm_config_db` distributes it from tb_top to driver/monitor.
- **Handshake**: sequence calls start_item/finish_item; driver calls
  get_next_item/item_done. Each request lasts one active DUT edge.
- **Analysis port**: monitor broadcasts actual observations. The scoreboard
  does not use the driver's request as its expected response.
- **Objection**: the test keeps the run phase alive while the sequence runs.
  A 1 ns drain lets the final monitor callback finish without another sample.
- **Checking**: the reference state increments/decrements independently;
  `!==` flags X/Z as well as incorrect values. check_phase verifies traffic.

### Why two clock edges?

Clock period is 10 ns. Driver changes pins at the falling edge; DUT updates at
the rising edge. Monitor input `#0` intentionally samples in the Observed region,
after the DUT's nonblocking assignments. It sees the result of that same edge.
Do not switch the monitor to `#1step` without redesigning scoreboard timing.
`valid` excludes the initial idle edge; it is not connected to the DUT.

## 4. Windows Questa GUI: compile, run and see waves

Requirements: licensed UVM-capable Questa/ModelSim, with class/constraint support
for the UVM library. No GNU make or bash is needed. UVM is not bundled; point to
an installed UVM source root containing `src/uvm_pkg.sv` (UVM 1.2 recommended).

Extract this folder, launch Questa, and enter in the **Transcript** (replace
example paths with your own):

```tcl
cd {C:/DV/counter_uvm_starter}
set UVM_HOME {C:/questasim64_2024.3/verilog_src/uvm-1.2}
set GUI_MODE 1
do run.do
```

The script compiles local UVM sources with `UVM_NO_DPI`, RTL, interface, package
and top; loads the one test; records waves; and runs. Do not compile `.svh`
headers separately. Do not compile the full project in this work library.

The Wave window displays count as unsigned. Use Zoom Full if needed:

```tcl
wave zoom full
examine -radix unsigned /tb_top/test_passed
```

Expected `test_passed` is 1. Look around 45–155 ns for 1 through 12, then around
165–215 ns for 11 through 6. The test should finish around 236 ns. These are
predicted timings, not a captured simulation result. Before recompiling in the
same GUI session, enter `quit -sim`, then `do run.do` again.

## 5. Windows Command Prompt: batch run

```bat
cd /d C:\DV\counter_uvm_starter
set "PATH=C:\questasim64_2024.3\win64;%PATH%"
set "UVM_HOME=C:\questasim64_2024.3\verilog_src\uvm-1.2"
run.bat
```

There are no test, width or random-count arguments: the starter has only one
fixed scenario. Batch returns a nonzero status on error.

## 6. Readable outputs

Generated files are in this starter's own `sim/` directory:

- `sim/run.log`: transcript, each checked cycle and final UVM summary.
- `sim/counter.csv`: per-cycle table for Excel or a text editor.
- `sim/counter.wlf`: waveform database for Questa.
- `sim/work/`: generated compiled library.

CSV columns: sample, time_ns, operation, enable, up, expected, actual, result.
Example expected rows (illustration only):

```text
4,45.000,UP,1,1,1,1,PASS
15,155.000,UP,1,1,12,12,PASS
16,165.000,DOWN,1,0,11,11,PASS
21,215.000,DOWN,1,0,6,6,PASS
```

A clean run should report `samples=23 UP=12 DOWN=6 mismatches=0`, with
`UVM_ERROR : 0` and `UVM_FATAL : 0`. Repeated runs replace the CSV/WLF; preserve
previous outputs if needed. The script sets the working directory so paths are
predictable and explicitly selects the transcript file.

## 7. Simple learning exercises

1. Follow one item from send_cycle through driver to monitor and scoreboard.
2. Change the sequence to 8 UP and 4 DOWN cycles. Update the exact traffic
   check accordingly; predict the final count before running.
3. Intentionally reverse the RTL direction in a local copy. Confirm the
   scoreboard reports a mismatch, then restore the correct RTL.
4. Only after this lesson, add load/clear fields and their reference-model
   priority using the full project as a reference.

## Validation

RTL is byte-for-byte identical to the full project's RTL. Static compilation
and elaboration of this starter passed with pyslang 12.1.0 against Accellera UVM
1.2 (zero errors; two warnings in upstream UVM empty-loop bodies).
No HDL simulator is installed in the development sandbox, so Windows Questa
execution, actual log creation and waveform results remain for local validation.
