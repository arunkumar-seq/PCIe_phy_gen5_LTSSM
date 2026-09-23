module PCIe #(
	
	parameter MAXPIPEWIDTH = 32,
	parameter DEVICETYPE = 0, //0 for downstream 1 for upstream
	parameter LANESNUMBER =16,
	parameter GEN1_PIPEWIDTH = 8 ,	
	parameter GEN2_PIPEWIDTH = 8 ,	
	parameter GEN3_PIPEWIDTH = 8 ,								
	parameter GEN4_PIPEWIDTH = 8 ,	
	parameter GEN5_PIPEWIDTH = 8 ,	
	parameter MAX_GEN = 1
)
(
//clk and reset 
input CLK,
input lpreset,
output phy_reset,
//PIPE interface width
output [1:0] width, ///////////////////which module
//TX_signals
output [MAXPIPEWIDTH*LANESNUMBER-1:0]TxData,
output [LANESNUMBER-1:0]TxDataValid,
output [LANESNUMBER-1:0]TxElecIdle,
output [LANESNUMBER-1:0]TxStartBlock,
output [(MAXPIPEWIDTH/8)*LANESNUMBER-1:0]TxDataK,
output [2*LANESNUMBER -1:0]TxSyncHeader,
output [LANESNUMBER-1:0]TxDetectRx_Loopback,
//RX_signals
input  	[MAXPIPEWIDTH*LANESNUMBER-1:0]RxData,
input   [LANESNUMBER-1:0]RxDataValid,
input	[(MAXPIPEWIDTH/8)*LANESNUMBER-1:0]RxDataK,
input	[LANESNUMBER-1:0]RxStartBlock,
input	[2*LANESNUMBER -1:0]RxSyncHeader,
input	[3*LANESNUMBER -1:0]RxStatus,
input   [15:0]RxElectricalIdle,
//commands and status signals
output  [4*LANESNUMBER-1:0]PowerDown,
output  [3:0] Rate,
input   [LANESNUMBER-1:0]PhyStatus,

//pclkcontrolsignal
output [4:0]PCLKRate,
output PclkChangeAck,
input  PclkChangeOk,
//eq_signals
input 	[18*LANESNUMBER -1:0]LocalTxPresetCoefficients,
output 	[18*LANESNUMBER -1:0]TxDeemph,
input 	[6*LANESNUMBER -1:0]LocalFS,
input 	[6*LANESNUMBER -1:0]LocalLF,
output 	[4*LANESNUMBER -1:0]LocalPresetIndex,
output 	[LANESNUMBER -1:0]GetLocalPresetCoeffcients,
input 	[LANESNUMBER -1:0]LocalTxCoefficientsValid,
output 	[6*LANESNUMBER -1:0]LF,
output 	[6*LANESNUMBER -1:0]FS,
output 	[LANESNUMBER -1:0]RxEqEval,
output 	[LANESNUMBER -1:0]InvalidRequest,
input 	[6*LANESNUMBER -1:0]LinkEvaluationFeedbackDirectionChange,

output pl_trdy,
input  lp_irdy,
input  [512-1:0]lp_data,
input  [64-1:0]lp_valid,
output [512-1:0]pl_data,
output [64-1:0] pl_valid,
input  [3:0]lp_state_req,
output [3:0]pl_state_sts,
output [2:0]pl_speedmode,////////////////////////////////////////
input lp_force_detect,
////lPIF start & end of TLP DLLP
input [64-1:0]lp_dlpstart,
input [64-1:0]lp_dlpend,
input [64-1:0]lp_tlpstart,
input [64-1:0]lp_tlpend,
output [64-1:0]pl_dlpstart,
output [64-1:0]pl_dlpend,
output [64-1:0]pl_tlpstart,
output [64-1:0]pl_tlpend,
output [64-1:0]pl_tlpedb,
output pl_linkUp,
//optional Message bus
output [7:0] M2P_MessageBus,
input  [7:0] P2M_MessageBus,
output  [15:0] RxStandby
);

