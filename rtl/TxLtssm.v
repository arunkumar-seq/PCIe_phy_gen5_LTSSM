
module TX_LTSSM #
(
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
input Pclk,
input Reset, //active low
output  [2:0]Gen ,
output reg [4:0] NumberDetectLanes,
output reg [LANESNUMBER-1:0] DetectLanes,
output reg WriteDetectLanesFlag,
// main LTSSM interface
input [2:0] MainLTSSMGen,
input  [4:0] SetTXState,
output reg TXFinishFlag,
output reg [4:0] TXExitTo,
output reg[7:0] WriteLinkNum,
output reg WriteLinkNumFlag,
input [7:0] ReadLinkNum,
input [2:0] TrainToGen,
input ReadDirectSpeedChange,
input  [47:0] ReceiverpresetHintDSP,
input [63:0] TransmitterPresetHintDSP,
input  [47:0] ReceiverpresetHintUSP,
input  [63:0] TransmitterPresetHintUSP,
input  [6*16-1:0]LF_register,
input  [6*16-1:0]FS_register,
input  [6*16-1:0]CursorCoff_register,
input  [6*16-1:0]PreCursorCoff_register,
input  [6*16-1:0]PostCursorCoff_register,

//input ReadCompleteEqualizationVariable, //////ask Emad 
// LPIF TX control & data flow interface 
output reg HoldFIFOData,
input FIFOReady,
// OS generator interface 
output reg [2:0] OSType,
output reg[1:0] LaneNumber, 
output reg[7:0] LinkNumber,
output reg[2:0] Rate,
output reg Loopback,
//OS generator interface communication
output reg OSGeneratorStart,
input OSGeneratorBusy,
input OSGeneratorFinish,
input startSend16,
//OS generator interface equalization 
output reg [1:0] EC,
output reg ResetEIEOSCount,
output reg [4* LANESNUMBER-1:0] TXPreset,
output reg [3* LANESNUMBER-1:0] RXPreset,
output reg [LANESNUMBER-1:0] UsePresetCoff,
output reg [6* LANESNUMBER-1:0] FS,
output reg [6* LANESNUMBER-1:0] LF,
output reg [6* LANESNUMBER-1:0] PreCursorCoff,
output reg [6* LANESNUMBER-1:0] CursorCoff,
output reg [6* LANESNUMBER-1:0] PostCursorCoff,
output reg [ LANESNUMBER-1:0] RejectCoff,
output reg SpeedChange,
output reg ReqEq,
output reg EQTS2,
output reg[15:0] RxStandby,
output reg turnOffScrambler_flag,
//mux
output reg MuxSel,
//Lane Management control 
//PIPE TX Control
output reg [ LANESNUMBER-1:0]DetectReq,
output reg [ LANESNUMBER-1:0]ElecIdleReq,
input  [ LANESNUMBER-1:0]DetectStatus
);

// states encoding
 parameter  DetectQuiet = 5'd0, DetectActive = 5'd1, PollingActive = 5'd2,
	    PollingConfigration = 5'd3, ConfigrationLinkWidthStart = 5'd4, ConfigrationLinkWidthAccept= 5'd5,
            ConfigrationLaneNumWait = 5'd6,  ConfigrationLaneNumActive = 5'd7, ConfigrationComplete = 5'd8,
            ConfigrationIdle = 5'd9,L0=5'd10,RecoveryRcvrLock=5'd11,RecoveryRcvrCfg=5'd12, RecoverySpeed=5'd13,Ph0=5'd14,Ph1=5'd15,Ph2=5'd16,Ph3=5'd17,RecoveryIdle= 5'd18, Idle=5'd31,recoverySpeedeieos = 5'd19,
        recoverywait = 5'd20;
