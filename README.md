# pcie5_phy
PCIE 5.0 Graduation project (Verification Team)

To run the Environment: 
- navigate to tb/sim
- run  `make build` to build the environment
- run `make run` to run the code

---

## Running from the repository root (added 2026-09-23)

The instructions above (`tb/sim` -> `make build` / `make run`) are unchanged and
still the way to run the UVM environment. A root-level `Makefile` was added on top
of them; it does not modify `tb/sim/Makefile`, it delegates to it.

From the repository root:

```bash
make help                       # list every target
make compile                    # vlog rtl/*.v  -> sim/work
make sim                        # bounded batch run of rtl/pcieTB.v
make wave                       # same run in the GUI with waveform groups loaded
make sim FAST_TIMERS=1          # all LTSSM timeouts 4096x shorter (see below)
make uvm-build && make uvm-run  # the UVM flow above, from the root
make lint                       # slang elaboration gate (no licence needed)
make synth                      # yosys synthesis check   (no licence needed)
```

If `vlog`/`vsim` are not on `PATH`:

```bash
make sim QUESTA_BIN="C:/questasim64_10.4e/win64/"
```

`make` itself still needs Cygwin or MinGW on Windows - see `configure-make.md`.

### Please read before concluding the LTSSM is stuck

`rtl/pcieTB.v` models the LTSSM timeouts at **true PCIe scale**. With its 10 ns
clock, leaving `Detect` alone costs about 6,000,000 cycles (~60 ms of simulated
time), so a short `run` window legitimately shows the link sitting in
`Detect.Active`. `make sim FAST_TIMERS=1` compiles with
`+define+SIM_TIMER_PRESCALE=12` to divide every timeout by 4096 so a full
`Detect -> Polling -> Configuration -> L0` walk becomes observable in a couple of
milliseconds. The macro is **not** defined by default, so the normal build and
synthesis are unaffected.

Also note that `rtl/pcieTB.v` contains no `$finish` and its clock free-runs, so
`run -all` can never terminate. Every script here uses a bounded run instead.

### What changed in the RTL, and what still needs a decision

`docs/RTL_CHANGELOG.md` (and `.docx`) records every source change with its unique
change-ID, the root cause, and whether the result was actually verified. It also
lists the items that were found but deliberately **not** changed because they need
a design decision - most importantly `rtl/osDecoder.v:181`, whose non-constant
`for` loop bound is a hard synthesis blocker.

**No QuestaSim result in that document is verified** - the simulator only exists on
the developer's machine. Everything marked NOT VERIFIED there needs a re-run.
