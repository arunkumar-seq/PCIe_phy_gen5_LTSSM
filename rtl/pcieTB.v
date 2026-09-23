// SIMULATION-ONLY testbench for the PCIe top-level (NOT synthesizable).
// BUGFIX-001:
//   Original issue: module 'pcieTB' was defined TWICE - once inside rtl/PCIE.v
//   (a synthesizable RTL file) and once in this file. Duplicate module
//   definitions are an elaboration error when both files are compiled
//   together, and embedding a testbench in synthesizable RTL violates the
//   simulation/synthesis separation.
//   Fix: the pcieTB definition was removed from rtl/PCIE.v and this file is
//   now the single definition. The body kept here is the NEWER of the two
//   duplicates (it matches the current PCIe port list, drives the
//   equalization handshake and uses MAX_GEN=5); the older copy that used to
//   live in this file referenced stale ports (e.g. 'linkUp' instead of
//   'pl_linkUp') and could no longer elaborate against the DUT.
// Verified by: slang elaboration of rtl/*.v with --top PCIe (no duplicate-
//   definition error) and Questa flow scripts/questa_compile.do (NOT
//   VERIFIED in this environment - see docs/RTL_CHANGELOG.md).

module pcieTB;
    parameter MAXPIPEWIDTH = 32;
	parameter DEVICETYPE = 0; //0 for downstream 1 for upstream
	parameter LANESNUMBER =16;
	parameter GEN1_PIPEWIDTH = 8 ;	
	parameter GEN2_PIPEWIDTH = 8 ;	
	parameter GEN3_PIPEWIDTH = 8 ;								
	parameter GEN4_PIPEWIDTH = 8 ;	
	parameter GEN5_PIPEWIDTH = 8 ;	
	parameter MAX_GEN = 1;
reg CLK;
reg reset;
//output phy_reset,
//PIPE interface width
//output [1:0] width, ///////////////////which module
//TX_signals
wire [1:0] width;
wire [MAXPIPEWIDTH*LANESNUMBER-1:0]TxData;
wire [LANESNUMBER-1:0]TxDataValid;
wire [LANESNUMBER-1:0]TxElecIdle;
wire [LANESNUMBER-1:0]TxStartBlock;
wire [(MAXPIPEWIDTH/8)*LANESNUMBER-1:0]TxDataK;
wire [2*LANESNUMBER -1:0]TxSyncHeader;
wire [LANESNUMBER-1:0]TxDetectRx_Loopback;
//RX_signals
wire [MAXPIPEWIDTH*LANESNUMBER-1:0]RxData;
wire [LANESNUMBER-1:0]RxDataValid;////////////////////////////////////////
wire[(MAXPIPEWIDTH/8)*LANESNUMBER-1:0]RxDataK;
wire[LANESNUMBER-1:0]RxStartBlock;
wire[2*LANESNUMBER -1:0]RxSyncHeader;
wire[LANESNUMBER-1:0]RxValid;
wire [15:0]RxStandby;
reg	[3*LANESNUMBER -1:0]RxStatus;
reg [15:0]RxElectricalIdle;
//commands and status signals
wire [4*LANESNUMBER-1:0]PowerDown;
wire  [3:0]Rate;
reg [LANESNUMBER-1:0]PhyStatus;

//pclkcontrolsignal
wire [4:0]PCLKRate;
wire PclkChangeAck;
reg  PclkChangeOk;
//eq_signals
reg 	[18*LANESNUMBER -1:0]LocalTxPresetCoefficients;
wire 	[18*LANESNUMBER -1:0]TxDeemph;
reg 	[6*LANESNUMBER -1:0]LocalFS;
reg 	[6*LANESNUMBER -1:0]LocalLF;
wire 	[4*LANESNUMBER -1:0]LocalPresetIndex;
wire 	[LANESNUMBER -1:0]GetLocalPresetCoeffcients;
reg 	[LANESNUMBER -1:0]LocalTxCoefficientsValid;
wire 	[6*LANESNUMBER -1:0]LF;
wire 	[6*LANESNUMBER -1:0]FS;
wire 	[LANESNUMBER -1:0]RxEqEval;
wire 	[LANESNUMBER -1:0]InvalidRequest;
reg 	[6*LANESNUMBER -1:0]LinkEvaluationFeedbackDirectionChange;
wire    pl_trdy;
reg     lp_irdy;
reg     [512-1:0]lp_data;
reg     [64-1:0]lp_valid;
wire [512-1:0]pl_data;
wire [64-1:0] pl_valid;
reg  [3:0]lp_state_req;
wire [3:0]pl_state_sts;
wire [2:0]pl_speedmode;////////////////////////////////////////
reg lp_force_detect;
////lPIF start & end of TLP DLLP
reg [64-1:0]lp_dlpstart;
reg [64-1:0]lp_dlpend;
reg  [64-1:0]lp_tlpstart;
reg  [64-1:0]lp_tlpend;
wire [64-1:0]pl_dlpstart;
wire [64-1:0]pl_dlpend;
wire [64-1:0]pl_tlpstart;
wire [64-1:0]pl_tlpend;
wire [64-1:0]pl_tlpedb;
wire pl_linkUp;
//optional Message bus
wire [7:0] M2P_MessageBus;
reg  [7:0] P2M_MessageBus;