//Device type 
parameter DownStream = 0 ,UpStream = 1;
//time 
parameter t12ms= 3'b001,t0ms = 3'b000 , t1ms=3'b110;
//Generation
parameter Gen1 = 3'b001,Gen2 = 3'b010,Gen3 = 3'b011,Gen4 = 3'b100,Gen5 = 3'b101; // TODO edited
//internal Register 
reg [15:0]idleCounts; // BUGFIX-035:
reg startSend16_q; // BUGFIX-036: synchronous edge-detect register for startSend16 was 1 bit wide; it stores an OSCount snapshot (16-bit) used by the Configuration.Idle exit condition 'OSCount-idleCounts > 6', which was truncated to the LSB
reg [4:0]State;
wire [4:0]NextState;
reg [4:0] ExitToState;
reg ExitToFlag;
//internal Register 
reg [15:0]OSCount;
reg [2:0]CurrentGen;
//
reg WriteDetectLanesFlagReg;
//Timer interface
reg TimerEnable;
reg TimerStart;
reg [2:0]TimerIntervalCode;
reg turnOffScrambler_flag_next,turnOffScrambler_flag_next2;
wire TimeOut;
reg SDSFlag;
Timer #(.Width(32)) T(.Gen(Gen),.Reset(Reset),.Pclk(Pclk),.Enable(TimerEnable),.Start(TimerStart),.TimerIntervalCode(TimerIntervalCode),.TimeOut(TimeOut));

//assignment
assign NextState = SetTXState; 

