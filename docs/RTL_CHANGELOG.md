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
| `FSM-008` | `rtl/maintlssm.v:98` (decls), `:222` / `:260` (resets), `:374` (capture), `:667` (Polling.Configuration), `:707` (Config.LinkWidthAccept, upstream), `:749` (Config.Complete), `:952` (Recovery.Idle→L0) | Generic **sticky capture** of each side's `(finish, goto)` request, applied to the four transitions that demanded both sides' strobes on the *same* clock edge. Also fixes a `gotoRx`-written-twice typo. | **Race / handshake loss — the "stuck in Polling" stall** |
| `SIM-015` | `rtl/Timer.v:63` | **Opt-in** `SIM_TIMER_PRESCALE` macro divides every timeout by 2^N. Not defined by default ⇒ zero effect on netlist and on normal simulation. | Sim productivity only |
| `BUGFIX-048` | `rtl/osDecoder.v:232` | Non-constant `for` loop bound `128<<numberOfShifts` replaced by the constant maximum plus a guard that preserves the exact original trip count. **This was the read-time synthesis blocker for the whole closure.** | Synthesis blocker |
| `BUGFIX-049` | `rtl/osDecoder.v:262` | `always@(out)` → `always@(*)`. The block also reads `numberOfShifts`, `numberOfDetectedLanes`, `lane_iter`, `index_iter`, so simulation and synthesis disagreed. | Sim ≠ synthesis |
| `BUGFIX-050` | `rtl/osDecoder.v:264`, `:85` | `lane_iter`/`index_iter` initialized at block entry and removed from the clocked reset. They were driven by **two processes** and were never initialized, giving combinational feedback. | Multiple driver + feedback |
| `BUGFIX-051` | `rtl/osDecoder.v:196`, `:213` | Added the missing `default` to the `numberOfDetectedLanes` and `gen` cases. Both inferred latches; a stale `numberOfShifts` of 5/6/7 made the loop bound 4096/8192/16384 and read past the end of the 2048-bit `out`. | Inferred latch + OOB read |
| `BUGFIX-052` | `rtl/osDecoder.v:266` | `outOs` cleared at block entry. Only `128<<numberOfShifts` of its 2048 bits were ever written, so unused lane regions held stale ordered-set data and inferred a 2048-bit latch. | Inferred latch + stale data |
| `BUGFIX-053` | `rtl/LMC.v:27` | Added the missing final `else` and switched `always@(generation)` → `always@(*)`, removing the `pipe_width` latch. Matches the convention the same author already used in `rtl/DataHandling.v:9,111`. | Inferred latch — **A/B verified** |
| `BUGFIX-054` | `rtl/osDecoder.v:113` | `valid` had **two conflicting drivers** — clocked (`valid <= validnext`) and combinational (`{out,valid} = {data,1'b1}`). Now drives `validnext` only. | Multiple driver / race — **A/B verified** |
| `BUGFIX-055` | `rtl/Modules Integration.v:30`, `rtl/PCIE.v:237` | `RX.linkUp` was an **implicit wire with no driver** — consumed by `osDecoder` and `packet_identifier` but never declared as a port. Restored as `input linkUp`, driven from `pl_linkUp`. | Undriven X — **A/B verified** |

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

## 3. The three bugs that actually stopped your simulation

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

### 3.3 `FSM-008` — why the LTSSM **stalled in Polling** (the bug behind "it runs, but never finishes")

**Symptom.** After `SIM-006`/`SIM-007` removed the time-0 hang, the simulation
advanced and the LTSSM trained out of `Detect`, but then **sat in Polling** and
never reached `Configuration`, `L0`, or link-up.

**Root cause — the two sides drive `finish` with different lifetimes.**
`mainLTSSM` arbitrates between the TX and RX sub-FSMs using four wires
(`PCIE.v:149-152`):

| `mainLTSSM` name | actual net | producer | lifetime of the request |
|---|---|---|---|
| `finishTx` / `gotoTx` | `TXFinishFlag` / `TXExitTo` | `TxLtssm.v` | **LEVEL** — held high |
| `finishRx` / `gotoRx` | `RXfinish` / `RXexitTo` | `Master_RX_LTSSM.v` | **ONE-CYCLE STROBE** |

