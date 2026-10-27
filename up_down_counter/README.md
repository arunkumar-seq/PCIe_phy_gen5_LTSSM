# Up/down counter: RTL + complete UVM example

A standalone DV training project. It does **not** replace or depend on the PCIe
RTL/testbench elsewhere in this repository. Run the commands below from this
`up_down_counter/` directory, not the repository root.

## DUT specification

`rtl/up_down_counter.sv` is a synthesizable single-clock counter. No other RTL
blocks are necessary. Default width is 8 bits; arithmetic wraps modulo `2**WIDTH`.

| Signal | Meaning |
| --- | --- |
| `clk` | Rising-edge clock (testbench uses a 10 ns period) |
| `rst_n` | Active-low **asynchronous** reset to zero |
| `clear` | Synchronous clear to zero |
| `load`, `load_value[WIDTH-1:0]` | Synchronously load a value |
| `enable` | Count when high; otherwise hold |
| `up` | 1 = increment, 0 = decrement; ignored when disabled/loading/clearing |
| `count[WIDTH-1:0]` | Current count |

**Priority:** reset > clear > load > enabled count > hold. Clear and load work
regardless of enable. Maximum + 1 = zero; zero - 1 = maximum. No saturation,
carry, borrow, or terminal-count output is implied. RTL supports positive widths;
the UVM example requires width >= 2 because its random/coverage interior range
excludes zero and maximum. Use `WIDTH=` on make commands to keep DUT, interface,
transactions, reference model, and coverage consistent.

## Files and UVM architecture

```text
rtl/up_down_counter.sv      synthesizable RTL
 tb/top/counter_if.sv          pins, driver/monitor clocking blocks
 tb/counter_pkg.sv         UVM package and include order
 tb/agent/counter_item.svh       randomized one-cycle stimulus and observed response
 tb/sequences/counter_sequences.svh  reset, directed, wrap, constrained-random sequences
 tb/agent/counter_sequencer.svh  typed UVM sequencer
 tb/agent/counter_driver.svh     sequence-item-to-pin driver
 tb/agent/counter_monitor.svh    passive pin-to-transaction monitor
 tb/agent/counter_agent.svh      active/passive-capable agent
 tb/env/counter_scoreboard.svh independent cycle-accurate reference model/comparison
 tb/env/counter_coverage.svh   functional coverage subscriber
 tb/env/counter_env.svh        agent, scoreboard, coverage and analysis connections
 tb/tests/counter_tests.svh      base regression test and four focused tests
 tb/top/tb_top.sv              clock, interface, DUT, config DB, run_test, watchdog
 tb/rtl_smoke/counter_rtl_smoke.sv   separate non-UVM RTL smoke test
sim/run.do                batch run with nonzero exit status on failure
Makefile                  compile, run, regression, smoke and clean targets
```

```text
uvm_test_top (counter_base_test or focused test)
  env
    agent
      sequencer --> driver --> interface --> DUT
      monitor <--------------- interface
        | analysis port
        +--> scoreboard (reference model + comparison every sampled cycle)
        +--> coverage   (functional coverage)
```

The driver drives at the **falling** edge. Monitor clocking inputs use `#0`
(Observed-region sampling) at the rising edge, after DUT NBA assignments. Each
sequence item therefore describes the controls and resulting count for one active
edge; the scoreboard updates its independent expected value before comparing.
It does not infer expected values from DUT output. Case inequality detects X/Z
on count. The first item of every sequence resets the DUT. A two-clock drain
allows the final monitor callbacks to finish before dropping the objection.
When idle, the driver holds the last controls and the monitor continues checking
valid cycles, including the drain cycles; sample counts can exceed sequence length.

The monitor is always present. Setting the agent's standard `is_active` config
to `UVM_PASSIVE` omits its sequencer/driver; a passive integration must provide
external stimulus and an appropriate test (these supplied tests are active).

## Windows QuestaSim: start here (no make needed)

1. Extract the ZIP completely. Open **Command Prompt** in this folder.
2. Put your licensed QuestaSim `win64` folder on PATH and set the UVM source path
   (replace these example installation paths with your own):

```bat
set "PATH=C:\questasim64_2024.3\win64;%PATH%"
set "UVM_HOME=C:\questasim64_2024.3\verilog_src\uvm-1.2"
run.bat
run.bat counter_wrap_test 1 8 1000
run.bat counter_random_test 42 16 5000
regression.bat
```

Argument order is **test, seed, width, random-item count**. Batch runs return
nonzero on failure. `regression.bat` runs all five tests (seed 1, width 8).
Paths containing spaces are supported; prefer short project paths for convenience.

For GUI waveform learning, start QuestaSim and use its **Transcript**:

```tcl
cd {C:/DV/up_down_counter}
set UVM_HOME {C:/questasim64_2024.3/verilog_src/uvm-1.2}
set GUI_MODE 1
set TEST counter_wrap_test
set WIDTH 8
set SEED 1
set NUM_ITEMS 1000
do run.do
```