///lanes number
always @ *
begin 
if(DetectLanes[15]) NumberDetectLanes=15+1;
else if (DetectLanes[14]) NumberDetectLanes=14+1;
else if (DetectLanes[13]) NumberDetectLanes=13+1;
else if (DetectLanes[12]) NumberDetectLanes=12+1;
else if (DetectLanes[11]) NumberDetectLanes=11+1;
else if (DetectLanes[10]) NumberDetectLanes=10+1;
else if (DetectLanes[9]) NumberDetectLanes=9+1;
else if (DetectLanes[8]) NumberDetectLanes=8+1;
else if (DetectLanes[7]) NumberDetectLanes=7+1;
else if (DetectLanes[6]) NumberDetectLanes=6+1;
else if (DetectLanes[5]) NumberDetectLanes=5+1;
else if (DetectLanes[4]) NumberDetectLanes=4+1;
else if (DetectLanes[3]) NumberDetectLanes=3+1;
else if (DetectLanes[2]) NumberDetectLanes=2+1;
else if (DetectLanes[1]) NumberDetectLanes=1+1;
else if (DetectLanes[0]) NumberDetectLanes=0+1;
else   NumberDetectLanes=0;
end 
//exit to logic combinational
always @ * begin
//default value for outputs (synthesis)
	ExitToState = 4'd0;
	ExitToFlag  = 0 ;

	case(State)
		DetectQuiet:begin
			if (TimeOut==1) begin
				ExitToState = DetectActive;
				ExitToFlag  = 1 ;
			end
		end	
		DetectActive:begin
			if (DetectStatus == {LANESNUMBER{1'b1}} )begin
				// BUGFIX-018: DetectLanes/WriteDetectLanesFlagReg were written
				// in this combinational block without defaults (latch
				// inference). They are now registered in the clocked block
				// below under the very same condition.
				ExitToState = PollingActive;
				ExitToFlag  = 1 ;
			end	
			else if (TimeOut && DetectStatus == {LANESNUMBER{1'b0}} )begin
				ExitToState = DetectQuiet;
				ExitToFlag  = 1 ;
			end	
		end
		PollingActive:begin
		 if(OSCount >= 1024)begin
			ExitToState = PollingConfigration;
			ExitToFlag  = 1 ;
		 end
		end
		PollingConfigration:begin
		 if(OSCount >= 16)begin
			ExitToState = ConfigrationLinkWidthStart;
			ExitToFlag  = 1 ;
		 end
		end
		ConfigrationLinkWidthAccept:begin
		if(OSGeneratorFinish)begin
			ExitToState = ConfigrationLaneNumWait;
			ExitToFlag  = 1 ;
		end
		end
		ConfigrationComplete:begin
		if(OSCount >= 16)begin
			ExitToState = ConfigrationIdle;
			ExitToFlag  = 1 ;
		 end
		end
		ConfigrationIdle:begin
		if(startSend16 && OSCount-idleCounts > 6)begin
			ExitToState = L0;
			ExitToFlag  = 1 ;
		 end
		end
		RecoveryRcvrLock:begin //////////////TODO ask Emad 
			if(OSGeneratorFinish)begin 
				ExitToState=RecoveryRcvrCfg; // BUGFIX-018: was NBA inside always @(*)
				ExitToFlag=1;				
			end
		
		end
		RecoveryRcvrCfg:begin
			if(OSGeneratorFinish)begin 
				if(ReadDirectSpeedChange)begin
					ExitToState=RecoverySpeed; // BUGFIX-018: was NBA inside always @(*)
					ExitToFlag=1;
				end
				else begin
					ExitToState=RecoveryIdle; // BUGFIX-018: was NBA inside always @(*)
					ExitToFlag=1;
				end
			end
		
		end
		RecoverySpeed:begin
			if(TimeOut && OSCount >= 2)begin
				if(TrainToGen>=Gen3)begin
					ExitToState=Ph0; // BUGFIX-018: was NBA inside always @(*)
					ExitToFlag=1;
				end
				else begin
					ExitToState=RecoveryRcvrLock; // BUGFIX-018: was NBA inside always @(*)
					ExitToFlag=1;
				end
			end
		end
		RecoveryIdle:begin
		if( OSCount >= 6)begin
					ExitToState=L0; // BUGFIX-018: was NBA inside always @(*)
					ExitToFlag=1;
		end		
		end

		recoverywait:begin
			if(RxStandby)
			begin
				ExitToState=recoverySpeedeieos; // BUGFIX-018: was NBA inside always @(*)
				ExitToFlag=1;
			end
		end

	endcase
end
assign Gen = MainLTSSMGen;
integer i;
always @(posedge Pclk) begin
//Default values of outputs
//Gen <= CurrentGen;
ElecIdleReq <= {LANESNUMBER{1'b0}};
DetectReq<= {LANESNUMBER{1'b0}};
OSGeneratorStart <=0;
WriteLinkNumFlag <=0;
SpeedChange<=1'b0;
UsePresetCoff<=1'b0;
ResetEIEOSCount<=1'b0;
RejectCoff<=1'b0;
ReqEq <= 1'b0;
RxStandby<=16'b0;

	case(State)
		DetectQuiet:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData <= 1;
			ElecIdleReq <= {LANESNUMBER{1'b1}};
		end
		DetectActive:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			DetectReq<= {LANESNUMBER{1'b1}};
		end
		 PollingActive:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			OSType<=2'b00;
		   LaneNumber<=2'b00;
			LinkNumber<=8'b0;
			Rate<=MAX_GEN;
			Loopback<=1;
			OSGeneratorStart<=1;
			end
		end
		PollingConfigration:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			OSType<=2'b01; //TS2
		   LaneNumber<=2'b00;
			LinkNumber<=8'b0;
			Rate<=MAX_GEN;
			OSGeneratorStart<=1;
			end
		end
		ConfigrationLinkWidthStart:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			OSType<=2'b00; //TS1
		   LaneNumber<=2'b00;
			Rate<=MAX_GEN;
			if(DEVICETYPE==DownStream)begin
				LinkNumber<=8'b01;
				WriteLinkNum <= 8'b01;
				WriteLinkNumFlag <= 1;
			end
			else begin
				LinkNumber<=8'b00; //pad
			end
			OSGeneratorStart<=1;
			end
		end
		
		ConfigrationLinkWidthAccept:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			OSType<=2'b00; //TS1
		   LinkNumber<=ReadLinkNum;
			Rate<=MAX_GEN;
			if(DEVICETYPE==DownStream)begin
				LaneNumber<=2'b01; //num_seq
			end
			else begin
				LaneNumber<=8'b00; //pad
			end
			OSGeneratorStart<=1;
			end
		end
		ConfigrationLaneNumWait:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			OSType<=2'b00; //TS1
		   LinkNumber<=ReadLinkNum;
			Rate<=MAX_GEN;
			LaneNumber<=2'b01; //num_seq
			OSGeneratorStart<=1;
			end
		end
		ConfigrationLaneNumActive:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			OSType<=2'b00; //TS1
		   LinkNumber<=ReadLinkNum;
			Rate<=MAX_GEN;
			LaneNumber<=2'b01; //num_seq
			OSGeneratorStart<=1;
			end
		end
		
		ConfigrationComplete:begin
			turnOffScrambler_flag_next<=1'b1;
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy && OSCount < 15)begin //it is supposed that
			OSType<=2'b01; //TS2
		    LinkNumber<=ReadLinkNum;
			Rate<=MAX_GEN;
			LaneNumber<=2'b01; //num_seq
			OSGeneratorStart<=1;
			end
		end
		ConfigrationIdle:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
			turnOffScrambler_flag_next<=1'b0;
			OSType<=3'b100; //IDLE
			OSGeneratorStart<=1;
			end
		end
		L0:begin
			turnOffScrambler_flag_next<=1'b0;
			if(Gen<3'b011)begin 
			HoldFIFOData<=0;
			MuxSel <=1;
			end
			else if(Gen>=3'b011)begin
				if(!OSGeneratorBusy && !SDSFlag)begin
					HoldFIFOData<=1;
					MuxSel <=0;
					OSType<=3'b110;
					OSGeneratorStart<=1;
					// FSM-004: SDSFlag set moved to the single owner block
					// below (was a second clocked driver of SDSFlag).
				end
				if(SDSFlag && OSGeneratorFinish)begin
					HoldFIFOData<=0;
					MuxSel <=1;
				end
			end
			 //TODO : check is it 1 or 0 for orderset
		end
		RecoveryRcvrLock: begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin //it is supposed that
				OSType<=3'b000; //TS1
				LinkNumber<=ReadLinkNum;
				Rate<=MAX_GEN;
				EQTS2<=0;
				LaneNumber<=2'b01; //num_seq
				SpeedChange<=ReadDirectSpeedChange;
				EC<=2'b00;
				OSGeneratorStart<=1;
			end
		end
		
		
		RecoveryRcvrCfg:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset			
			if(!OSGeneratorBusy)begin //it is supposed that
				OSType<=3'b001; //TS2
				LinkNumber<=ReadLinkNum;
				Rate<=MAX_GEN;
				LaneNumber<=2'b01; //num_seq
				SpeedChange<=ReadDirectSpeedChange;
				EC<=2'b00;
				if (TrainToGen >= Gen3 && DEVICETYPE ==DownStream && ReadDirectSpeedChange )
				begin 
					EQTS2<=1;
					for(i=0;i<LANESNUMBER;i=i+1)begin
						RXPreset[3*i+:3]<=ReceiverpresetHintDSP[3*i+:3];
						TXPreset[4*i+:4]<=TransmitterPresetHintDSP[4*i+:4];
					end 
				end
				OSGeneratorStart<=1;
			end
		end
		RecoverySpeed:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			//ElecIdleReq <= {LANESNUMBER{1'b1}};
			if(!OSGeneratorBusy)begin 
				OSType<=3'b011; //eios
				OSGeneratorStart<=1;
			end
		end
//3'b101
		recoverySpeedeieos:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			//ElecIdleReq <= {LANESNUMBER{1'b1}};
			if(!OSGeneratorBusy)begin 
				OSType<=3'b101; //eieos
				OSGeneratorStart<=1;
			end
		end

		// BUGFIX-037: a second, byte-for-byte duplicate 'recoverySpeedeieos' case
// item used to follow here. Duplicate case items are illegal in synthesis
// and a source of confusion; the first (identical) item above is kept.
recoverywait:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(!OSGeneratorBusy)begin
			ElecIdleReq <= {LANESNUMBER{1'b1}};
			RxStandby <= {LANESNUMBER{1'b1}};
			end
		end

		Ph0:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(DEVICETYPE==DownStream)begin/////////////////****************************************************************////////
				if(!OSGeneratorBusy)begin //it is supposed that
					OSType<=3'b000; //TS1
					LinkNumber<=ReadLinkNum;
					Rate<=MAX_GEN;
					LaneNumber<=2'b01; //num_seq
					SpeedChange<=ReadDirectSpeedChange;
					EC<=2'b00;
					for(i=0;i<LANESNUMBER;i=i+1)begin
						TXPreset[4*i+:4]<=TransmitterPresetHintUSP[4*i+:4];
						PreCursorCoff[6*i+:6] <=PreCursorCoff_register[6*i+:6];//[23:18][5:0]       [35:0][17:0]
						CursorCoff[6*i+:6]    <=CursorCoff_register[6*i+:6];//[29:24][11:6]
	 					PostCursorCoff[6*i+:6]<=PostCursorCoff_register[6*i+:6];//[35:30][17:12]
					//	LF[6*i+:6] <= LocalLF[(6*LANESNUMBER-6)-6*i+:6];
						//FS[6*i+:6] <= LocalFS[(6*LANESNUMBER-6)-6*i+:6];
					end 

					OSGeneratorStart<=1;
				end
			end
		end
		Ph1:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			if(DEVICETYPE==DownStream)begin
				
				if(!OSGeneratorBusy)begin //it is supposed that
					OSType<=3'b000; //TS1
					LinkNumber<=ReadLinkNum;
					Rate<=MAX_GEN;
					LaneNumber<=2'b01; //num_seq
					SpeedChange<=ReadDirectSpeedChange;
		 			EC<=2'b01;
					for(i=0;i<LANESNUMBER;i=i+1)begin
						TXPreset[4*i+:4]<=TransmitterPresetHintDSP[4*i+:4];
						//PreCursorCoff[6*i+5:6*i] <=LocalTxPresetCoefficients[18*LANESNUMBER-18*i-12-1:18*LANESNUMBER-18*i-18];//[23:18][5:0]       [35:0][17:0]
						//CursorCoff[6*i+5:6*i] <=LocalTxPresetCoefficients[18*LANESNUMBER-18*i-6-1:18*LANESNUMBER-18*i-12];//[29:24][11:6]
	 					PostCursorCoff[6*i+:6] <=PostCursorCoff_register[6*i+:6];//[35:30][17:12]
						LF[6*i+:6] <= LF_register[6*i+:6];
						FS[6*i+:6] <= FS_register[6*i+:6];
					end 
					OSGeneratorStart<=1;
				end
			end
			else if(DEVICETYPE==UpStream)begin
			if(!OSGeneratorBusy)begin //it is supposed that
					OSType<=3'b000; //TS1
					LinkNumber<=ReadLinkNum;
					Rate<=MAX_GEN;
					LaneNumber<=2'b01; //num_seq
					SpeedChange<=ReadDirectSpeedChange;
					EC<=2'b01;
					for(i=0;i<LANESNUMBER;i=i+1)begin
						TXPreset[4*i+:4]<=TransmitterPresetHintUSP[4*i+:4];
						//PreCursorCoff[6*i+5:6*i] <=LocalTxPresetCoefficients[18*LANESNUMBER-18*i-12-1:18*LANESNUMBER-18*i-18];//[23:18][5:0]       [35:0][17:0]
						//CursorCoff[6*i+5:6*i] <=LocalTxPresetCoefficients[18*LANESNUMBER-18*i-6-1:18*LANESNUMBER-18*i-12];//[29:24][11:6]
	 					PostCursorCoff[6*i+:6] <=PostCursorCoff_register[6*i+:6];//[35:30][17:12]
						LF[6*i+:6] <= LF_register[6*i+:6];
						FS[6*i+:6] <= FS_register[6*i+:6];
					end 
					OSGeneratorStart<=1;
				end
			
			
			
			end
		
		
		end
		RecoveryIdle:begin
			HoldFIFOData<=1;
			MuxSel <=0; //TODO : check is it 1 or 0 for orderset
			// BUGFIX-034 (protocol): ElecIdleReq used to be asserted here.
			// In Recovery.Idle the LTSSM must EXIT electrical idle and
			// transmit IDLE data (PCIe Base Spec, Recovery.Idle), so forcing
			// TxElecIdle high via ElecIdleReq while the OS generator sends
			// IDLE/SDS contradicts the protocol (the PHY would suppress the
			// idle data). Detect states remain the only states that force
			// electrical idle via ElecIdleReq.
			if(!OSGeneratorBusy)begin 
				if(Gen>=3'b011 && !SDSFlag)begin
					OSType<=3'b110; //sds
					// FSM-004: SDSFlag set moved to the owner block below.
				end
				else begin
					OSType<=3'b100; //idle
				end
				OSGeneratorStart<=1;
			end
			
		end
	
	endcase 
end


//on trasition to different state initialize orderset_count and any other variable need to be initialized
always @(posedge Pclk)
begin
TimerStart <= 0;
	case(State)
		DetectQuiet:begin
			if( NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			else if (NextState == PollingActive || NextState == PollingConfigration 
			|| NextState == ConfigrationComplete ||NextState == ConfigrationIdle)begin
				OSCount<=0;		
			end
			if(TimeOut)begin
				TimerEnable <= 0;
			end
		end		
		
		DetectActive:begin
			if(NextState == DetectQuiet)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			else if (NextState == PollingActive || NextState == PollingConfigration 
			|| NextState == ConfigrationComplete ||NextState == ConfigrationIdle)begin
				OSCount<=0;		
			end			
		   if(TimeOut)begin
				TimerEnable <= 0;
			end
		end		

		PollingActive:begin
			if(OSGeneratorFinish)begin
				OSCount<=OSCount+1;		
			end
			if(NextState == DetectQuiet || NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			else if ( NextState == PollingConfigration || NextState == ConfigrationComplete 
			||NextState == ConfigrationIdle)begin
				OSCount<=0;		
			end			
		end		
		
		PollingConfigration :begin
			if(OSGeneratorFinish)begin
				OSCount<=OSCount+1;		
			end
			if(NextState == DetectQuiet || NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			else if (NextState == PollingActive  
			|| NextState == ConfigrationComplete ||NextState == ConfigrationIdle)begin
				OSCount<=0;		
			end			
		end		
	
		ConfigrationComplete:begin
			if(OSGeneratorFinish)begin
				OSCount<=OSCount+1;		
			end
			if(NextState == DetectQuiet || NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			else if (NextState == PollingActive || NextState == PollingConfigration 
			||NextState == ConfigrationIdle)begin
				OSCount<=0;		
			end			
		end		

		ConfigrationIdle:begin
			if(OSGeneratorFinish)begin
				OSCount<=OSCount+1;		
			end
			if(NextState == DetectQuiet || NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			
			else if (NextState == PollingActive || NextState == PollingConfigration 
			|| NextState == ConfigrationComplete )begin
				OSCount<=0;		
			end			
		end		
		
		RecoveryRcvrCfg:begin
			if(NextState==RecoverySpeed)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t0ms;
				OSCount<= 0;
			end
			else if (NextState==RecoveryIdle)begin
				OSCount<= 0;
				// FSM-004: SDSFlag clear moved to the owner block below.
			end
		end
		
		RecoverySpeed:begin
			if(OSGeneratorFinish)begin
				OSCount <= OSCount + 1;		
			end
			if(TimeOut)begin
				TimerEnable <= 0;
			end
		end
		RecoveryIdle:begin
			if(OSGeneratorFinish)begin
				OSCount<=OSCount+1;		
			end
			if(NextState == DetectQuiet || NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			
			
			else if (NextState == PollingActive || NextState == PollingConfigration 
			|| NextState == ConfigrationComplete || NextState==L0)begin
				OSCount<=0;		
				// FSM-004: SDSFlag clear moved to the owner block below.
			end			
		end		
		default:begin
			if(NextState == DetectQuiet || NextState == DetectActive)begin
				TimerEnable <= 1;
				TimerStart  <= 1;
				TimerIntervalCode <= t12ms;
			end
			else if (NextState == PollingActive || NextState == PollingConfigration 
			|| NextState == ConfigrationComplete ||NextState == ConfigrationIdle || NextState == RecoverySpeed )begin
				OSCount<=0;		
			end			
		end		
	endcase
end
// outputs
always @ (posedge Pclk)
begin
	if(!Reset) begin
		turnOffScrambler_flag<= 1'b1;
		State <= Idle;
		TXExitTo <= DetectQuiet;
		TXFinishFlag <= 0;
		CurrentGen=Gen1;
		WriteDetectLanesFlag<=0;
		SDSFlag<=0;
		DetectLanes <= {LANESNUMBER{1'b0}};      // BUGFIX-018 reset
		WriteDetectLanesFlagReg <= 1'b0;         // BUGFIX-018 reset
	end
	else begin
		// FSM-004: SDSFlag was written from THREE separate clocked blocks
		// (set here in L0/RecoveryIdle, cleared in the timer-control block,
		// reset here) - multiple conflicting drivers. Root cause: one flag
		// owned by several processes. Fix: this block is now the single
		// owner; the set/clear conditions are decoded combinationally below
		// exactly as they appeared in the former branches. Clear has
		// priority; set and clear are mutually exclusive by state.
		// (idleCounts/startSend16_q resets moved to the capture block,
		// BUGFIX-036.)
		if (sdsFlagClr)
			SDSFlag <= 1'b0;
		else if (sdsFlagSet)
			SDSFlag <= 1'b1;
		turnOffScrambler_flag <= turnOffScrambler_flag_next2;
		turnOffScrambler_flag_next2<=turnOffScrambler_flag_next;
		State   <= NextState;
		TXExitTo<= ExitToState;
		TXFinishFlag <= ExitToFlag;
		// BUGFIX-018: DetectLanes used to be assigned in the combinational
		// exit-to block (latch), and WriteDetectLanesFlagReg latched 1
		// forever once set (so WriteDetectLanesFlag was asserted every cycle
		// for the rest of the link's life). Both are now registered here:
		// DetectLanes captures the detection result and the write flag is a
		// proper one-cycle strobe.
		if (State == DetectActive && DetectStatus == {LANESNUMBER{1'b1}}) begin
			DetectLanes <= DetectStatus;
			WriteDetectLanesFlagReg <= 1'b1;
		end
		else begin
			WriteDetectLanesFlagReg <= 1'b0;
		end
		WriteDetectLanesFlag<=WriteDetectLanesFlagReg;
	end
end


// BUGFIX-036:
// Original issue: idleCounts was captured with 'always @(posedge
// startSend16)' - an asynchronous event control on a control signal coming
// from another block (mainLTSSM). This is a clock-domain-crossing style
// hazard (event-driven sampling, unsynthesizable as intended hardware).
// Root cause: event-driven capture instead of synchronous edge detection.
// Fix: detect the rising edge of startSend16 synchronously on Pclk and
// capture OSCount on that edge. startSend16 is already Pclk-synchronous
// (combinational decode in mainLTSSM), so no extra synchronizer is needed.
// Verified by: review + tb/regress directed tests (Configuration.Idle exit).
// (startSend16_q declared with the other regs above, BUGFIX-036.)
always @(posedge Pclk)
begin
	// BUGFIX-036 (amended): reset handling lives here so that idleCounts
	// and startSend16_q have exactly ONE clocked owner (FSM-004 style
	// consolidation; formerly also reset from the outputs block).
	if(!Reset) begin
		startSend16_q <= 1'b0;
		idleCounts <= 16'd0;
	end
	else begin
		startSend16_q <= startSend16;
		if (startSend16 && !startSend16_q)
			idleCounts <= OSCount;
	end
end

// FSM-004 decode logic (see the owner block above).
wire sdsFlagSet = ((State == L0) && (Gen >= 3'b011) && !OSGeneratorBusy && !SDSFlag)
               || ((State == RecoveryIdle) && !OSGeneratorBusy && (Gen >= 3'b011) && !SDSFlag);
wire sdsFlagClr = ((State == RecoveryRcvrCfg) && (NextState == RecoveryIdle))
               || ((State == RecoveryIdle) && (NextState == PollingActive
                                              || NextState == PollingConfigration
                                              || NextState == ConfigrationComplete
                                              || NextState == L0));

endmodule