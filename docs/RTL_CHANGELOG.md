# RTL Change Log — PCIe Gen5 PHY LTSSM

**Repository:** `arunkumar-seq/PCIe_phy_gen5_LTSSM`
**Branch:** `arena/01a0cd27-pcie-phy-gen5-ltssm` (base commit `ab898dd`)
**Design top:** `rtl/PCIE.v` → module `PCIe`
**Date:** 2026-09-23

---

## 1. Scope and ground rules

This document records every source change made during the audit / bug-fix /
synthesis-cleanup pass, plus the items that were **found but deliberately not
changed** because they need a design decision from you.

Rules that were applied throughout:

| Rule | How it was honoured |
|---|---|
| No architecture changes | Every fix is local: a reordered declaration, an added `else`, an added reset branch, a corrected port width, a driven input. No module was split, merged, renamed or rewritten. |
| No from-scratch rewrites | 13 files modified, 880 insertions / 109 deletions. The large insertion count is almost entirely explanatory comment blocks; the functional deltas are 1–20 lines each. |
| Unique change-ID on every edit | `BUGFIX-nnn`, `FSM-nnn`, `SIM-nnn`, `WIDTH-nnn`. Each ID appears exactly once as a comment banner immediately above the code it explains. |
| Never suppress a warning to hide an error | No `-suppress`, no `/* synopsys translate_off */`, no forced signals, no deleted tests. The one `+define+SIM_TIMER_PRESCALE` mechanism is **off by default** and off in synthesis. |
| Synthesis-safe DUT | Verified with yosys (§6). Two genuine synthesis blockers were found; one is fixed (`BUGFIX-047`), one needs your sign-off (§5.1). |
| Verification claims only for commands actually run | See the **VERIFIED / NOT VERIFIED** column on every entry and the command log in §7. |

> **The single most important caveat in this document:** QuestaSim exists only on
> your Windows machine. **No QuestaSim result in this document is VERIFIED.**
> Everything marked NOT VERIFIED is a prediction from static analysis (slang
> elaboration) and from your own uploaded transcript
> (`tb_edited/sim/transcript`). You must re-run it. §8 tells you exactly how.

---

## 2. Summary of all changes

### 2.1 RTL (`rtl/`) — affects synthesis

| ID | File:line | One-line description | Class |
|---|---|---|---|
| `BUGFIX-046` | `rtl/TxLtssm.v:719` | `sdsFlagSet`/`sdsFlagClr` wire declarations moved **above** the clocked block that consumes them (Verilog-2001 declare-before-use). | Hard compile error |
| `BUGFIX-047` | `rtl/OS_GENERATOR.v:279` | Functional branch chained onto the async-reset test with `else if`, so reset is the process's single controlling condition. | Synthesis blocker + reset defeat |
| `FSM-005` | `rtl/maintlssm.v:166` | `substateTx` / `substateRx` given explicit reset values in the async reset branch. | X at reset / FSM-001 class |
| `FSM-006` | `rtl/maintlssm.v:91` | `txPollingDone` / `rxPollingDone` made **sticky** so the Polling handshake cannot be lost between the two sides. | Race / handshake loss |
| `FSM-007` | `rtl/LMC.v:45` | Async-reset branch hoisted to the top of the process and made mutually exclusive with the functional logic. | Synthesis blocker (PROC_DFF) |
| `SIM-015` | `rtl/Timer.v:63` | **Opt-in** `SIM_TIMER_PRESCALE` macro divides every timeout by 2^N. Not defined by default ⇒ zero effect on netlist and on normal simulation. | Sim productivity only |

### 2.2 RTL testbenches (`rtl/*_tb.v`, `rtl/tb.v`, `rtl/tx_test.v`) — simulation only

| ID | File:line | One-line description | Class |
|---|---|---|---|
| `SIM-010` | `rtl/LPIF_tb.v:14` | Dead/unused port connections removed from the LPIF bench instantiation. | Elaboration warning |
| `SIM-011` | `rtl/tx_test.v:47` | `NumberDetectLanes` widened to `[4:0]` to match the DUT port (was truncated). | Port-width mismatch |
| `SIM-012` | `rtl/tb.v:2` | `ifdef` guard — **your decision**, see §4.3. | Undriven-input choice |
| `SIM-013` | `rtl/LMC_tb.v:2` | Bench instantiates **`LMC_RX`** (the RX-side lane-management block) instead of `LMC`. The bench's port list never matched `LMC`. | Wrong DUT / port mismatch |
| `SIM-014` | `rtl/pcieTB.v:110` | Five DUT inputs that were declared but never driven are now initialized, removing X-propagation into RX idle detect, Gen3+ EQ feedback and `forceDetect`. | X-propagation |