* On the TX side, `TxLtssm.v:140-177` computes `ExitToFlag` combinationally and
  sets it to `1` for as long as the state condition holds
  (`PollingConfigration && OSCount >= 16`). Registered at `TxLtssm.v:785-786`,
  so `TXFinishFlag`/`TXExitTo` stay asserted across **many** cycles.
* On the RX side, `FSM-003` deliberately removed a latch and gave `finish` a
  default of `1'b0`; its mini-FSM asserts `finish = 1'b1` **only** in the
  `success` state and immediately returns to `start`
  (`Master_RX_LTSSM.v:238-252`). So `RXfinish`/`RXexitTo` are a genuine
  **single-cycle** pulse, and `exitTo` is only meaningful during it.

The transition out of Polling was written as

```verilog
// rtl/maintlssm.v, {pollingConfiguration,pollingConfiguration} item — BEFORE
if (finishTx && finishRx && gotoTx==configurationLinkWidthStart
                        && gotoRx==configurationLinkWidthStart)
```

That requires a **one-cycle strobe to land on the same clock edge as a level**,
with both exit targets matching. TX and RX progress independently — TX's request
depends on `OSCount`, RX's on its own comparators and timers — so when RX pulses
first, its request is **discarded on the very next cycle and never re-issued**.
The FSM then waits forever in `Polling.Configuration`. This is a race, not a
deadlock: it can pass by luck and fail on the next run, which is why it looked
intermittent.

**Why `FSM-006` did not already cover it.** `FSM-006` identified exactly this
failure mode and fixed it with sticky `txPollingDone` / `rxPollingDone` flags —
but only for the single transition `{detectActive,detectActive} → pollingActive`.
Every *later* both-strobe transition still used the raw coincidence test:

| transition | old condition | effect |
|---|---|---|
| `{pollingConfiguration,pollingConfiguration}` → `configurationLinkWidthStart` | both strobes, same edge | **the reported stall** |
| `{configurationComplete,configurationComplete}` → `configurationIdle` | both strobes, same edge **+ typo** | would stall Configuration |
| `{recoveryIdle,recoveryIdle}` → `L0` | both strobes, same edge | would stall Recovery |
| `{configurationLinkWidthAccept,…}` → `configurationLanenumWait` (`DEVICETYPE==1`) | both strobes, same edge | upstream builds only |

**Second defect found in the same pass (copy/paste typo).**
`{configurationComplete,configurationComplete}` read:

```verilog
// BEFORE — note gotoRx tested TWICE, gotoTx never tested at all
if (finishRx&&gotoRx==configurationIdle&&finishTx&&gotoRx==configurationIdle)
```

so the TX side's requested exit state was **never checked**. Combined with the
race above this transition was doubly broken.

**Fix.** Generalize the `FSM-006` pattern instead of repeating it per
transition. Four registers latch each side's outstanding request
(`rtl/maintlssm.v:98`):

```verilog
reg       txHsValid;   reg [4:0] txHsTarget;
reg       rxHsValid;   reg [4:0] rxHsTarget;
```

Captured in the clocked block (`:374`): when a side strobes `finish` with a
non-`detectQuiet` target, the target is **remembered**. The capture is retired
as soon as the substate pair actually moves, and dropped entirely on any return
to `Detect` or on `forceDetect`, so a stale request can never shortcut a later
handshake or a retry. The case items now compare the sticky copies, so the two
sides no longer need to agree on a cycle:

```verilog
// AFTER
if ((txHsValid && txHsTarget == configurationLinkWidthStart) &&
    (rxHsValid && rxHsTarget == configurationLinkWidthStart))
```

**Deliberately not changed.** Requests to `detectQuiet` are *not* captured —
the abort/timeout paths are still evaluated combinationally on the live strobes
and keep priority. Latching an abort would let it fire after its cause is gone.
Single-sided transitions (e.g. `:625` `finishRx&&gotoRx==configurationLanenumAccept`)
were already satisfiable and are untouched. `FSM-006`'s existing
`txPollingDone`/`rxPollingDone` are left in place rather than folded in, so the
one transition already known to work is not disturbed.

**Verification — what was actually executed here.**