localparam[1:0]
        reset_   = 2'd0,
        active_  = 2'd1,
        retrain_ = 2'd2;
integer i;

initial
begin
    CLK = 0;
    reset = 0;
    // ---------------------------------------------------------------------
    // SIM-014  (pcieTB.v - five DUT inputs were declared but never driven)
    //
    // Root cause : this bench declares the DUT inputs it drives as `reg`s and
    //              assigns them from the initial block below, but five of them
    //              were never assigned anywhere:
    //                RxElectricalIdle[15:0]
    //                LinkEvaluationFeedbackDirectionChange[6*16-1:0]
    //                lp_force_detect
    //                PclkChangeOk
    //                P2M_MessageBus[7:0]
    //              An undriven `reg` stays X for the whole simulation, so X was
    //              being fed straight into the design. Three of the five are
    //              genuinely consumed inside rtl/PCIE.v:
    //                * RxElectricalIdle  -> PCIE.v:220 into the RX block, i.e.
    //                  per-lane electrical-idle detection sees X on all 16
    //                  lanes;
    //                * LinkEvaluationFeedbackDirectionChange -> PCIE.v:183 into
    //                  TOP_MODULE, i.e. the Gen3+ equalization feedback path
    //                  sees X;
    //                * lp_force_detect   -> PCIE.v:153 as mainLTSSM's
    //                  `.forceDetect(...)`, the very signal FSM-001 had to
    //                  restructure. With X there, the
    //                  `else if(forceDetect)` test in maintlssm.v evaluates to
    //                  "not taken" by luck rather than by design.
    //              (PclkChangeOk and P2M_MessageBus are declared as PCIe ports
    //              but are not connected to any submodule inside the closure -
    //              the PCLK-change handshake is not implemented in this design -
    //              so they are harmless; they are initialized anyway for a clean
    //              waveform.)
    // Impact     : X-propagation into RX idle detection, the equalization
    //              feedback and the LTSSM force-detect control. In the waveform
    //              viewer these show up as red/X traces, and any `wait()` or
    //              `if()` in the DUT that samples them is resolved by Verilog's
    //              "X is not true" rule instead of by a defined value - which
    //              makes failures look intermittent and very hard to debug.
    // Fix        : initialize all five to their defined INACTIVE values at the
    //              top of the existing initial block (before reset is released),
    //              and keep RxElectricalIdle at 0 - "not in electrical idle" -
    //              which matches what the UVM environment drives
    //              (hdl_top.sw connects {16{PIPE.RxElecIdle}} and pipe_if's
    //              RxElecIdle is 0). No DUT port, no protocol and no existing
    //              stimulus was changed; these lines only give previously-X
    //              nets a defined value. Testbench-only (pcieTB.v is explicitly
    //              simulation-only and not part of the synthesis closure).
    // Expected   : no X on RxElectricalIdle / LinkEvaluationFeedbackDirection-
    //              Change / lp_force_detect / PclkChangeOk / P2M_MessageBus in
    //              the waveform; the LTSSM's forceDetect input is a clean 0 so
    //              the FSM-001 synchronous re-init path is never taken by
    //              accident.
    // Verification: consumption of each signal traced through rtl/PCIE.v:153,
    //              183, 220 (done in sandbox); slang elaboration of rtl/*.v
    //              stays at 0 errors. QuestaSim re-run: NOT VERIFIED (the
    //              simulator only exists on the user's Windows machine).
    // ---------------------------------------------------------------------
    RxElectricalIdle                   = {16{1'b0}};   // SIM-014: not in electrical idle
    LinkEvaluationFeedbackDirectionChange = {(6*16){1'b0}};   // SIM-014: no EQ feedback
    lp_force_detect                    = 1'b0;         // SIM-014: no forced re-detect
    PclkChangeOk                       = 1'b0;         // SIM-014: unused in this design
    P2M_MessageBus                     = 8'h00;        // SIM-014: unused in this design
    #20
    reset = 1;
    #10
    lp_state_req = reset_;
    #10
    wait(TxDetectRx_Loopback);
    #10
    PhyStatus={16{1'b1}};
    RxStatus={16{3'b011}};
    #10
    RxStatus=16'd0;
    lp_state_req = active_;
    //wait(pl_state_sts == 3)
    //lp_state_req = retrain_;
    wait(GetLocalPresetCoeffcients == {16{1'b1}});
    LocalTxCoefficientsValid = {16{1'b1}};
    LocalTxPresetCoefficients={16*18{1'b1}};
    LocalLF={16*6{1'b1}};
    LocalFS={16*6{1'b1}};
	wait(pl_linkUp && pl_speedmode==3'd4 && pl_state_sts==active_);
	lp_state_req = active_;
	@(negedge CLK);
	lp_irdy=1;
	for (i=0;i<512;i=i+1) 
	begin
		lp_data[i]=$random;
		lp_tlpstart[i]=0;
		lp_tlpend[i]=0;
		lp_dlpend[i]=0;
		lp_dlpstart[i]=0;
	end
	lp_valid={2'b00, {62{1'b1}}};
	lp_tlpstart[0]=1;
	lp_tlpend[61]=1;
    // lp_dlpstart[0]=1;
    // lp_dlpend[5]=1;
	#10
	lp_irdy=0;
end
always #5 CLK = ~CLK;




PCIe #(
	
	.MAXPIPEWIDTH(32),
	.DEVICETYPE (0), //0 for downstream 1 for upstream
	. LANESNUMBER (16),
	. GEN1_PIPEWIDTH (8) ,	
	. GEN2_PIPEWIDTH (8) ,	
	. GEN3_PIPEWIDTH (8) ,								
	. GEN4_PIPEWIDTH (8) ,	
	. GEN5_PIPEWIDTH (8) ,	
	. MAX_GEN (5)
)
pcie
(
//clk and reset 
 CLK,
 reset,
 phy_reset,
//PIPE interface width
 width, ///////////////////which module
//TX_signals
 TxData,
 TxDataValid,
 TxElecIdle,
 TxStartBlock,
 TxDataK,
 TxSyncHeader,
 TxDetectRx_Loopback,
//RX_signals
 RxData,
 RxDataValid,////////////////////////////////////////
 RxDataK,
 RxStartBlock,
 RxSyncHeader,
 RxStatus,
 RxElectricalIdle,
//commands and status signals
 PowerDown,
 Rate,
 PhyStatus,

//pclkcontrolsignal
 PCLKRate,
 PclkChangeAck,
 PclkChangeOk,
//eq_signals
 LocalTxPresetCoefficients,
 TxDeemph,
 LocalFS,
 LocalLF,
 LocalPresetIndex,
 GetLocalPresetCoeffcients,
 LocalTxCoefficientsValid,
LF,
FS,
RxEqEval,
InvalidRequest,
LinkEvaluationFeedbackDirectionChange,
pl_trdy,
lp_irdy,
lp_data,
lp_valid,
pl_data,
pl_valid,
lp_state_req,
pl_state_sts,
pl_speedmode,////////////////////////////////////////
lp_force_detect,
////lPIF start & end of TLP DLLP
lp_dlpstart,
lp_dlpend,
lp_tlpstart,
lp_tlpend,
pl_dlpstart,
pl_dlpend,
pl_tlpstart,
pl_tlpend,
pl_tlpedb,
pl_linkUp,
//optional Message bus
M2P_MessageBus,
P2M_MessageBus,
RxStandby
);
assign {RxData,RxDataValid,RxDataK,RxValid,RxSyncHeader,RxStartBlock} = {TxData,TxDataValid,TxDataK,TxDataValid,TxSyncHeader,TxStartBlock}; 
endmodule