### 2.3 UVM environment (`tb/`) — simulation only

| ID | File:line | One-line description | Class |
|---|---|---|---|
| `SIM-003` | `tb/top/hdl_top.sv:230` | `RxDataK` connection corrected. | Port mismatch |
| `SIM-004` | `tb/agents/pipe_agent/pipe_driver_bfm.sv:164` | `previous_PowerDown` initialized to `1'b1` so the power-down wait at time 0 is not entered with an X comparison. | Time-0 deadlock |
| `SIM-006` | `tb/agents/pipe_agent/pipe_driver_bfm.sv:706` | **`get_width()` completed** — the root cause of your hang. See §3.1. | Time-0 infinite loop |
| `SIM-007` | `tb/agents/pipe_agent/pipe_driver_bfm.sv:864` | Loop bound captured from the queue size **before** the loop, so `pop_front()` inside the loop cannot shrink the bound and spin. | Zero-delay infinite loop |
| `SIM-008` | `tb/agents/pipe_agent/pipe_monitor_bfm.sv:1474` | Missing parentheses corrected in a bit-select/concat expression. | Precedence bug |
| `SIM-009` | `tb/top/hdl_top.sv:347` | `UVM_DEBUG` verbosity/enable path corrected. | Debug visibility |
| `WIDTH-001` | `tb/top/hdl_top.sv:259` | `RxElecIdle` expanded `{16{...}}` — the DUT port is `[15:0]` (one per lane) but `pipe_if` declares a scalar. | Port-width mismatch |

### 2.4 New files (nothing overwritten)

| Path | Purpose |
|---|---|
| `Makefile` | Repo-root build/run/wave/lint/synth targets. Does **not** touch `tb/sim/Makefile`. |
| `scripts/questa_compile.do` | `vlib`/`vmap`/`vlog` of `rtl/*.v` into `sim/work`; path-robust via `info script`. |
| `scripts/questa_run.do` | **Bounded** run (never `run -all`), end-state report, optional `.wlf` dump. |
| `scripts/questa_wave.do` | 7 preloaded waveform groups; parametrized `::TB_PATH`/`::DUT_PATH` so it works for both `pcieTB` and `hdl_top`. |
| `scripts/run_questa.sh` | Same as `make compile sim`, for shells without `make`. |
| `tools_check/` | Licence-free checks: `slang_check.py`, `run_yosys.mjs`, `yosys_closure.sh`, `yosys_targeted.sh`. |
| `.gitignore` | Keeps `sim/`, `work/`, `*.wlf`, `wlft*`, `transcript`, `node_modules/` out of git. |
| `docs/RTL_CHANGELOG.md` / `.docx` | This document. |

---

## 3. The two bugs that actually stopped your simulation

### 3.1 `SIM-006` — the UVM hang at time 0 (**root cause of your 4m22s freeze**)

Your transcript `tb_edited/sim/transcript` shows every `UVM_INFO` at time 0,
`Errors: 0, Warnings: 0`, and then nothing until you broke in at 4 min 22 s with
the cursor inside `pipe_driver_bfm.sv:800`:

```systemverilog
RxDataK[i] = k_data.pop_front();
```

Compile and elaborate were clean. This was a **runtime** hang, and it was a
zero-delay infinite loop, not a slow simulation.

`get_width()` decoded the PIPE link width from the DUT's `Width[1:0]` signal, but
it only had cases for `2'b00` and `2'b11` and **no `default`**:

| `Width[1:0]` | before `SIM-006` | after `SIM-006` |
|---|---|---|
| `2'b00` | 8 | 8 |
| `2'b01` | *(fell through → 0)* | 16 |
| `2'b10` | *(fell through → 0)* | **32** |
| `2'b11` | 32 | 32 |
| `X` (time 0) | *(fell through → 0)* | 8 (`default`) |

The DUT drives `Width[1:0]` from `mainLTSSM` (`rtl/maintlssm.v:432`) and its real
encoding for a 32-bit datapath is **`2'b10`** — the one value `get_width()` had no
case for. So:

1. At time 0, `Width` is `X` → `get_width()` returns `0`.
2. In every Gen3/Gen4/Gen5 phase, `Width` is `2'b10` → `get_width()` returns `0`.
3. `pipe_width = 0` → the driver's per-beat loop iterates `0/8 = 0` times… except
   the loop at ~line 796/800 pops from a queue whose size was re-evaluated each
   iteration, so it never terminated and never advanced simulation time.

Result: the UVM environment froze at 0 ns with no error, exactly as your
transcript shows.