| check | result |
|---|---|
| slang elaboration, `--top PCIe`, all 55 `rtl/*.v` | **0 errors, 1310 warnings** — byte-identical to the pre-change baseline (no new warnings) |
| yosys `proc; opt_clean; check -noinit; stat` on `mainLTSSM` | **0 problems**, **0 `$dlatch`** |
| cell-count A/B (`git stash` vs. working tree) | `$adff` 22 → **26** (+4 = the new sticky regs), `$dff` 7 → **7**, `$eq` 504 → 509, `$mux` 764 → 798 — additive only |
| QuestaSim re-run | **NOT VERIFIED** — the simulator exists only on your Windows machine |

The A/B is the important one: the change is provably *additive* at the flop
level, no existing storage element was altered, and nothing new infers a latch.

**What you need to confirm.** Re-run and watch the substate pair leave
`{pollingConfiguration,pollingConfiguration}` (= `3,3`) for
`{configurationLinkWidthStart,…}` (= `4,4`), then continue to `L0` (= `10`).
If it still stalls, the remaining candidate is that one side never asserts its
request at all (e.g. TX's `OSCount` never reaching 16, or RX's `success` state
never entered) — that is a datapath/timer question, not this handshake, and the
sticky flags make it directly visible: probe `txHsValid`/`txHsTarget` and
`rxHsValid`/`rxHsTarget` and whichever stays `0` names the side that never asked.

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

## 5. Deeper findings — what was fixed, and what still needs a decision

Items 5.1 and 5.2 were reported as "found but not changed" in the first pass of
this audit because they needed a design decision. **That decision was given, and
both are now fixed** (`BUGFIX-048`…`BUGFIX-053`). What remains open is 5.3, plus a
newly discovered structural limit inside `osDecoder` described at the end of 5.1.

### 5.1 `rtl/osDecoder.v` — non-constant `for` loop bound (**was** the closure's synthesis blocker) — FIXED

The original code was

```verilog
always@(out)
    for (j = 0; j < 128<<numberOfShifts; j = j+8)
        outOs[(lanesOffsets[11*lane_iter +: 11]+index_iter)+:8] = out[j+:8];
```

`numberOfShifts` is a `reg`, so the bound was a runtime value. Hardware can only be
built from such a loop by unrolling it, which needs a constant trip count, so yosys
refused to read the file at all:

```
osDecoder.v:181: ERROR: 2nd expression of procedural for-loop is not constant!
```

Because `RX` instantiates `osDecoder` (`rtl/Modules Integration.v:107`), this blocked
synthesis of the **entire closure**, not just this leaf.

**`BUGFIX-048`** loops to the constant maximum and gates the body on the original
bound. That is exactly equivalent, because `numberOfShifts` can only be 0…4:

| lanes | 1 | 2 | 4 | 8 | 16 |
|---|---|---|---|---|---|
| `numberOfShifts` | 0 | 1 | 2 | 3 | 4 |
| `128<<numberOfShifts` | 128 | 256 | 512 | 1024 | **2048** |
| iterations (`bound/8`) | 16 | 32 | 64 | 128 | **256** |

The maximum is 2048, which is also exactly the width of `out` — so 2048 is both the
largest legal bound and the largest *meaningful* one (`out[j+:8]` is in range only
for `j <= 2040`). Iterating `j = 0,8,…,2040` and executing the body only while
`j < (128<<numberOfShifts)` performs the same iterations, in the same order, with the
same values.

Fixing that one line exposed four further defects in the same block, all fixed too:

| ID | Defect | Why it mattered |
|---|---|---|
| `BUGFIX-049` | `always@(out)` read `numberOfShifts`, `numberOfDetectedLanes`, `lane_iter`, `index_iter` but was sensitive only to `out` | Synthesis ignores hand-written sensitivity lists, so **simulation and synthesis disagreed** — a changed lane count with a stable `out` left `outOs` stale in sim but not in silicon |
| `BUGFIX-050` | `lane_iter`/`index_iter` were never initialized at block entry **and** were also driven from the clocked reset branch | Two processes driving one `reg` (clocked + combinational) is a multiple-driver conflict, and the block had combinational feedback through values it was supposed to compute from scratch |
| `BUGFIX-051` | No `default` in the `numberOfDetectedLanes` or `gen` cases | Inferred latches. A stale `numberOfShifts` of 5/6/7 made the old bound 4096/8192/16384 — **reading past the end of the 2048-bit `out`** |
| `BUGFIX-052` | `outOs` only partially assigned | For fewer than 16 lanes the unused lane regions kept stale ordered-set data and inferred a 2048-bit latch |