wire WriteDetectLanesFlag;
wire [4:0] SetTXState;
wire TXFinishFlag;
wire [4:0]TXExitTo;
wire WriteLinkNumFlagTx,WriteLinkNumFlagRx;
wire [4:0] NumberDetectLanesfromtx;
wire [2:0]GEN; 
wire [4:0]numberOfDetectedLanes;
wire [4:0]RXsubstate;
wire [7:0]linkNumberRxInput,linkNumberTxInput,linkNumberRxOutput,linkNumberTxOutput;
wire [7:0] rateid,rateIdInTx;
wire upConfigureCapability,upConfigureCapabilityInTX;
wire RXfinish;
wire [4:0]RXexitTo;
///////////output pl_linkUp,////////////
wire witeUpconfigureCapability;
wire writerateid;
wire  directed_speed_change;
wire  [47:0] ReceiverpresetHintDSP;
wire  [63:0] TransmitterPresetHintDSP;
wire  [47:0] ReceiverpresetHintUSP;
wire  [63:0] TransmitterPresetHintUSP;
wire  [6*16-1:0]LF_register;
wire  [6*16-1:0]FS_register;
wire  [6*16-1:0]CursorCoff;
wire  [6*16-1:0]PreCursorCoff;
wire  [6*16-1:0]PostCursorCoff;
wire  [47:0] ReceiverpresetHintDSPIn;
wire  [63:0] TransmitterPresetHintDSPIn;
wire  [47:0] ReceiverpresetHintUSPIn;
wire  [63:0] TransmitterPresetHintUSPIn;
wire writeReceiverpresetHintDSP;
wire writeTransmitterPresetHintDSP;
wire writeReceiverpresetHintUSP;
wire writeTransmitterPresetHintUSP;
wire directed_speed_change_In;
wire write_directed_speed_chang;
wire [2:0] trainToGen;
wire [16*6-1:0] FSDSP,LFDSP;
wire disableScrambler;
wire turnOffScrambler_flag;
wire startSend16;

mainLTSSM #(
.Width(MAXPIPEWIDTH),
.DEVICETYPE(DEVICETYPE), //0 for downstream 1 for upstream
.GEN1_PIPEWIDTH(GEN1_PIPEWIDTH),	
.GEN2_PIPEWIDTH (GEN2_PIPEWIDTH) ,	
.GEN3_PIPEWIDTH (GEN3_PIPEWIDTH),	
.GEN4_PIPEWIDTH (GEN4_PIPEWIDTH) ,	
.GEN5_PIPEWIDTH (GEN5_PIPEWIDTH),
.LANESNUMBER(LANESNUMBER),
.MAX_GEN(MAX_GEN)
) mainltssm(
    .clk(CLK),
    .reset(lpreset),
    .lpifStateRequest(lp_state_req),
    .numberOfDetectedLanesIn(NumberDetectLanesfromtx),
    .rateIdIn(rateid),
    .upConfigureCapabilityIn(upConfigureCapability),
    .writeNumberOfDetectedLanes(WriteDetectLanesFlag),
    .writeUpconfigureCapability(witeUpconfigureCapability),
    .writeRateId(writerateid),
    .finishTx(TXFinishFlag),
    .finishRx( RXfinish),
    .gotoTx(TXExitTo),
    .gotoRx(RXexitTo),
    .forceDetect(lp_force_detect),
    .linkUp(pl_linkUp),
    .GEN(GEN),
    .numberOfDetectedLanesOut(numberOfDetectedLanes),
    .rateIdOut(rateIdInTx),
    .upConfigureCapabilityOut(upConfigureCapabilityInTX),//////not used in tx
    .lpifStateStatus(pl_state_sts),
    .substateTx(SetTXState),
    .substateRx(RXsubstate),
    .linkNumberInTx(linkNumberTxOutput),
    .linkNumberInRx(linkNumberRxOutput),
    .writeLinkNumberTx(WriteLinkNumFlagTx),
    .writeLinkNumberRx(WriteLinkNumFlagRx),
    .linkNumberOutTx(linkNumberTxInput),
    .linkNumberOutRx(linkNumberRxInput),
    .width(width),
    .ReceiverpresetHintDSPIn(ReceiverpresetHintDSPIn),
    .TransmitterPresetHintDSPIn(TransmitterPresetHintDSPIn),
    .ReceiverpresetHintUSPIn(ReceiverpresetHintUSPIn),
    .TransmitterPresetHintUSPIn(TransmitterPresetHintUSPIn),
    .writeReceiverpresetHintDSP(writeReceiverpresetHintDSP),
    .writeTransmitterPresetHintDSP(writeTransmitterPresetHintDSP),
    .writeReceiverpresetHintUSP(writeReceiverpresetHintUSP),
    .writeTransmitterPresetHintUSP(writeTransmitterPresetHintUSP),
    .directed_speed_change_In(directed_speed_change_In),
    .write_directed_speed_change(write_directed_speed_change),
    .LocalTxPresetCoefficients(LocalTxPresetCoefficients),
    .LocalFS(LocalFS),
    .LocalLF(LocalLF),
    .LocalTxCoefficientsValid(LocalTxCoefficientsValid),
    .LinkEvaluationFeedbackDirectionChange(LinkEvaluationFeedbackDirectionChange),
    .TxDeemph(TxDeemph),
    .LocalPresetIndex(LocalPresetIndex),
    .GetLocalPresetCoeffcients(GetLocalPresetCoeffcients),
    .LF(LF),
    .FS(FS),
    .RxEqEval(RxEqEval),
    .InvalidRequest(InvalidRequest),
    .directed_speed_change(directed_speed_change),
    .ReceiverpresetHintDSP(ReceiverpresetHintDSP),
    .TransmitterPresetHintDSP(TransmitterPresetHintDSP),
    .ReceiverpresetHintUSP(ReceiverpresetHintUSP),
    .TransmitterPresetHintUSP(TransmitterPresetHintUSP),
    .LF_register(LF_register),
    .FS_register(FS_register),
    .CursorCoff(CursorCoff),
    .PreCursorCoff(PreCursorCoff),
    .PostCursorCoff(PostCursorCoff),
    .trainToGen(trainToGen),
    .LFDSP(LFDSP),
    .FSDSP(FSDSP),
    .disableScrambler(disableScrambler),
    .PCLKRate(PCLKRate),
    .startSend16(startSend16),
    .turnOffScrambler_flag(turnOffScrambler_flag)
);