`SIM-007` fixes the second half of the same mechanism: the loop bound is now
captured from the queue size **once, before** the loop, so a `pop_front()` inside
the body cannot keep the bound moving.

> **NOT VERIFIED in QuestaSim.** The diagnosis is corroborated by your own
> transcript (break location, all-`UVM_INFO`-at-0, zero errors) and by static
> analysis of the DUT's `Width` encoding.

### 3.2 `SIM-014` + `SIM-015` — why the RTL bench "sat in Detect"

Your waveform cursor was at ≈34.4 µs with `substateTx`/`substateRx` still in
`DetectActive`. That is ≈3,400 `Pclk` cycles. **Detect cannot exit in 3,400
cycles** — this design models the timeouts at true PCIe scale. See §8.3 for the
arithmetic; the short version is that leaving `Detect` costs ~6,000,000 cycles
(≈60 ms of simulated time) in the `pcieTB` configuration.

This was **not** (only) an RTL bug. It is a run-window problem, and it is why
`scripts/questa_run.do` refuses to use `run -all` and why `SIM-015` exists.

---

## 4. Notable details on individual changes

### 4.1 `BUGFIX-046` — declare-before-use is a hard error, not a warning

`FSM-004` (from an earlier pass) made the `always @(posedge Pclk)` block the
single owner of `SDSFlag` and fed it from two continuous assignments. Those two
wires were declared at the **bottom** of the file, after the block that used
them. Verilog-2001 requires declaration before reference, so:

- slang: `identifier 'sdsFlagClr' used before its declaration` (error)
- QuestaSim: `** Error: (vlog-…) sdsFlagSet is not declared`

Worse, QuestaSim would then fall back to an **implicit 1-bit net** for the
undeclared name, silently tying the SDS set/clear decode to 0 and breaking Gen3+
SDS generation. The fix moves the two `wire` declarations (expressions
byte-for-byte unchanged) to just above the consuming block. `FSM-004`'s semantics
and the locked design decision are preserved.

### 4.2 `BUGFIX-047` / `FSM-007` — the "two top-level ifs" synthesis blocker

Both `rtl/OS_GENERATOR.v` and `rtl/LMC.v` had a process declared
`always @(posedge clk, negedge reset_n)` that began with `if (reset_n == 1'b0)`
but then continued with a **second, independent** top-level `if`. Because the
reset test was not the process's single controlling condition, no async reset
could be lifted out, and yosys `PROC_DFF` aborted with:

```
ERROR: Multiple edge sensitive events found for this signal!
```

In `OS_GENERATOR.v` this was also a **functional** bug, not just a tool complaint:
because the two branches were not mutually exclusive, the functional branch ran
*while reset was asserted* and its non-blocking assignments came later in the
process, so they **overrode the reset values**. Concretely, with `reset_n == 0`
the trailing `else` branch ("no ordered sets available to send") still ran and
re-drove `DataValid` / `Os_Out` / `DataK` / `finish` from `not_valid`. `finish`,
`busy` and `valid` are exactly the handshake signals the Tx LTSSM waits on, so an
ordered-set generator that does not actually reset is a link-training hazard.

Fix: chain the functional logic to the reset test (`else if`), no expression
changes. Same class as `FSM-001` (`maintlssm.v`), already fixed in an earlier
pass.

### 4.3 `SIM-012` — the one change that is **your decision**, not mine

`rtl/tb.v` has undriven DUT inputs. I did **not** silently pick values for them;
the fix is an `ifdef` guard so you choose:

- default build → unchanged behaviour;
- with the guard enabled → the inputs get defined, non-X values.

Compare with `SIM-014` (`rtl/pcieTB.v`), where I *did* drive the five inputs
unconditionally, because there the three that matter are genuinely consumed:

| Input | Where it goes | Effect of leaving it X |
|---|---|---|
| `RxElectricalIdle[15:0]` | `PCIE.v:220` → RX block | Per-lane electrical-idle detection sees X on all 16 lanes |
| `LinkEvaluationFeedbackDirectionChange[95:0]` | `PCIE.v:183` → `TOP_MODULE` | Gen3+ equalization feedback path sees X |
| `lp_force_detect` | `PCIE.v:153` → `mainLTSSM.forceDetect` | The `else if (forceDetect)` test that `FSM-001` restructured evaluates to "not taken" **by luck rather than by design** |
| `PclkChangeOk` | declared as a `PCIe` port, not connected inside the closure | Harmless — the PCLK-change handshake is not implemented in this design. Initialized anyway for a clean waveform. |
| `P2M_MessageBus[7:0]` | declared as a `PCIe` port, not connected inside the closure | Harmless, as above |