`BUGFIX-050` is worth calling out because the old code only ever *appeared* to work,
and only by coincidence: the trip count is always `16 × numberOfDetectedLanes`, so
after a full evaluation `lane_iter` wrapped back to 0 and `index_iter` reached 128
and wrapped to 0 in its 7 bits. That coincidence holds **only** for lane counts in
{1,2,4,8,16} — precisely the counts `BUGFIX-051` now has to default. For any other
count the iterators never returned to zero and every later de-interleave was written
to the wrong lanes.

**Verified (executed in sandbox):**

| yosys pass | Before | After |
|---|---|---|
| `read_verilog` | **ERROR** at line 181, aborts in 1.2 s | **SUCCESS** in 5.6 s |
| `+ hierarchy -top osDecoder` | never reached | SUCCESS, 5.7 s |
| `+ proc_clean … proc_arst` | never reached | SUCCESS, 14.2 s, **no `Multiple edge sensitive events`** |
| `+ proc_mux` and beyond | never reached | **does not complete** — see below |
| whole closure `hierarchy -top PCIe; check -noinit` | never reached (read aborted) | **completes, 605 s, 1222 problems** |

#### What still does not work in `osDecoder`, and why it is not something I should change unasked

`proc_mux` — the pass that converts decision trees into multiplexers — does not
finish. I bisected it, and **it is not caused by any of the fixes above**:

| Experiment (throwaway copies in `/tmp`, repo untouched) | Result |
|---|---|
| Replace the whole de-interleave block with `outOs = out` | still does not complete |
| Hoist the loop-invariant `orderedSets\|(data)<<capacity` out of both 64-iteration loops (it is replicated 128× by unrolling — ≈3.1 M muxes) | still does not complete |
| `read_verilog` alone | **completes in 2–6 s** |
| A trivial control module through the identical flow | completes, 0 problems |

So the file is now *legal* and elaborates; the cost is in lowering the pre-existing
2048-bit datapath in the **first** `always@(*)` block (the ordered-set accumulator),
which uses variable-indexed writes into 2048-bit vectors and 2048-bit results
shifted by a 12-bit `capacity`. That block was not touched by this pass.

Making it synthesize efficiently means restructuring the datapath — e.g. a
`generate`-based per-lane slice, or an explicit byte permutation. The mapping is a
pure permutation (`out` byte *k* → `outOs` byte `16·(k mod N) + (k div N)`, with
`N = numberOfDetectedLanes`), so it is very expressible in hardware — but writing it
that way **is an architecture change**, which your rules put off limits without your
sign-off. **This is the one remaining `osDecoder` decision I need from you.**

### 5.2 `rtl/LMC.v` — `pipe_width` latch — FIXED and A/B verified

`BUGFIX-053`. `generation` is `input [2:0]`, so 0, 6 and 7 are reachable, but the
chain covered only 1…5 with no final `else`, so `pipe_width` held its previous value:
a latch. The block was also `always@(generation)` while reading `pipe_width`.

The fix is three lines and is **not an invention** — it matches the convention the
same author already used in the RX-side twin of this logic, `rtl/DataHandling.v:9`
(`always@*`) and `:107-111` (final `else` with `pipeWidth = 0;`). `LMC.v` was simply
the odd one out, which is exactly why only it inferred the latch.

`0` is the safe default here: `pipe_width` is used in `LMC.v` **only** in equality
comparisons (`pipe_width == 8/16/32 && …`, from line ~551 on) — never as a divisor,
shift amount or array index (verified by grep). So 0 matches none of them, the same
no-match sentinel `DataHandling` uses, and no handled generation changes behaviour.

**A/B verified with yosys**, before = commit `a828d38`, after = this commit, same
command, same machine:

| | Before | After |
|---|---|---|
| `Latch inferred for signal \LMC.\pipe_width [5:3]` | present | **gone** |
| `Latch inferred for signal \LMC.\pipe_width [2:0]` | present | **gone** |
| `$dlatch` cells | 1 | **0** |
| `$adff` cells | 65 | 65 (unchanged — `FSM-007` intact) |
| `Found and reported N problems` | 1 | 1 |
| runtime | 15.4 s | 14.0 s |