Use Tcl braces around Windows paths and forward slashes. The root `run.do`
compiles in dependency order, loads the test, adds interface waves and runs.
In GUI mode it leaves the simulator open; inspect the UVM summary and
`/tb_top/test_passed` (1 = pass), then use Zoom Full in the Wave window. Before
recompiling another test in the same GUI session, enter `quit -sim`, then change
`TEST` and run `do run.do` again. A fresh GUI session is simplest when changing
UVM installations. `sim/run.do` is the batch completion helper, not the GUI entry.

The Word guide is [`docs/Counter_UVM_Beginners_Guide.docx`](docs/Counter_UVM_Beginners_Guide.docx).
It includes the architecture, step-by-step explanations, timing examples,
Windows instructions, debugging and a complete source listing. See
[`ARCHITECTURE.md`](ARCHITECTURE.md) for the source and runtime hierarchy.

## Requirements and simulation

Use a **UVM-capable QuestaSim/ModelSim edition**, GNU make, and bash. Free or
limited ModelSim editions may not support classes, constrained randomization,
or covergroups. Ensure `vlib`, `vlog`, and `vsim` are on PATH and licensed.

Set `UVM_HOME` to a UVM **source installation** containing `src/uvm_pkg.sv`:

```bash
cd up_down_counter
export UVM_HOME=/path/to/uvm-1.2
# A typical Questa installation provides:
# export UVM_HOME="$QUESTA_HOME/verilog_src/uvm-1.2"
make help
make run                         # complete base-test suite; seed 1, width 8
make run TEST=counter_wrap_test
make run TEST=counter_random_test SEED=42 NUM_ITEMS=5000 WIDTH=16
make regression                  # all five test classes, separate logs
make clean
```

If `QUESTA_HOME` is set, the Makefile defaults to its `verilog_src/uvm-1.2`.
Accellera UVM 1.2 is recommended; the source also statically compiles with the
IEEE UVM reference library. UVM is **not vendored**. The Makefile compiles its
source into the local work library with `UVM_NO_DPI`, so no vendor-specific
precompiled-UVM mapping or external DPI build is needed. Do not mix another
precompiled `uvm_pkg` into this invocation. Override `VLIB`, `VLOG`, or `VSIM`
if your executable names differ. Use `make clean` when switching UVM libraries.

`make run` always recompiles (including when WIDTH changes). `make regression`
compiles once then starts a fresh simulator for each test. Logs and work library
are generated under ignored `sim/build/`. The Tcl file is invoked by make after
loading `tb_top`; it is not a standalone compile script. UVM report error/fatal
counts determine the top's `test_passed` flag. Tcl checks it and returns a nonzero
status for failures; run errors and breaks also fail the command. The top has a
10 ms watchdog; very long random runs may need a larger watchdog.

For multiple random seeds:

```bash
for seed in 1 7 42; do
  make run TEST=counter_random_test SEED=$seed NUM_ITEMS=2000 || exit 1
done
```

### Lightweight RTL-only run

With Icarus Verilog (`iverilog`, `vvp`) on PATH:

```bash
make smoke
make smoke WIDTH=16
```

This self-checking non-UVM test covers reset, load, hold, priority, both wrap
boundaries, a reset assertion between clock edges (checked before the next
edge), and 2,000 randomized cycles. A mismatch triggers `$fatal`. It is a quick
sanity check, **not** a replacement for running the UVM tests and coverage.

## Test plan

| UVM test class | Intent |
| --- | --- |
| `counter_reset_test` | Startup and mid-traffic reset; reset overrides load, clear and counting |
| `counter_directed_test` | Up/down, disabled holds, direction reversal, load versus enable and clear versus load/enable |
| `counter_wrap_test` | Load maximum then increment to zero; decrement zero to maximum |
| `counter_random_test` | Reset followed by weighted randomized control combinations and boundary-biased loads; `+NUM_ITEMS` controls length |
| `counter_base_test` | Runs all four sequences above in one simulation (default) |

All tests check every valid sampled cycle via the scoreboard. Tests use UVM
factory registration, config DB virtual-interface distribution, sequence
handshakes, objections, and analysis ports. No expected-value transaction is
sent from the driver to the scoreboard.

Coverage includes effective operation (reset/clear/load/hold/up/down), zero,
maximum and interior count values, overflow and underflow events, plus crosses
for direction x enable, clear x load, and reset x load. Wrap coverage uses the
previous observed count and current operation, rather than merely seeing a zero
or maximum output. Coverage is reported at end of simulation; there is no hard
coverage threshold and a single seed is not a coverage-closure claim. These are
functional covergroups; code coverage/UCDB merging can be enabled with your
site's simulator options if needed.

## Validation in the development workspace

- Static syntax **and elaboration** with pyslang 12.1.0 and the unmodified
  Accellera UVM 1.2 release: passed at WIDTH=2, 8 and 16. Two warnings are in
  the upstream UVM library (empty loop bodies), not the example sources.
- Static elaboration against IEEE UVM reference sources: passed (one upstream
  escape-sequence warning).
- Standalone RTL smoke test: static compilation passed without warnings.
- Make command generation (`make -n`) and missing-UVM configuration guard checked.
- **No RTL or UVM simulation was executed here:** Questa/ModelSim and Icarus are
  not installed. Run the commands above in your simulator environment before
  treating the example as simulation-validated or claiming coverage results.