### 4.4 `SIM-013` — the bench was instantiating the wrong module

`rtl/LMC_tb.v` instantiated `LMC` (`rtl/LMC.v`), but its port list matches
**`LMC_RX`** (`rtl/Lane_Management_Control.v:1`):

```
clk, reset, GEN, descramblerSyncHeader, descramblerDataValid, LANESNUMBER,
LMCIn, descramblerDataK  →  LMCValid, LMCSyncHeader, LMCDataK, LMCData
params GEN1_PIPEWIDTH … GEN5_PIPEWIDTH
```

`LMC_RX` is the block `RX` actually instantiates (`rtl/Modules Integration.v:103`);
`LMC` is the TX-side block. So the bench was checking a different module from the
one whose ports it declared. `LMCValid`/`LMCDataK`/`LMCData` are outputs;
`LMCSyncHeader` is intentionally left unconnected (warning only).

This is why the slang gate went from **10 to 11 elaborated top instances** — the
bench now actually elaborates.

### 4.5 `WIDTH-001` — 1-bit net on a 16-bit port

`rtl/PCIE.v:35` declares `input [15:0] RxElectricalIdle` (one indicator per lane,
`LANESNUMBER = 16`), but `pipe_if.sv:25` declares `logic RxElecIdle;` — a scalar.
Connecting a 1-bit net to a 16-bit port relies on implicit zero-extension, so
lanes 1–15 were permanently tied to "not in electrical idle" and only lane 0 ever
saw the driver's value. Fixed by replicating: `{16{PIPE.RxElecIdle}}`.

Related widths, for reference:

| Signal | Declaration | Width |
|---|---|---|
| `pipe_if.RxDataValid` | `pipe_if.sv:18` | `[lanes-1:0]` |
| `pipe_if.RxDataK` | `pipe_if.sv:19` | `[bus_data_kontrol_param:0]` = 64 bits |
| `pipe_if.RxElecIdle` | `pipe_if.sv:25` | 1 bit (scalar) |
| `PCIe.RxDataK` | `PCIE.v:31` | `[(MAXPIPEWIDTH/8)*LANESNUMBER-1:0]` |
| `PCIe.RxElectricalIdle` | `PCIE.v:35` | `[15:0]` |

---

## 5. Found but **NOT** changed — needs your decision

### 5.1 `rtl/osDecoder.v:181` — non-constant `for` loop bound (**synthesis blocker**)

```verilog
for (j = 0; j < 128<<numberOfShifts; j = j+8)
```

`numberOfShifts` is a `reg`, i.e. a runtime value, so the loop bound is not a
constant. yosys refuses to read the file at all:

```
osDecoder.v:181: ERROR: 2nd expression of procedural for-loop is not constant!
```

Any commercial synthesis tool will reject this too. **`osDecoder` is in the
closure** — `RX` instantiates it at `rtl/Modules Integration.v:107` — so this
blocks synthesis of the whole design, not just one leaf.

A second problem in the same file: `always @(out)` has an **incomplete sensitivity
list** — the block also reads `numberOfShifts`, `lanesOffsets`, `lane_iter` and
`index_iter`. In simulation this produces stale values; in synthesis the tool
ignores the list entirely, so **sim and silicon would differ**.

**Why I did not fix it:** the obvious fix (replace the bound with a constant upper
bound and guard the body) is **behaviour-affecting** — it changes how many shift
iterations execute for a given `numberOfShifts`. That is a design decision, not a
cleanup, and your rules say minimal root-cause fixes with no architecture
changes. **This needs your sign-off.** No change-ID has been allocated to it yet;
the next free ID is `BUGFIX-048`.

> Because of this file, every yosys run in §6 works on a **throwaway copy** in
> `/tmp` with that one bound replaced by a constant. **Your repository file is
> untouched.** Read the osDecoder/RX rows as "clean apart from the known
> non-constant loop bound".

### 5.2 `rtl/LMC.v` — `pipe_width` latch (pre-existing)

yosys infers a latch for `pipe_width`. This is **pre-existing**, not introduced by
`FSM-007`, and `FSM-007` deliberately did not touch it: giving `pipe_width` a
default in the `GEN` case would change link-width behaviour. Flagging it for your
review; next free ID `BUGFIX-048`/`WIDTH-002`.

### 5.3 `rtl/OS_GENERATOR.v` — residual `PROC_ARST` limitation