The one remaining reported problem is pre-existing and benign: `Wire LMC.count has an
unprocessed 'init' attribute`, from `reg [4:0] count = 0;` at `rtl/LMC.v:25`. A
declaration initializer is honoured in simulation and in FPGA bitstream init but not
by ASIC synthesis. It is a warning, not an error, and changing it would alter the
simulated initial value, so it was **left alone deliberately**.


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

### 5.6 Remaining closure problems after `BUGFIX-048`…`055` — **needs decisions, not applied**

`BUGFIX-048` made the whole closure checkable for the first time (previously every
module aborted at `read_verilog` on `osDecoder.v:181`). Running
`hierarchy -top PCIe; check -noinit` over all 46 synthesizable files now completes
in ~605 s and reports **1222 problems**, down from 1224. The two that
`BUGFIX-054`/`055` targeted are confirmed gone by A/B comparison of the two runs.

What is left, grouped by what a decision would require:

**(a) `InsertBlockToken_G3` — 6 signals with multiple conflicting drivers (400 bits)**

`DK`, `END_reg`, `SDB_reg`, `STB_reg`, `valid_reg` (80 bits each) and `NoMoreData`.
These are written by the 77 `` `en(i) `` macro expansions, which all live inside one
process — and that process is

```verilog
always @(negedge clk) begin        // rtl/InsertBlockToken_G3.v:456
```

**This is the most important new finding in this document.** The rest of the design,
and `InsertBlockToken_G3.v` itself (line 290), clock on `posedge clk`. Its twin file
`rtl/Insert_token_block.v` has no `negedge` block at all — every one of its six
processes is `posedge` or `@*`. So a whole datapath block here updates on the
**opposite clock edge** from its twin and from the rest of the design, a half-cycle
offset that also explains the driver conflicts.

Two further defects in the same region:

- `` `en(i) `` and `` `co(a) `` expand to `data_reg[8*i-1:0]` and
  `data_reg[632-1:8*i]`. At the boundary indices these are **out-of-bounds part
  selects** — at `i=0`, `data_reg[-1:0]`. yosys sets those bits to `undef`, which is
  X-injection into the datapath. This is the source of ~8,946 of the warnings
  (`InsertBlockToken_G3.v:371` ≈6,706 and `Insert_token_block.v:462` ≈2,240).
- Both files use **non-blocking `<=` inside `always @ *`** blocks
  (`InsertBlockToken_G3.v:371,374`, `Insert_token_block.v:462`).

**Why this was not fixed.** Deciding it means choosing which clock edge is correct
and which process should own each of the six registers — i.e. establishing design
intent for ~700 lines of macro-generated datapath across two files, with no way to
verify the result in simulation here. Getting it wrong would silently corrupt the
Gen3 token-insertion path. `negedge` → `posedge` at line 456 is *probably* the single
highest-value one-word fix in the repository, but it is exactly the kind of change
that should not be made on inference. **Your call.** Next free ID `BUGFIX-056`.

**(b) `RX.PIPEWIDTH` — 6 bits with multiple conflicting drivers**

Not yet root-caused. `PIPEWIDTH` inside `RX` is fed by `LMC_RX` (via
`DataHandling`), so a second driver exists somewhere in `rtl/Modules Integration.v`.
Needs the same treatment as `BUGFIX-055`. Not applied.

**(c) Three undriven `PCIe` top-level signals**

`PclkChangeAck`, `directed_speed_change_In`, `write_directed_speed_change`. The
first is consistent with `SIM-014`'s finding that the PCLK-change handshake is not
implemented in this design. The other two are inputs the LTSSM expects but nothing
drives. Whether to implement, tie off, or remove them is a design decision. Not
applied.

**(d) `RX_TB_Integration` is dead code with a latent elaboration error**

`rtl/Modules Integration.v:193`. It is **never instantiated anywhere** in `rtl/` or
`tb/`, which is why slang does not elaborate it (it is absent from the 11 elaborated
tops) and why QuestaSim never reported it — `vlog` compiles it, but nothing
elaborates it unless it is a simulation top. Had it been elaborated it would fail:
its `RX` instance at line 238 uses **positional** connections and passes **32
arguments to a 50-port module**, with an extra `pl_state_sts` at position 23 that
shifts everything after it. Its `linkUp` at position 29 is what revealed the missing
port fixed by `BUGFIX-055`. Repairing it means converting to named connections and
supplying 18 missing arguments. Not applied; flagging so you know it is unusable
as-is. Next free ID `SIM-016`.


## 6. Verification status

### 6.1 slang elaboration gate — **VERIFIED (executed in sandbox)**

```
python3 tools_check/slang_check.py --rtl-dir rtl --show 30
```

| Metric | Result |
|---|---|
| Files parsed | 55 |
| **Errors** | **0** |
| Warnings | **1310** (1311 before `BUGFIX-049` removed the incomplete-sensitivity warning; 1308 before `SIM-013` added an 11th elaborable bench) |
| Elaborated top-level instances | **11** (was 10 before `SIM-013`) |

The 11 elaborated tops cover the full closure plus the standalone benches.
Also verified both ways for `SIM-015`:

```
python3 tools_check/slang_check.py --rtl-dir rtl --define SIM_TIMER_PRESCALE=12   → 0 errors
python3 tools_check/slang_check.py --rtl-dir rtl                                  → 0 errors
```

So the `ifdef` is syntactically clean whether or not the macro is defined, and the
default build is provably unaffected.

### 6.2 yosys synthesis check — **VERIFIED for leaf modules; NOT obtained for the whole closure**

An important methodological correction to the first pass of this audit. The earlier
"~25 minutes of CPU, killed" measurements were for runs that elaborate the **whole
closure** (`hierarchy -top PCIe`) or a large module while reading all 46 files. Once
the sweep was narrowed to *leaf* modules read on their own, the same WASM yosys
finishes in **seconds**. Every result below was obtained that way and is reproducible.

| Module | Command scope | Result | Status |
|---|---|---|---|
| `LMC` | leaf, own file | 65 `$adff`, **0 `$dlatch`**, 1 benign pre-existing problem, 14.0 s | **completed** |
| `LMC` (before `BUGFIX-053`) | leaf, own file, commit `a828d38` | 65 `$adff`, **1 `$dlatch`** on `pipe_width`, 15.4 s | **completed** — the A/B baseline |
| `osDecoder` | leaf, own file, `read_verilog` | **no error**, 5.6 s | **completed** |
| `osDecoder` | `+ hierarchy -top osDecoder` | no error, 5.7 s | **completed** |
| `osDecoder` | `+ proc_clean … proc_arst` | no error, **no `Multiple edge sensitive events`**, 14.2 s | **completed** |
| `osDecoder` | `+ proc_mux` and beyond | does not complete; bisected to the pre-existing 2048-bit accumulator datapath (§5.1) | **did not complete** |
| `osDecoder` (before `BUGFIX-048`) | leaf, `read_verilog` | **`ERROR: 2nd expression of procedural for-loop is not constant!`** at line 181, aborts in 1.2 s | **completed** — the A/B baseline |
| `mainLTSSM` | full read set | clean, 0 problems, 29 registers | completed earlier |
| `OS_GENERATOR` | full read set | see the caveat below | **partial** |
| whole closure (`PCIe`) | all 46 files, `read_verilog` only | **0 errors**, 34 s | **completed** |
| whole closure (`PCIe`) | `hierarchy -top PCIe; check -noinit` | **completes**, 605 s, 1222 problems (was 1224 before `BUGFIX-054`/`055`) | **completed** |

**The two A/B pairs are the strongest evidence in this document**, because both sides
were executed in the same sandbox with the same command and differ only by the fix:

- `osDecoder` `read_verilog`: ERROR in 1.2 s → success in 5.6 s (`BUGFIX-048`)
- `LMC` `$dlatch` count: 1 → 0, with `$adff` unchanged at 65 (`BUGFIX-053`)

**Still only reasoned, not demonstrated — `OS_GENERATOR`.** What was executed and
observed is the *failure before the fix*: yosys aborted with `ERROR: Multiple edge
sensitive events found for this signal!` on register `D` in the process at
`OS_GENERATOR.v:267`. That is the evidence `BUGFIX-047` was written against and it is
recorded verbatim in the source banner. The post-fix re-run was started three times
and killed each time without producing output — not because it reported an error, but
because `OS_GENERATOR.v` is ~86 KB containing a ~2000-line process and does not
behave like a leaf. So "the error is gone" remains **reasoned from the fix's
structure** (chaining the functional branch onto the reset test is exactly what
`PROC_ARST` requires, and the identical restructuring is *demonstrated* to work in
`LMC.v`, where 65 `$adff` cells with async reset are now inferred). Confirm it with
your own synthesis tool.

Reproduce any of it:

```bash
# leaf modules - seconds, and these are the runs behind every number above
cd /tmp && cp <repo>/rtl/LMC.v . && yosys -p \
  'read_verilog "LMC.v"; hierarchy -top LMC; proc; opt_clean; check -noinit; stat'