RX #(.DEVICETYPE(DEVICETYPE),.GEN1_PIPEWIDTH(GEN1_PIPEWIDTH),.GEN2_PIPEWIDTH(GEN2_PIPEWIDTH),.GEN3_PIPEWIDTH(GEN3_PIPEWIDTH),.GEN4_PIPEWIDTH(GEN4_PIPEWIDTH),.GEN5_PIPEWIDTH(GEN5_PIPEWIDTH))
rx
( .reset(lpreset), 
.clk(CLK), 
.GEN(GEN), 
.PhyStatus(PhyStatus), 
.RxValid(RxDataValid),
.RxStartBlock(RxStartBlock), 
.RxStatus(RxStatus),
.RxSyncHeader(RxSyncHeader), 
.RxElectricalIdle(RxElectricalIdle),
.RxData(RxData), 
.RxDataK(RxDataK),
.numberOfDetectedLanes(numberOfDetectedLanes),
.substate(RXsubstate),
.linkNumber(linkNumberRxInput),
.pl_tlpstart(pl_tlpstart), 
.pl_dllpstart(pl_dlpstart), 
.pl_tlpend(pl_tlpend),
.pl_dllpend(pl_dlpend), 
.pl_tlpedb(pl_tlpedb), 
.pl_valid(pl_valid), 
.pl_data(pl_data),
.pl_speedmode(pl_speedmode), 
.rateid(rateid),
.upConfigureCapability(upConfigureCapability),
.finish( RXfinish),
.exitTo(RXexitTo),
// BUGFIX-055: drive RX's restored linkUp input from the real link-up status.
// pl_linkUp is mainLTSSM's linkUp output (maintlssm.v:68), wired at line ~154.
.linkUp(pl_linkUp),
.witeUpconfigureCapability(witeUpconfigureCapability),
.writerateid(writerateid),
.linkNumberOut(linkNumberRxOutput),
.writeLinkNumber(WriteLinkNumFlagRx),
.ReceiverpresetHintDSPout(ReceiverpresetHintDSPIn),
.TransmitterPresetHintDSPout(TransmitterPresetHintDSPIn),
.ReceiverpresetHintUSPout(ReceiverpresetHintUSPIn),
.TransmitterPresetHintUSPout(TransmitterPresetHintUSPIn),
.ReceiverpresetHintDSP(ReceiverpresetHintDSP),
.TransmitterPresetHintDSP(TransmitterPresetHintDSP),
.ReceiverpresetHintUSP(ReceiverpresetHintUSP),
.TransmitterPresetHintUSP(TransmitterPresetHintUSP),
.writeReceiverpresetHintDSP(writeReceiverpresetHintDSP),
.writeTransmitterPresetHintDSP(writeTransmitterPresetHintDSP),
.writeReceiverpresetHintUSP(writeReceiverpresetHintUSP),
.writeTransmitterPresetHintUSP(writeTransmitterPresetHintUSP),
.LFDSP(LFDSP),
.FSDSP(FSDSP),
.CursorCoff(CursorCoff),
.PreCursorCoff(PreCursorCoff),
.PostCursorCoff(PostCursorCoff),
.directed_speed_change(directed_speed_change),
.trainToGen(trainToGen),
.disableScrambler(disableScrambler)
);