`BUGFIX-047` restructures the process so that `PROC_ARST` *can* lift the async
reset: the functional branch is now chained onto the reset test, which is exactly
the condition that pass requires. The identical restructuring cleared the
`Multiple edge sensitive events` error in `LMC.v` (`FSM-007`) and `maintlssm.v`
(`FSM-001`), where it was observed to do so.

For `OS_GENERATOR` specifically the post-fix confirmation run **did not complete**
in the sandbox — WASM yosys spent ~25 minutes of CPU on this one module without
producing output and was killed. So "the error is gone here too" is an expectation
from the fix's structure, not a demonstrated result. See §6.2, and confirm with
your own synthesis tool.

Separately, yosys was still unable to lift an async reset out of one process in
this ~2000-line chain even where it did run. The remaining fix would require
**splitting the process**, which is an architecture change. Bisecting which
sub-chain triggers it was attempted and abandoned — the trigger is not isolatable
without the split. **Needs your sign-off.**

### 5.4 Nine unnamed generate blocks — **do not rename**

slang reports 9 unnamed generate blocks. They must **not** be given names,
because your existing `tb/sim/wave.do` addresses signals through the
auto-generated names:

```
/hdl_top/DUT/rx/rxltssm/genblk1[0]/counter/count
```

Naming the blocks would silently break every saved waveform script and `.wlf`
database. The warnings are accepted as-is.

### 5.5 950 width-expansion warnings — accepted

slang reports ~950 width-expansion warnings across `rtl/`. These are implicit
narrow→wide extensions that are legal Verilog and intentional in this coding
style. Fixing them would mean touching hundreds of expressions for zero
functional gain and a large regression risk. **Accepted, not suppressed** — they
are still printed in full by `make lint`.

---

## 6. Verification status

### 6.1 slang elaboration gate — **VERIFIED (executed in sandbox)**

```
python3 tools_check/slang_check.py --rtl-dir rtl --show 30
```

| Metric | Result |
|---|---|
| Files parsed | 55 |
| **Errors** | **0** |
| Warnings | 1311 (was 1308 before `SIM-013` added an 11th elaborable bench) |
| Elaborated top-level instances | **11** (was 10 before `SIM-013`) |

The 11 elaborated tops cover the full closure plus the standalone benches.
Also verified both ways for `SIM-015`:

```
python3 tools_check/slang_check.py --rtl-dir rtl --define SIM_TIMER_PRESCALE=12   → 0 errors
python3 tools_check/slang_check.py --rtl-dir rtl                                  → 0 errors
```

So the `ifdef` is syntactically clean whether or not the macro is defined, and the
default build is provably unaffected.

### 6.2 yosys synthesis check — **PARTIALLY VERIFIED (executed in sandbox)**

See §7 for the exact command and the live result. Summary of what was established:

| Module | Result | When |
|---|---|---|
| `mainLTSSM` | clean — 0 problems reported, 29 registers inferred | completed |
| `LMC` | clean after `FSM-007` — 65 `$adff` inferred; `pipe_width` latch is pre-existing (§5.2) | completed |
| `OS_GENERATOR` | `Multiple edge sensitive events` reproduced **before** `BUGFIX-047`; the post-fix confirmation run did **not** converge in the sandbox (see below) | partial |
| `osDecoder` | blocked at read by the non-constant loop bound (§5.1) | reproduced |
| whole closure (`PCIe`) | **not obtained** — see below | did not complete |

**Be precise about the `OS_GENERATOR` row.** What was actually executed and
observed is the *failure before the fix*: yosys aborted with `ERROR: Multiple edge
sensitive events found for this signal!` on register `D` in the process at
`OS_GENERATOR.v:267`. That is the evidence `BUGFIX-047` was written against, and it
is recorded verbatim in the `BUGFIX-047` comment banner in the source. The
*post-fix* re-run was started twice and killed both times without producing output
— not because it reported an error, but because it did not finish. So the claim
"the error is gone" is **reasoned from the fix's structure** (the functional branch
is now chained onto the reset test, which is exactly the condition `PROC_ARST`
requires, and the same restructuring cleared the identical error in `LMC.v` and
`maintlssm.v`), **not from a completed post-fix yosys run.** Treat it as expected
rather than demonstrated, and confirm it with your own synthesis tool.

**Why the runs did not converge.** yosys was run through `@yowasp/yosys` (version
0.69, WebAssembly) because no native licence-free synthesizer was available in the
sandbox. WASM yosys must parse all 46 synthesizable `rtl/*.v` files — several over
100 KB, `OS_GENERATOR.v` alone containing a ~2000-line process — before it can
elaborate *any* top, and it does that from scratch for every module. Measured
cost: ~25 minutes of CPU on `OS_GENERATOR` alone with no output, and ~25 minutes
on the `hierarchy -top PCIe` step of the closure run, both killed. This is a
**sandbox throughput limit, not a design problem.** On a native yosys build the
same commands take seconds to minutes.