# the whole closure, on a native yosys build (recommended)
yosys -p "read_verilog rtl/*.v; hierarchy -top PCIe; proc; check -noinit; stat"

# the WASM path used in the sandbox
bash tools_check/yosys_fixed.sh LMC osDecoder
```

Note that `tools_check/yosys_fixed.sh` still carries a **sweep-only** `/tmp` patch of
the `osDecoder.v:181` loop bound. That patch is now **obsolete for the repository
file** — `BUGFIX-048` fixed it properly — and is left in the script only so the
historical baseline remains reproducible. It never modifies the repository.

yosys is **not** a substitute for your target synthesis tool. It is used here only as
a licence-free structural check for the `proc`/`check` classes of problem:
async-reset lifting, inferred latches, combinational loops, uninitialised state.

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

**Leaf-module yosys runs that COMPLETED** (these back every number in §6.2):

```bash
cd /tmp && cp <repo>/rtl/LMC.v .            # after BUGFIX-053
yosys -p 'read_verilog "LMC.v"; hierarchy -top LMC; proc; opt_clean; check -noinit; stat'
#   -> 65 $adff, 0 $dlatch, "Found and reported 1 problems", 14.0 s
git show a828d38:rtl/LMC.v > LMC.v          # before BUGFIX-053, same command
#   -> 65 $adff, 1 $dlatch, "Latch inferred for signal `\LMC.\pipe_width [5:3]'" and "[2:0]"