TOP_MODULE #
(
.MAXPIPEWIDTH(MAXPIPEWIDTH),
.DEVICETYPE(DEVICETYPE), //0 for downstream 1 for upstream
.LANESNUMBER(LANESNUMBER),
.GEN1_PIPEWIDTH(GEN1_PIPEWIDTH),	
.GEN2_PIPEWIDTH (GEN2_PIPEWIDTH) ,	
.GEN3_PIPEWIDTH (GEN3_PIPEWIDTH),	
.GEN4_PIPEWIDTH (GEN4_PIPEWIDTH) ,	
.GEN5_PIPEWIDTH (GEN5_PIPEWIDTH),	
.MAX_GEN(MAX_GEN))
TX
(.pclk(CLK),
.reset_n(lpreset),
.pl_trdy(pl_trdy),
.lp_irdy(lp_irdy),
.lp_data(lp_data),
.lp_valid(lp_valid),
.lp_dlpstart(lp_dlpstart),
.lp_dlpend(lp_dlpend),
.lp_tlpstart(lp_tlpstart),
.lp_tlpend(lp_tlpend),
.RxStatus(RxStatus),
.NumberDetectLanes(NumberDetectLanesfromtx),
.TxDetectRx_Loopback(TxDetectRx_Loopback),
.PowerDown(PowerDown),
.PhyStatus(PhyStatus),
.TxElecIdle(TxElecIdle),
.WriteDetectLanesFlag(WriteDetectLanesFlag),
.SetTXState(SetTXState),
.TXFinishFlag(TXFinishFlag),
.TXExitTo(TXExitTo), /////////////////////////
.WriteLinkNum(linkNumberTxOutput),//////////////////////////////
.WriteLinkNumFlag(WriteLinkNumFlagTx),
.ReadLinkNum(linkNumberTxInput),
.rateIdIn(rateIdInTx),
.upConfigureCapabilityIn(upConfigureCapabilityInTX),
.MainLTSSMGen(GEN),
.TxData16(TxData[31:0]),
.TxData15(TxData[63:32]),
.TxData14(TxData[95:64]),
.TxData13(TxData[127:96]),
.TxData12(TxData[159:128]),
.TxData11(TxData[191:160]),
.TxData10(TxData[223:192]),
.TxData9(TxData[255:224]),
.TxData8(TxData[287:256]),
.TxData7(TxData[319:288]),
.TxData6(TxData[351:320]),
.TxData5(TxData[383:352]),
.TxData4(TxData[415:384]),
.TxData3(TxData[447:416]),
.TxData2(TxData[479:448]),
.TxData1(TxData[511:480]),
.TxDataValid16(TxDataValid[0]),
.TxDataValid15(TxDataValid[1]),
.TxDataValid14(TxDataValid[2]),
.TxDataValid13(TxDataValid[3]),
.TxDataValid12(TxDataValid[4]),
.TxDataValid11(TxDataValid[5]),
.TxDataValid10(TxDataValid[6]),
.TxDataValid9(TxDataValid[7]),
.TxDataValid8(TxDataValid[8]),
.TxDataValid7(TxDataValid[9]),
.TxDataValid6(TxDataValid[10]),
.TxDataValid5(TxDataValid[11]),
.TxDataValid4(TxDataValid[12]),
.TxDataValid3(TxDataValid[13]),
.TxDataValid2(TxDataValid[14]),
.TxDataValid1(TxDataValid[15]),
.TxDataK16(TxDataK[3:0]),
.TxDataK15(TxDataK[7:4]),
.TxDataK14(TxDataK[11:8]),
.TxDataK13(TxDataK[15:12]),
.TxDataK12(TxDataK[19:16]),
.TxDataK11(TxDataK[23:20]),
.TxDataK10(TxDataK[27:24]),
.TxDataK9(TxDataK[31:28]),
.TxDataK8(TxDataK[35:32]),
.TxDataK7(TxDataK[39:36]),
.TxDataK6(TxDataK[43:40]),
.TxDataK5(TxDataK[47:44]),
.TxDataK4(TxDataK[51:48]),
.TxDataK3(TxDataK[55:52]),
.TxDataK2(TxDataK[59:56]),
 .TxDataK1(TxDataK[63:60]),
.TxSyncHeader1(TxSyncHeader[1:0]),
 .TxSyncHeader2(TxSyncHeader[3:2]),
 .TxSyncHeader3(TxSyncHeader[5:4]),
 .TxSyncHeader4(TxSyncHeader[7:6]),
 .TxSyncHeader5(TxSyncHeader[9:8]),
 .TxSyncHeader6(TxSyncHeader[11:10]),
 .TxSyncHeader7(TxSyncHeader[13:12]),
 .TxSyncHeader8(TxSyncHeader[15:14]),
 .TxSyncHeader9(TxSyncHeader[17:16]),
 .TxSyncHeader10(TxSyncHeader[19:18]),
 .TxSyncHeader11(TxSyncHeader[21:20]),
 .TxSyncHeader12(TxSyncHeader[23:22]),
 .TxSyncHeader13(TxSyncHeader[25:24]),
 .TxSyncHeader14(TxSyncHeader[27:26]),
 .TxSyncHeader15(TxSyncHeader[29:28]),
 .TxSyncHeader16(TxSyncHeader[31:30]),
 .TxStartBlock1(TxStartBlock[0]), 
 .TxStartBlock2(TxStartBlock[1]), 
 .TxStartBlock3(TxStartBlock[2]), 
 .TxStartBlock4(TxStartBlock[3]), 
 .TxStartBlock5(TxStartBlock[4]), 
 .TxStartBlock6(TxStartBlock[5]), 
 .TxStartBlock7(TxStartBlock[6]), 
 .TxStartBlock8(TxStartBlock[7]), 
 .TxStartBlock9(TxStartBlock[8]),
 .TxStartBlock10(TxStartBlock[9]), 
 .TxStartBlock11(TxStartBlock[10]),
 .TxStartBlock12(TxStartBlock[11]), 
 .TxStartBlock13(TxStartBlock[12]), 
 .TxStartBlock14(TxStartBlock[13]), 
 .TxStartBlock15(TxStartBlock[14]), 
 .TxStartBlock16(TxStartBlock[15]),
 .ReceiverpresetHintDSP(ReceiverpresetHintDSP), 
 .TransmitterPresetHintDSP(TransmitterPresetHintDSP),
 .ReceiverpresetHintUSP(ReceiverpresetHintUSP),
 .TransmitterPresetHintUSP(TransmitterPresetHintUSP),
 .LF_register(LF_register),
 .FS_register(FS_register),
 .CursorCoff_register(CursorCoff),
 .PreCursorCoff_register(PreCursorCoff),
 .PostCursorCoff_register(PostCursorCoff),
 .TrainToGen(trainToGen),
 .ReadDirectSpeedChange(directed_speed_change),
 .turnOff(disableScrambler),
 .RxStandby(RxStandby),
 .startSend16(startSend16),
 .turnOffScrambler_flag(turnOffScrambler_flag)
 );

assign phy_reset = lpreset;

endmodule

// BUGFIX-001: module 'pcieTB' (simulation-only testbench) used to be defined
// here as well as in rtl/pcieTB.v, creating a duplicate module definition.
// The single remaining definition now lives in rtl/pcieTB.v.