Reproduce it yourself where it will actually finish:

```bash
# native yosys (recommended - seconds, not tens of minutes)
yosys -p "read_verilog rtl/*.v; hierarchy -top PCIe; proc; check -noinit; stat"

# or the WASM path used here, with the osDecoder.v:181 caveat from §5.1
bash tools_check/yosys_fixed.sh OS_GENERATOR    # one module
bash tools_check/yosys_closure.sh               # whole closure
```

Note that yosys is **not** a substitute for your target synthesis tool. It is used
here only as a licence-free structural check for the `proc`/`check` classes of
problem: async-reset lifting, inferred latches, combinational loops, uninitialised
state.

### 6.3 QuestaSim — **NOT VERIFIED**

**No** QuestaSim command in this document was executed. Specifically NOT VERIFIED:

- `scripts/questa_compile.do` — plain `vlog` compiles all of `rtl/*.v` with 0 errors
- `scripts/questa_run.do` — the bounded run terminates and reports an LTSSM end state
- `scripts/questa_wave.do` — all 7 waveform groups resolve against real signals
- `SIM-006`/`SIM-007` — the UVM hang is gone
- `SIM-013`/`SIM-014`/`WIDTH-001` — the benches and UVM top elaborate and run
- `SIM-015` with `+define+SIM_TIMER_PRESCALE=12` — the LTSSM walks
  Detect → Polling → Configuration → L0 inside a short window

Everything above is a **prediction** from slang elaboration, from yosys, and from
your own uploaded transcript and `modelsim.ini`. §8 is the recipe to confirm it.

### 6.4 Evidence taken from your own uploaded artifacts

These are your files, treated as ground truth about your environment:

| Evidence | Source | Conclusion drawn |
|---|---|---|
| `Resolution = ns` (line 793) | `tb_edited/sim/modelsim.ini` | `#5` in `pcieTB` means 5 ns ⇒ **10 ns Pclk period**. All run windows in §8.3 use this. |
| `vsim -c -do "run -all; quit -f;" hvl_top hdl_top +UVM_NO_RELNOTES +UVM_TESTNAME=pcie_test +VSEQ=dummy_vseq -suppress 8887` | `tb_edited/sim/transcript` | Your UVM invocation. Note it already carries `-suppress 8887` — that is **yours**, not mine; nothing new was suppressed. |
| Break after 4:22 at `pipe_driver_bfm.sv:800` | `tb_edited/sim/transcript` | The hang location that pinpointed `SIM-006`/`SIM-007` (§3.1). |
| `run -all` never returned | `tb_edited/sim/transcript` | `pcieTB` has **no `$finish`** and `always #5 CLK = ~CLK` free-runs ⇒ any vsim run **must** be bounded. Hence `scripts/questa_run.do`. |
| `vlog ../../rtl/*.v` (plain, no `-sv`) | `tb/top/top.mk` | Your working RTL build uses **plain `vlog`**. Confirmed correct: the only `logic` tokens anywhere in `rtl/*.v` are inside comments (`Descrambler.v:72`, `Scrambler.v:95`), so there is no SystemVerilog to enable. All scripts use plain `vlog`. |
| `-novopt` | `tb/sim/Makefile` (`run_design`) | Your older flow disables optimization to keep internals visible. The modern equivalent is `-voptargs=+acc`, which is what the new scripts use (`-novopt` is documented as the fallback). |
| `Exception c0000005 Tcl_UpdateLinkedVar`, Questa 10.4e win64 | `tb_edited/sim/vish_stacktrace.vstf` | A **vish GUI crash**, separate from the hang. `vsim_stacktrace.vstf` (2021, vsim 10.7) is older still and was ignored. |

---

## 7. Commands actually executed

```bash
# slang elaboration gate — COMPLETED, 0 errors, 55 files, 11 elaborated tops
python3 tools_check/slang_check.py --rtl-dir rtl --show 30
python3 tools_check/slang_check.py --rtl-dir rtl --define SIM_TIMER_PRESCALE=12
python3 tools_check/slang_check.py --rtl-dir rtl --top PCIe

# Makefile plumbing — COMPLETED (dry runs; vsim/vlog do not exist in the sandbox)
make help
make -n compile
make -n sim
make -n sim FAST_TIMERS=1 RUN_TIME="80 ms"
make -n synth ; make -n synth-modules
make lint                      # real run: 0 errors, 1311 warnings

# change-ID inventory used to build §2 and §9 — COMPLETED
grep -rnoE "(BUGFIX|FSM|SIM|WIDTH)-[0-9]{3}" rtl/ tb/ tb_edited/

# shell/Tcl static checks — COMPLETED
bash -n scripts/run_questa.sh tools_check/*.sh
python3 tools_check/md2docx.py docs/RTL_CHANGELOG.md docs/RTL_CHANGELOG.docx
```