cd /tmp && cp <repo>/rtl/osDecoder.v .      # after BUGFIX-048..052
yosys -p 'read_verilog "osDecoder.v"'                                  # 5.6 s, no error
yosys -p 'read_verilog "osDecoder.v"; hierarchy -top osDecoder'         # 5.7 s, no error
yosys -p '... ; proc_clean; proc_rmdead; proc_prune; proc_init; proc_arst'  # 14.2 s, no error
git show a828d38:rtl/osDecoder.v > osDecoder.v                          # before BUGFIX-048
yosys -p 'read_verilog "osDecoder.v"'
#   -> osDecoder.v:181: ERROR: 2nd expression of procedural for-loop is not constant!
```

**Started but killed — no result obtained.** All are WASM-throughput casualties on
non-leaf scopes, not design errors (§6.2):

```bash
bash tools_check/yosys_sweep.sh      # broad per-module sweep - every module aborted
                                     # at read on osDecoder.v:181 (before BUGFIX-048)
bash tools_check/yosys_targeted.sh   # targeted per-module sweep - killed
bash tools_check/yosys_closure.sh    # hierarchy -top PCIe - killed at ~25 min CPU
bash tools_check/yosys_fixed.sh OS_GENERATOR TX_LTSSM LMC mainLTSSM Timer   # killed
yosys -p '...; hierarchy -top osDecoder; proc; opt_clean; check; stat'      # hangs in proc_mux
```

**Bisection experiments on throwaway `/tmp` copies** (the repository was never
modified by any of these) — used to prove the `proc_mux` hang is pre-existing and not
caused by `BUGFIX-048`…`052`:

```bash
# de-interleave block replaced by `outOs = out`        -> still hangs
# loop-invariant shift hoisted out of both 64x loops   -> still hangs
# OSD_OUT_BITS reduced 2048 -> 128 (16 iterations)     -> still hangs
# read_verilog alone                                   -> completes in 2-6 s
# trivial control module through the identical flow     -> completes, 0 problems
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
BUGFIX-046  BUGFIX-047  BUGFIX-048  BUGFIX-049  BUGFIX-050  BUGFIX-051
BUGFIX-052  BUGFIX-053  BUGFIX-054  BUGFIX-055
FSM-005     FSM-006     FSM-007     FSM-008
SIM-003     SIM-004     SIM-006     SIM-007     SIM-008     SIM-009
SIM-010     SIM-011     SIM-012     SIM-013     SIM-014     SIM-015
WIDTH-001
```

That is 26 IDs: 10 `BUGFIX`, 3 `FSM`, 12 `SIM`, 1 `WIDTH`.

Pre-existing in the repository from earlier passes (unchanged, still present):
`FSM-001`…`FSM-004`, `SIM-002`, and 33 `BUGFIX-nnn` IDs.

The full register, verified by `grep -rnoE "(BUGFIX|FSM|SIM|WIDTH)-[0-9]{3}" rtl/
tb/ tb_edited/` (64 distinct IDs in total: 43 `BUGFIX`, 7 `FSM`, 13 `SIM`, 1 `WIDTH`):

| Prefix | Range present | Count | Numbers that were **never allocated** |
|---|---|---|---|
| `BUGFIX` | 001–055 | 43 | 007, 008, 013, 019, 022, 023, 024, 025, 026, 027, 029, 032 |
| `FSM` | 001–007 | 7 | none — contiguous |
| `SIM` | 002–015 | 13 | 001, 005 |
| `WIDTH` | 001 | 1 | none |

Do **not** reuse a gap number: an ID that is absent from the tree is still absent
from the history of earlier passes, and reusing one makes it impossible to tell
which pass introduced a given comment. Allocate forward from the next free ID.

**Next free IDs:** `BUGFIX-056`, `FSM-009`, `SIM-016`, `WIDTH-002`.

---

## 10. Recommended next actions, in priority order

1. **Run `make sim FAST_TIMERS=1 RUN_TIME="2 ms"` and confirm the LTSSM reaches
   `L0`** — not merely that it leaves `Detect`. Items 1–2 of the previous
   revision are now *done*: the time-0 hang is gone and training advances out of
   `Detect`. The blocking question is `FSM-008` (§3.3): watch the substate pair
   go `{3,3}` → `{4,4}` → … → `{10,10}`.
   **If it still stalls**, probe `txHsValid`/`txHsTarget`/`rxHsValid`/`rxHsTarget`
   in the waveform — whichever side's `…Valid` stays `0` is the side that never
   issued its exit request, which localizes the fault to a datapath or timer
   problem rather than the handshake. That is the single highest-value check and
   it takes minutes. Then work through §6.3 item by item — none of it is verified
   yet.
2. **Re-run the UVM flow** (`make uvm-build && make uvm-run`). The time-0 hang is
   fixed (`SIM-006`/`SIM-007`) and you have confirmed the run now advances; what
   remains is checking it too reaches `L0` rather than stopping in Polling.
3. **Decide on the `osDecoder` datapath restructure** (§5.1, last subsection). The
   non-constant loop bound you asked about is fixed and verified — the file now
   reads, elaborates and lifts async resets cleanly. What remains is that
   `proc_mux` cannot lower the pre-existing 2048-bit accumulator datapath. The
   mapping is a pure byte permutation, so it is very expressible in hardware, but
   rewriting it that way is an architecture change and needs your explicit go-ahead.
4. **Decide on the `OS_GENERATOR` process split** (§5.3) — same situation: the
   demonstrated blocker is fixed, the residual `PROC_ARST` limitation needs a split.
5. **Decide on `SIM-012`** (`rtl/tb.v` undriven inputs) — enable the guard or not.
6. **Run your own synthesis tool over the closure.** Now that `osDecoder.v` reads,
   the one command that could not be run before is possible:
   `yosys -p "read_verilog rtl/*.v; hierarchy -top PCIe; proc; check -noinit; stat"`.
   On a native build this should finish; in the sandbox it did not (§6.2).
7. Only after 1–2 pass: attempt a true-scale run (§8.3) to validate real timeout
   behaviour.

---

*Generated 2026-09-23. All QuestaSim results in this document are NOT VERIFIED and
require a run on your machine. slang and yosys results were executed in the
sandbox and are reproducible with the commands in §7.*
