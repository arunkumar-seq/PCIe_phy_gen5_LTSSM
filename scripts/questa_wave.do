#-----------------------------------------------------------------------------
# scripts/questa_wave.do
#
# Waveform setup for the PCIe Gen5 PHY.  Sourced by questa_run.do (both batch
# and GUI) and safe to source by hand from the QuestaSim console after
# `vsim work.pcieTB`.
#
# The signal groups follow the design's own structure:
#   1. clocks / resets / LPIF state        - is the LTSSM being asked to train?
#   2. PIPE control                        - receiver detect, electrical idle,
#                                            PhyStatus, PowerDown, Rate
#   3. mainLTSSM handshake                 - substateTx/Rx, finishTx/Rx,
#                                            gotoTx/Rx and the FSM-006 sticky
#                                            txPollingDone / rxPollingDone
#   4. TX PIPE datapath                    - TxData/TxDataValid/TxDataK/
#                                            TxSyncHeader/TxStartBlock
#   5. RX PIPE datapath                    - RxData/RxDataValid/RxDataK
#   6. LPIF data flow                      - lp_irdy/lp_data/lp_valid vs
#                                            pl_trdy/pl_data/pl_valid
#   7. equalization                        - the Gen3+ preset/coefficient
#                                            handshake pcieTB drives
#
# Hierarchy (rtl/PCIE.v):
#   pcieTB.pcie                -> PCIe          (the DUT)
#   pcieTB.pcie.mainltssm      -> mainLTSSM     (rtl/maintlssm.v)
#   pcieTB.pcie.TX             -> TOP_MODULE    (rtl/TX .v)
#   pcieTB.pcie.rx             -> RX            (rtl/Modules Integration.v)
# The same groups work for the UVM environment by overriding the paths, e.g.
#   set ::TB_PATH /hdl_top ; set ::DUT_PATH /hdl_top/DUT ; do questa_wave.do
# which is what tb/sim/design.do and tb/sim/wave.do address.
#
# Every add-wave is wrapped in `catch`: a signal that does not exist in a
# particular parameterization must not abort the whole waveform setup.
#-----------------------------------------------------------------------------

if {![info exists ::TB_PATH]}  { set ::TB_PATH  /pcieTB }
if {![info exists ::DUT_PATH]} { set ::DUT_PATH $::TB_PATH/pcie }

set LTSSM $::DUT_PATH/mainltssm
set TXP   $::DUT_PATH/TX
set RXP   $::DUT_PATH/rx

proc w {args} {
    foreach s $args {
        if {[catch {add wave -noupdate $s} err]} {
            # keep going; report once so a wrong path is still visible
            echo "  (wave: skipped $s)"
        }
    }
}
proc wradix {radix args} {
    foreach s $args {
        if {[catch {add wave -noupdate -radix $radix $s} err]} {
            echo "  (wave: skipped $s)"
        }
    }
}

quietly WaveActivateNextPane {} 0

# --- 1. clocks, resets, LPIF state -----------------------------------------
w $::TB_PATH/CLK
w $::TB_PATH/reset
wradix binary $::TB_PATH/lp_state_req
wradix unsigned $::TB_PATH/pl_state_sts
w $::TB_PATH/pl_linkUp
wradix unsigned $::TB_PATH/pl_speedmode
w $::DUT_PATH/width

# --- 2. PIPE control --------------------------------------------------------
w $::TB_PATH/TxDetectRx_Loopback
w $::TB_PATH/TxElecIdle
w $::TB_PATH/PhyStatus
wradix binary $::TB_PATH/PowerDown
wradix unsigned $::TB_PATH/Rate
wradix unsigned $::TB_PATH/RxStatus
w $::TB_PATH/RxElectricalIdle          ;# SIM-014: now driven, was X
w $::TB_PATH/GetLocalPresetCoeffcients

# --- 3. mainLTSSM handshake (FSM-005 / FSM-006) -----------------------------
# These are the signals to watch when checking the DetectActive -> PollingActive
# fix: finishTx and finishRx are ONE-CYCLE strobes, so before FSM-006 the
# transition only fired if both landed on the same Pclk edge.  txPollingDone /
# rxPollingDone are the new sticky captures; substateTx/substateRx must leave
# detectQuiet deterministically (FSM-005) and reach pollingActive (FSM-006).
wradix unsigned $LTSSM/substateTx
wradix unsigned $LTSSM/substateRx
w $LTSSM/finishTx
w $LTSSM/finishRx
wradix unsigned $LTSSM/gotoTx
wradix unsigned $LTSSM/gotoRx
w $LTSSM/txPollingDone                 ;# FSM-006
w $LTSSM/rxPollingDone                 ;# FSM-006
wradix unsigned $LTSSM/currentState
wradix unsigned $LTSSM/nextState
wradix unsigned $LTSSM/GEN
w $LTSSM/linkUp
w $LTSSM/width                         ;# SIM-006: DUT side of the encoding
w $LTSSM/forceDetect                   ;# SIM-014: now a clean 0 from the bench

# --- 4. TX PIPE datapath ----------------------------------------------------
wradix hexadecimal $::TB_PATH/TxData
w $::TB_PATH/TxDataValid
wradix binary $::TB_PATH/TxDataK
wradix binary $::TB_PATH/TxSyncHeader
w $::TB_PATH/TxStartBlock

# --- 5. RX PIPE datapath ----------------------------------------------------
wradix hexadecimal $::TB_PATH/RxData
w $::TB_PATH/RxDataValid
wradix binary $::TB_PATH/RxDataK
wradix binary $::TB_PATH/RxSyncHeader
w $::TB_PATH/RxStartBlock

# --- 6. LPIF data flow ------------------------------------------------------
w $::TB_PATH/lp_irdy
wradix hexadecimal $::TB_PATH/lp_data
w $::TB_PATH/lp_valid
w $::TB_PATH/pl_trdy
wradix hexadecimal $::TB_PATH/pl_data
w $::TB_PATH/pl_valid
w $::TB_PATH/lp_tlpstart
w $::TB_PATH/lp_tlpend

# --- 7. equalization --------------------------------------------------------
wradix hexadecimal $::TB_PATH/LocalTxPresetCoefficients
w $::TB_PATH/LocalTxCoefficientsValid
wradix hexadecimal $::TB_PATH/TxDeemph
wradix hexadecimal $::TB_PATH/LF
wradix hexadecimal $::TB_PATH/FS

# --- per-lane RX LTSSM (lane 0 only; 16 lanes makes the window unreadable) ---
catch {add wave -noupdate -radix unsigned $RXP/rxltssm/masterRxLTSSM/currentState}
catch {add wave -noupdate -radix unsigned $RXP/rxltssm/masterRxLTSSM/substate}
catch {add wave -noupdate $RXP/rxltssm/orderedSets}

#-----------------------------------------------------------------------------
# Readability
#-----------------------------------------------------------------------------
catch {TreeUpdate [SetDefaultTree]}
catch {configure wave -namecolwidth 220}
catch {configure wave -valuecolwidth 120}
catch {configure wave -justifyvalue left}
catch {configure wave -signalnamewidth 1}
catch {configure wave -snapdistance 10}
catch {configure wave -datasetprefix 0}
catch {configure wave -rowmargin 4}
catch {configure wave -childrowmargin 2}
catch {configure wave -gridoffset 0}
catch {configure wave -gridperiod 1}
catch {configure wave -griddelta 40}
catch {configure wave -timeline 0}
catch {configure wave -timelineunits ns}
catch {update}

echo "questa_wave: waveform groups loaded for DUT path $::DUT_PATH"