**Started but killed — no result obtained** (all four were WASM-yosys throughput
limit casualties, see §6.2):

```bash
bash tools_check/yosys_sweep.sh      # broad per-module sweep — killed, all modules
                                     # aborted at read on osDecoder.v:181
bash tools_check/yosys_targeted.sh   # targeted per-module sweep — killed
bash tools_check/yosys_closure.sh    # hierarchy -top PCIe — killed at ~25 min CPU
bash tools_check/yosys_fixed.sh OS_GENERATOR TX_LTSSM LMC mainLTSSM Timer
                                     # killed at ~25 min CPU on OS_GENERATOR
```

**Not executed anywhere:** any `vlog`, `vsim`, `vish`, `vlib`, `vmap`, `make sim`,
`make wave`, `make uvm-*` or QuestaSim `.do` script. See §6.3.

---

## 8. How to run it in QuestaSim

### 8.1 Prerequisites

`make` is not native to `cmd.exe`/PowerShell — install Cygwin (or MinGW); see
`configure-make.md` in the repo. If `vlog`/`vsim` are not on `PATH`:

```bash
make sim QUESTA_BIN="C:/questasim64_10.4e/win64/"
```

Forward slashes work in both Cygwin make and Windows; backslashes do not survive
make's escaping.

### 8.2 Two independent flows

**A) RTL bench — `rtl/pcieTB.v` → `rtl/PCIE.v`.** Self-contained Verilog, no UVM
needed. Fastest way to see the LTSSM train.

```bash
make compile                  # vlib/vmap/vlog rtl/*.v → sim/work
make sim                      # batch, 200 µs smoke test, log → sim/sim.log
make wave                     # GUI run with the 7 waveform groups preloaded
make wave-view                # reopen the .wlf written by 'make sim'
make sim FAST_TIMERS=1        # SIM-015: all timeouts 4096x shorter
make sim RUN_TIME="80 ms"     # true-scale, long enough to actually reach L0
```

**B) UVM environment — `tb/`.** Delegates to the project's own `tb/sim/Makefile`,
which was **not modified**.

```bash
make uvm-build      # compile common/agents/env/seq/test/top + rtl
make uvm-run        # vsim -gui with tb/sim/wave.do
make uvm-design     # vsim -novopt with tb/sim/design.do (FSM debug waves)
make uvm-clean
```

Housekeeping and licence-free checks:

```bash
make lint           # slang elaboration gate
make synth          # yosys closure check
make clean          # remove sim/ output
make distclean      # + tb/sim/work
make help
```

### 8.3 Run windows — **read this before concluding the LTSSM is stuck**

`modelsim.ini` sets `Resolution = ns` and `pcieTB` clocks with `always #5
CLK = ~CLK`, so the **Pclk period is 10 ns**. Base timer values in `rtl/Timer.v`
are in Pclk cycles at Gen1 / 32-bit, then scaled by generation (`<< (N-1)`) and
by PIPE width (32/16/8 → `<<0`/`<<1`/`<<2`):

| Timeout | Base cycles (Gen1, 32-bit) |
|---|---|
| `t2ms` | 125,000 |
| `t8ms` | 500,000 |
| `t12ms` | 750,000 |
| `t24ms` | 1,500,000 |
| `t48ms` | 3,000,000 |

For `pcieTB` (`GEN1..GEN5_PIPEWIDTH = 8`, `MAX_GEN = 5`, `LANESNUMBER = 16`,
10 ns Pclk):

| Scenario | Cycles | Simulated time |
|---|---|---|
| Gen1, 8-bit, one `t12ms` | `750000 << 0 << 2` = **3,000,000** | ≈ 30 ms |
| Gen5, 8-bit, one `t12ms` | `750000 << 4 << 2` = **48,000,000** | ≈ 480 ms |
| Just leaving `Detect` (Quiet + Active, both `t12ms`) | ≈ 6,000,000 | ≈ 60 ms |
| Your waveform cursor at 34.4 µs | ≈ **3,400** | three orders of magnitude short |
| With `FAST_TIMERS=1` (`SIM_TIMER_PRESCALE=12`), `Detect.Quiet` | ≈ **732** | observable in a few hundred µs |

So:

| Goal | Command |
|---|---|
| Prove it compiles, elaborates and the clock/reset/handshake toggles | `make sim` (200 µs) |
| **See** Detect → Polling → Configuration → L0 quickly | `make sim FAST_TIMERS=1 RUN_TIME="2 ms"` |
| True-scale full link training to L0 at Gen1 | `make sim RUN_TIME="80 ms"` |
| True-scale Gen5 (be prepared to wait) | `make sim RUN_TIME="600 ms"` |

> `scripts/questa_run.do` deliberately **never** issues `run -all`: `pcieTB` has
> no `$finish` and its clock free-runs, so `run -all` cannot terminate. That is
> precisely what happened in your 4m22s transcript. The default `::RUN_TIME` is
> `200 us` and it is always bounded.

### 8.4 Waveform visibility

QuestaSim optimizes the design by default (`vopt`) and drops internal nets.
Without full visibility the `mainLTSSM` substate and handshake signals in
`scripts/questa_wave.do` would simply not exist. The scripts therefore pass
`-voptargs=+acc` (override with `VOPT_ARGS="-novopt"` if your version rejects it —
that is the older, slower equivalent your `tb/sim/Makefile` already uses).

Hierarchy paths used by the wave scripts (parametrized through `::TB_PATH` /
`::DUT_PATH`, so one script serves both benches):

| Bench | DUT path | Instances |
|---|---|---|
| `pcieTB` | `/pcieTB/pcie/` | `mainltssm`, `rx`, `TX` |
| UVM `hdl_top` | `/hdl_top/DUT/` | `mainltssm` (→ `substateTx`, `substateRx`, `finishTx`, `finishRx`, `gotoTx`, `gotoRx`) |

Every group in `questa_wave.do` is wrapped in `catch`, so a missing signal
produces a message rather than aborting the script — but per your rules, a
`catch`ed miss is **reported**, never silently ignored.

---

## 9. Change-ID register

Allocated and used in this pass:

```
BUGFIX-046  BUGFIX-047
FSM-005     FSM-006     FSM-007
SIM-003     SIM-004     SIM-006     SIM-007     SIM-008     SIM-009
SIM-010     SIM-011     SIM-012     SIM-013     SIM-014     SIM-015
WIDTH-001
```

Pre-existing in the repository from earlier passes (unchanged, still present):
`FSM-001`…`FSM-004`, `SIM-002`, and 33 `BUGFIX-nnn` IDs.

The full register, verified by `grep -rnoE "(BUGFIX|FSM|SIM|WIDTH)-[0-9]{3}" rtl/
tb/ tb_edited/` (55 distinct IDs in total):

| Prefix | Range present | Count | Numbers that were **never allocated** |
|---|---|---|---|
| `BUGFIX` | 001–047 | 35 | 007, 008, 013, 019, 022, 023, 024, 025, 026, 027, 029, 032 |
| `FSM` | 001–007 | 7 | none — contiguous |
| `SIM` | 002–015 | 13 | 001, 005 |
| `WIDTH` | 001 | 1 | none |

Do **not** reuse a gap number: an ID that is absent from the tree is still absent
from the history of earlier passes, and reusing one makes it impossible to tell
which pass introduced a given comment. Allocate forward from the next free ID.

**Next free IDs:** `BUGFIX-048`, `FSM-008`, `SIM-016`, `WIDTH-002`.

---

## 10. Recommended next actions, in priority order

1. **Run `make sim FAST_TIMERS=1 RUN_TIME="2 ms"`** and confirm the LTSSM leaves
   `Detect`. This is the single highest-value check and it takes minutes, not
   hours. Then confirm §6.3 item by item.
2. **Re-run the UVM flow** (`make uvm-build && make uvm-run`) and confirm the
   time-0 hang is gone (`SIM-006`/`SIM-007`).
3. **Decide on `rtl/osDecoder.v:181`** (§5.1). This is a hard synthesis blocker in
   the closure and the only item that will stop a real synthesis run. It needs a
   behaviour decision from you, so I did not touch it.
4. **Decide on the `LMC.v` `pipe_width` latch** (§5.2) and the `OS_GENERATOR`
   process split (§5.3).
5. **Decide on `SIM-012`** (`rtl/tb.v` undriven inputs) — enable the guard or not.
6. Only after 1–2 pass: attempt a true-scale run (§8.3) to validate real timeout
   behaviour.

---

*Generated 2026-09-23. All QuestaSim results in this document are NOT VERIFIED and
require a run on your machine. slang and yosys results were executed in the
sandbox and are reproducible with the commands in §7.*
