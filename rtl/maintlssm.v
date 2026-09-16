module mainLTSSM  #(
parameter MAX_GEN = 5,
parameter DEVICETYPE=0,
parameter Width = 32,
parameter GEN1_PIPEWIDTH = 8 ,	
parameter GEN2_PIPEWIDTH = 8 ,	
parameter GEN3_PIPEWIDTH = 8 ,	
parameter GEN4_PIPEWIDTH = 8 ,	
parameter GEN5_PIPEWIDTH = 8 ,
parameter LANESNUMBER = 16)
(
    input clk,
    input reset,
    input [3:0] lpifStateRequest,
    input [4:0] numberOfDetectedLanesIn,
    input [7:0] linkNumberInTx,
    input [7:0] linkNumberInRx,
    input [7:0] rateIdIn,
    input upConfigureCapabilityIn,
    input writeNumberOfDetectedLanes,
    input writeLinkNumberTx,
    input writeLinkNumberRx,
    input writeUpconfigureCapability,
    input writeRateId,
    input finishTx,
    input finishRx,
    input [4:0] gotoTx,
    input [4:0] gotoRx,
    input forceDetect,
    /***************eq****************/
    input [47:0] ReceiverpresetHintDSPIn,
    input [63:0] TransmitterPresetHintDSPIn,
    input [47:0] ReceiverpresetHintUSPIn,
    input [63:0] TransmitterPresetHintUSPIn,
    input writeReceiverpresetHintDSP,
    input writeTransmitterPresetHintDSP,
    input writeReceiverpresetHintUSP,
    input writeTransmitterPresetHintUSP,
    input directed_speed_change_In,
    input write_directed_speed_change,
    input [18*16 -1:0]LocalTxPresetCoefficients,
    input [6*16 -1:0]LocalFS,
    input [6*16 -1:0]LocalLF,
    input [16 -1:0]LocalTxCoefficientsValid,
    input [6*16 -1:0]LinkEvaluationFeedbackDirectionChange,
    input [16*6-1:0]FSDSP,
    input [16*6-1:0]LFDSP,
    input turnOffScrambler_flag,
    output	reg[18*16 -1:0]TxDeemph,
    output  reg[4*16 -1:0]LocalPresetIndex,
    output 	reg[16 -1:0]GetLocalPresetCoeffcients,
    output 	reg[6*16 -1:0]LF,
    output 	reg[6*16 -1:0]FS,
    output 	reg[16 -1:0]RxEqEval,
    output 	reg[16 -1:0]InvalidRequest,

    output  reg directed_speed_change,
    output  reg[47:0] ReceiverpresetHintDSP,
    output  reg[63:0] TransmitterPresetHintDSP,
    output  reg[47:0] ReceiverpresetHintUSP,
    output  reg[63:0] TransmitterPresetHintUSP,
    output  reg[6*16-1:0]LF_register,
    output  reg[6*16-1:0]FS_register,
    output  reg[6*16-1:0]CursorCoff,
    output  reg[6*16-1:0]PreCursorCoff,
    output  reg[6*16-1:0]PostCursorCoff, 
    /***************eq****************/
    output reg linkUp,
    output reg[2:0] GEN,
    output [4:0] numberOfDetectedLanesOut,
    output [7:0] linkNumberOutTx,
    output [7:0] linkNumberOutRx,
    output [7:0] rateIdOut,
    output upConfigureCapabilityOut,
    output reg[3:0] lpifStateStatus,
    output reg[4:0] substateTx,
    output reg[4:0] substateRx,
    output reg[1:0] width,
    output reg[2:0] trainToGen,
    output reg disableScrambler,
    output reg [4:0] PCLKRate,
    output reg startSend16);
//local signals
    reg [4:0] numberOfDetectedLanes;
    reg [7:0] linkNumber;
    reg [7:0] rateId;
    reg upConfigureCapability;
    reg [3:0]currentState,nextState;
    reg [4:0] substateTxnext,substateRxnext;
    integer i;
    // BUGFIX-017b/010/011: helper signals for the latch-free, single-driver
    // re-implementation of the output handling block (see comments there):
    //   dscSet/dscClr      -> registered set/clear of directed_speed_change
    //   trainSpeedSet      -> register trainToGen on a directed speed change
    //   genWrite           -> register GEN update (speed change commit)
    //   eqPhase0/eqPhase1  -> register equalization outputs (were latches)
    reg dscSet, dscClr, trainSpeedSet, genWrite;
    reg [2:0] trainToGenNext;
    reg eqPhase0, eqPhase1;              // write enables for eq. registers
    reg [18*16 -1:0] TxDeemph_c;
    reg [4*16 -1:0]  LocalPresetIndex_c;
    reg [6*16-1:0]   LF_register_c, FS_register_c, CursorCoff_c, PreCursorCoff_c, PostCursorCoff_c;
    reg [6*16-1:0]   LF_c, FS_c;
    
//Local parameters
    //LPIF STATES
    localparam[3:0]
        reset_   = 4'd0,
        active_  = 4'd1,
        retrain_ = 4'd11;

    //Tx/Rx LTSSM states
    localparam [4:0]
	    detectQuiet =  5'd0,
        detectActive = 5'd1,
        pollingActive= 5'd2,
        pollingConfiguration= 5'd3,
        configurationLinkWidthStart = 5'd4,
        configurationLinkWidthAccept = 5'd5,
        configurationLanenumWait = 5'd6,
        configurationLanenumAccept = 5'd7,
        configurationComplete = 5'd8,
        configurationIdle = 5'd9,
        L0 = 5'd10,
        recoveryRcvrLock = 5'd11,
        recoveryRcvrCfg = 5'd12,
        recoverySpeed = 5'd13,
        phase0 = 5'd14,
        phase1 = 5'd15,
        phase2 = 5'd16,
        phase3 =5'd17,
        recoveryIdle = 5'd18,
        recoverySpeedeieos = 5'd19,
        recoverywait = 5'd20;


    always @(posedge clk) 
    begin
        if(turnOffScrambler_flag)disableScrambler<=1'b1;
        else disableScrambler<=1'b0;      
    end

    // FSM-001: 'forceDetect' was part of the ASYNC reset condition
    // ('if(!reset || forceDetect)') while not being in the sensitivity
    // list, which yosys rejects ("Multiple edge sensitive events") and
    // which would synthesize as an asynchronous reset driven by ordinary
    // control logic (a false async path). Root cause: async-reset
    // expression referencing a non-edge signal. Fix: forceDetect is now a
    // SYNCHRONOUS reset applied in the cycle after it is asserted, using
    // exactly the same initialization values as the async reset path.
    // Verified by: yosys proc (process converts cleanly), slang.
    wire initCond = (!reset) || forceDetect;
    always @(posedge clk or negedge reset)
    begin
        if(!reset)
        begin
            currentState <= reset_;
            ReceiverpresetHintDSP<=48'hAABBCCDD1122;
            TransmitterPresetHintDSP<=64'h11AA22BB33CC44DD;
            ReceiverpresetHintUSP<=48'h2211DDCCBBAA;
            TransmitterPresetHintUSP<=64'h11AA22BB33CC44DD;
            GEN <= 3'd1;
            // BUGFIX-011/017b: give the formerly latch-inferred outputs a
            // defined reset value (they were X until first written).
            directed_speed_change <= 1'b0;
            trainToGen <= 3'd0;
            GetLocalPresetCoeffcients <= {16{1'b0}};
            LocalPresetIndex <= {4*16{1'b0}};
            TxDeemph <= {18*16{1'b0}};
            LF_register <= {6*16{1'b0}};
            FS_register <= {6*16{1'b0}};
            CursorCoff <= {6*16{1'b0}};
            PreCursorCoff <= {6*16{1'b0}};
            PostCursorCoff <= {6*16{1'b0}};
            LF <= {6*16{1'b0}};
            FS <= {6*16{1'b0}};
        end
        else if(forceDetect)
        begin
            // FSM-001: synchronous re-initialization (same values as reset)
            currentState <= reset_;
            ReceiverpresetHintDSP<=48'hAABBCCDD1122;
            TransmitterPresetHintDSP<=64'h11AA22BB33CC44DD;
            ReceiverpresetHintUSP<=48'h2211DDCCBBAA;
            TransmitterPresetHintUSP<=64'h11AA22BB33CC44DD;
            GEN <= 3'd1;
            directed_speed_change <= 1'b0;
            trainToGen <= 3'd0;
            GetLocalPresetCoeffcients <= {16{1'b0}};
            LocalPresetIndex <= {4*16{1'b0}};
            TxDeemph <= {18*16{1'b0}};
            LF_register <= {6*16{1'b0}};
            FS_register <= {6*16{1'b0}};
            CursorCoff <= {6*16{1'b0}};
            PreCursorCoff <= {6*16{1'b0}};
            PostCursorCoff <= {6*16{1'b0}};
            LF <= {6*16{1'b0}};
            FS <= {6*16{1'b0}};
        end
        else
        begin
            currentState <= nextState;
            substateTx <= substateTxnext;
            substateRx <= substateRxnext;
            if(writeNumberOfDetectedLanes)numberOfDetectedLanes<=numberOfDetectedLanesIn;
            if(writeLinkNumberTx)linkNumber<=linkNumberInTx;
            else if(writeLinkNumberRx)linkNumber<=linkNumberInRx;
            if(writeUpconfigureCapability)upConfigureCapability<=upConfigureCapabilityIn;
            if(writeReceiverpresetHintDSP)ReceiverpresetHintDSP <=ReceiverpresetHintDSPIn;
            if(writeReceiverpresetHintUSP)ReceiverpresetHintUSP <=ReceiverpresetHintUSPIn;
            if(writeTransmitterPresetHintUSP) TransmitterPresetHintUSP<=TransmitterPresetHintUSPIn;
            if(writeTransmitterPresetHintDSP)TransmitterPresetHintDSP <=TransmitterPresetHintDSPIn;
            if(write_directed_speed_change) directed_speed_change <= directed_speed_change_In;
            if(writeRateId)rateId <= rateIdIn;
            // BUGFIX-011/017b/017c/017d: registered updates replacing the
            // latch-inferred / multiply-driven combinational outputs.
            // The FSM set/clear flags take precedence over the LPIF-directed
            // write (both are never asserted together by construction).
            if(dscSet)            directed_speed_change <= 1'b1;
            else if(dscClr)       directed_speed_change <= 1'b0;
            if(trainSpeedSet)     trainToGen <= trainToGenNext;
            if(genWrite)          GEN <= trainToGen;
            if(eqPhase0) begin
                GetLocalPresetCoeffcients <= {16{1'b1}};
                LocalPresetIndex <= LocalPresetIndex_c;
                if(LocalTxCoefficientsValid=={16{1'b1}}) begin
                    TxDeemph <= TxDeemph_c;
                    LF_register <= LF_register_c;
                    FS_register <= FS_register_c;
                    CursorCoff <= CursorCoff_c;
                    PreCursorCoff <= PreCursorCoff_c;
                    PostCursorCoff <= PostCursorCoff_c;
                end
            end
            if(eqPhase1) begin
                LF <= LF_c;
                FS <= FS_c;
            end
        end    
    end

//next LPIF state handling
    // BUGFIX-017a:
    // Original issue: this combinational block used non-blocking assignments
    // (nextState <= ...) and had no default for branches whose conditions
    // were false, so nextState was inferred as a latch in simulation and is
    // a combinational-default/lint error for synthesis.
    // Root cause: NBA inside always @(*), missing defaults.
    // Fix: blocking assignments + explicit hold default (nextState =
    // currentState), which reproduces the previous latch-hold behavior
    // without inferring storage.
    // Verified by: yosys proc/check (no latch), slang elaboration.
    always @(*)
    begin
       nextState = currentState; // default: hold (was an inferred latch)
       case (currentState)
        reset_:
        begin
            if(finishTx&&gotoTx==L0&&finishRx&&gotoRx==L0&&lpifStateRequest==active_)
            begin
                nextState = active_;
            end
        end
        active_:
        begin
            if(lpifStateRequest==reset_)
            begin
               nextState = reset_; 
            end
            else if(lpifStateRequest==retrain_ || trainToGen >= 3'd2)
            begin
               nextState = retrain_; 
            end
        end
        retrain_:
        begin
            if(finishTx&&gotoTx==L0&&finishRx&&gotoRx==L0)
            begin
               nextState = active_; 
            end
        end 
        default:
            nextState = reset_; 
       endcase 
        
    end

//check on gneration and adjust width reg 0 for 8bit 1 for 16bit 2 for 32bit
always @ (posedge clk)
begin 
	if(!reset) begin width <= 0; end
	else begin
		if (GEN == 1)begin  
			case(GEN1_PIPEWIDTH)
			8:width<=0;
			16:width<=1;
			32:width<=2;
			endcase
		end
		else if (GEN == 2)begin  
			case(GEN2_PIPEWIDTH)
			8:width<=0;
			16:width<=1;
			32:width<=2;
			endcase
		end
		else if (GEN == 3)begin  
			case(GEN3_PIPEWIDTH)
			8:width<=0;
			16:width<=1;
			32:width<=2;
			endcase
		end
		else if (GEN == 4)begin  
			case(GEN4_PIPEWIDTH)
			8:width<=0;
			16:width<=1;
			32:width<=2;
			endcase
		end
		else if (GEN == 5)begin  
			case(GEN5_PIPEWIDTH)
			8:width<=0;
			16:width<=1;
			32:width<=2;
			endcase
		end
		
	end
end

//output handling block
    // BUGFIX-017b:
    // Original issue: this combinational block (a) assigned several outputs
    // (lpifStateStatus, linkUp, startSend16, directed_speed_change,
    // trainToGen, substateTxnext/substateRxnext and all equalization data
    // outputs) only inside selected case branches, inferring latches for the
    // unassigned paths, (b) used non-blocking assignments inside the
    // combinational block, and (c) drove substateTx/substateRx directly with
    // an NBA while the clocked block below also drives them (multiple
    // driver - a synthesis error, see BUGFIX-010), and likewise drove GEN
    // (BUGFIX-011).
    // Root cause: missing combinational defaults + mixing of sequential
    // assignment styles into a combinational process.
    // Fix: explicit hold/safe defaults are assigned at the top of the block
    // (reproducing the previous latch-hold behavior without storage),
    // substate transitions now go through substateTxnext/substateRxnext
    // only, and directed_speed_change/trainToGen/GEN plus the equalization
    // data outputs are updated in the clocked domain via the write-enable
    // flags computed here. No protocol state values were changed.
    // Verified by: yosys proc/check (no latches, no multi-driver), slang
    // elaboration, directed regression tb/regress/tb_ltssm_pipe_control.v.
    always @(*)
    begin
        // ---- defaults (latch removal; hold semantics unless noted) ----
        {substateTxnext,substateRxnext} = {substateTx,substateRx}; // hold
        lpifStateStatus = currentState;   // status mirrors current LPIF state
        linkUp = 1'b0;                    // cleared unless a branch sets it
        startSend16 = 1'b0;               // one-shot pulse (was latch NBA)
        dscSet = 1'b0; dscClr = 1'b0;     // directed_speed_change set/clear
        trainSpeedSet = 1'b0; trainToGenNext = trainToGen;
        genWrite = 1'b0;                  // GEN commit (speed change)
        eqPhase0 = 1'b0; eqPhase1 = 1'b0; // equalization register enables
        TxDeemph_c = {18*16{1'b0}};
        LocalPresetIndex_c = {4*16{1'b0}};
        LF_register_c = {6*16{1'b0}}; FS_register_c = {6*16{1'b0}};
        CursorCoff_c = {6*16{1'b0}}; PreCursorCoff_c = {6*16{1'b0}};
        PostCursorCoff_c = {6*16{1'b0}};
        LF_c = {6*16{1'b0}}; FS_c = {6*16{1'b0}};
        // FSM-002: 'nextState' is driven ONLY by the LPIF next-state block
        // above (BUGFIX-017a). Original code ALSO assigned it from this
        // block's 'default:' case item, creating two combinational drivers
        // of the same reg (multiple-driver error in synthesis; in
        // simulation the result was a race between the blocks). Root
        // cause: split ownership of the FSM next-state register. Fix:
        // this block no longer drives nextState at all; the LPIF block's
        // own default (nextState = currentState, plus 'default: reset_'
        // for unlisted encodings) keeps the FSM total and latch-free -
        // the stuck-LTSSM hazard noted for GitHub issues #74/#77 is
        // addressed by that default.
        // BUGFIX-040b: loop index 'i' was only assigned inside the phase0
        // branch, latching it for all other evaluations. Fix: default 0.
        // Verified by: yosys proc/check (no $dlatch, no multi-driver).
        i = 0;
        //disableScrambler = 1'b1;
       case (currentState)
        reset_:
        begin
            case ({substateTx,substateRx})
                {detectQuiet,detectQuiet}:
                begin
                   if (/*finishTx&&*/finishRx&&/*gotoTx==detectActive&&*/gotoRx==detectActive) 
                    begin
                        {substateTxnext,substateRxnext} = {detectActive,detectActive};
                        lpifStateStatus = reset_;
                    end 
                end
                
                {detectActive,detectActive}:
                begin
                    if (finishTx&&finishRx&&gotoTx==pollingActive&&gotoRx==pollingActive) 
                        begin
                            {substateTxnext,substateRxnext} = {pollingActive,pollingActive};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                end

                {pollingActive,pollingActive}:
                begin
                    if ((finishRx&&gotoRx==pollingConfiguration) ||(gotoTx==pollingConfiguration&&finishTx)) 
                        begin
                            {substateTxnext,substateRxnext}= {pollingConfiguration,pollingConfiguration};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                end
                {pollingConfiguration,pollingConfiguration}:
                begin
                    if (finishTx&&finishRx&&gotoTx==configurationLinkWidthStart&&gotoRx==configurationLinkWidthStart) 
                        begin
                            {substateTxnext,substateRxnext}= {configurationLinkWidthStart,configurationLinkWidthStart};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                end
                {configurationLinkWidthStart,configurationLinkWidthStart}:
                begin
                    if (finishRx&&gotoRx==configurationLinkWidthAccept) 
                        begin
                            {substateTxnext,substateRxnext}= {configurationLinkWidthAccept,configurationLinkWidthAccept};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                end
                {configurationLinkWidthAccept,configurationLinkWidthAccept}:
                begin
                    if (!DEVICETYPE&&finishTx&&gotoTx==configurationLanenumWait)//in downstream the Rx doesn't make any thing 
                        begin
                            {substateTxnext,substateRxnext}= {configurationLanenumWait,configurationLanenumWait};
                            lpifStateStatus = reset_;
                        end
                    else if (DEVICETYPE&&finishTx&&finishRx&&gotoTx==configurationLanenumWait&&gotoRx==configurationLanenumWait) 
                        begin
                            {substateTxnext,substateRxnext}= {configurationLanenumWait,configurationLanenumWait};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                end
                {configurationLanenumWait,configurationLanenumWait}:
                    if (finishRx&&gotoRx==configurationLanenumAccept) 
                        begin
                            {substateTxnext,substateRxnext}= {configurationLanenumAccept,configurationLanenumAccept};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                {configurationLanenumAccept,configurationLanenumAccept}:
                    if (finishRx&&gotoRx==configurationComplete) 
                        begin
                            {substateTxnext,substateRxnext}= {configurationComplete,configurationComplete};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                {configurationComplete,configurationComplete}:
                    if (finishRx&&gotoRx==configurationIdle&&finishTx&&gotoRx==configurationIdle) 
                        begin
                            {substateTxnext,substateRxnext}= {configurationIdle,configurationIdle};
                            lpifStateStatus = reset_;
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                {configurationIdle,configurationIdle}:
                begin
                    //disableScrambler = 1'b0;
                    if (finishRx&&gotoRx==L0)startSend16= 1'b1;
                    if (finishTx&&gotoTx==L0) 
                        begin
                            linkUp = 1'b1;
                            startSend16 = 1'b0;
                            lpifStateStatus = reset_;
                            // BUGFIX-010: was "{substateTx,substateRx} <= {L0,L0}"
                            // - a non-blocking write from this combinational
                            // block onto registers that the clocked block below
                            // also drives (multiple-driver synthesis error and
                            // an NBA race in simulation). The transition is now
                            // routed through the normal next-state path.
                            {substateTxnext,substateRxnext}= {L0,L0};//ERASE THE COMMENT IF I CAN GOT TO L0 WITHOUT LPIF PERMISSION
                        end
                    else if((finishTx&&gotoTx==detectQuiet)||(finishRx&&gotoRx==detectQuiet))
                        begin
                            {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                            lpifStateStatus = reset_;
                        end
                end
                    

                default:
                    begin
                        {substateTxnext,substateRxnext}= {detectQuiet,detectQuiet};
                        lpifStateStatus = reset_;
                        linkUp = 1'b0;
                        //pl_speedmode = 3'd0;
                    end
            
            endcase
        end
        active_:
        begin
            {substateTxnext,substateRxnext}= {L0,L0};
            lpifStateStatus = active_;
            linkUp = 1'b1;
            if((MAX_GEN==3'd3 && rateId[5:1] == 5'b00111)&&(GEN<3'd3)&&(!DEVICETYPE || (DEVICETYPE && finishRx &&gotoRx== recoveryRcvrLock)))
            begin
                // BUGFIX-017c: directed_speed_change/trainToGen were latch-
                // inferred combinational outputs; they are now registered via
                // these write flags (see clocked block, BUGFIX-011/017b).
                dscSet = 1'b1;
                trainToGenNext = 3'd3; trainSpeedSet = 1'b1;
                {substateTxnext,substateRxnext}= {recoveryRcvrLock,recoveryRcvrLock};
                
            end
            else if((MAX_GEN==3'd2 && rateId[5:1] == 5'b00011)&&(GEN<3'd2)&&(!DEVICETYPE || (DEVICETYPE && finishRx &&gotoRx== recoveryRcvrLock)))
            begin
                // BUGFIX-017c: directed_speed_change/trainToGen were latch-
                // inferred combinational outputs; they are now registered via
                // these write flags (see clocked block, BUGFIX-011/017b).
                dscSet = 1'b1;
                trainToGenNext = 3'd2; trainSpeedSet = 1'b1;
                {substateTxnext,substateRxnext}= {recoveryRcvrLock,recoveryRcvrLock};
            end             

            else if((MAX_GEN==3'd4 && rateId[5:1] == 5'b01111)&&(GEN<3'd4)&&(!DEVICETYPE || (DEVICETYPE && finishRx &&gotoRx== recoveryRcvrLock)))
            begin
                // BUGFIX-017c: directed_speed_change/trainToGen were latch-
                // inferred combinational outputs; they are now registered via
                // these write flags (see clocked block, BUGFIX-011/017b).
                dscSet = 1'b1;
                trainToGenNext = 3'd4; trainSpeedSet = 1'b1;
                {substateTxnext,substateRxnext}= {recoveryRcvrLock,recoveryRcvrLock};
            end   

            else if((MAX_GEN==3'd5 && rateId[5:1] == 5'b11111)&&(GEN<3'd5)&&(!DEVICETYPE || (DEVICETYPE && finishRx &&gotoRx== recoveryRcvrLock)))
            begin
                // BUGFIX-017c: directed_speed_change/trainToGen were latch-
                // inferred combinational outputs; they are now registered via
                // these write flags (see clocked block, BUGFIX-011/017b).
                dscSet = 1'b1;
                trainToGenNext = 3'd5; trainSpeedSet = 1'b1;
                {substateTxnext,substateRxnext}= {recoveryRcvrLock,recoveryRcvrLock};
            end   
                
                       
        end
        retrain_:
        begin
           lpifStateStatus = retrain_;
           linkUp = 1'b1;
           case({substateRx,substateTx})
                {recoveryRcvrLock,recoveryRcvrLock}:
                begin
                    if(finishRx && gotoRx == recoveryRcvrCfg)
                        {substateTxnext,substateRxnext}= {recoveryRcvrCfg,recoveryRcvrCfg};
                end
                {recoveryRcvrCfg,recoveryRcvrCfg}:
                begin
                    if(finishRx && gotoRx == recoverySpeed)
                        {substateTxnext,substateRxnext}= {recoverySpeed,recoverySpeed};

                    else if(finishRx && gotoRx == recoveryIdle)
                        {substateTxnext,substateRxnext}= {recoveryIdle,recoveryIdle};
                end
                {recoverySpeed,recoverySpeed}:
                begin
                    if((finishRx&&gotoRx==recoverywait))
                    begin
                        {substateTxnext,substateRxnext}= {recoverywait,recoverywait};
                        dscClr = 1'b1; // BUGFIX-017c: registered clear (was latch)
                    end                       

                end
                {recoverywait,recoverywait}:
                begin
                    if((finishTx&&gotoTx==recoverySpeedeieos))
                    begin
                        {substateTxnext,substateRxnext}= {recoverySpeedeieos,recoverySpeedeieos};
                        // BUGFIX-011: GEN was driven combinationally here AND
                        // by the async-reset sequential block below (multiple
                        // driver). The update is now registered via genWrite.
                        genWrite = 1'b1;
                        dscClr = 1'b1; // BUGFIX-017c: registered clear (was latch)
                    end                       

                end

                {recoverySpeedeieos,recoverySpeedeieos}:
                begin
                    if(finishRx&&gotoRx==phase0)
                    begin
                        {substateTxnext,substateRxnext}= {phase0,phase0};
                    end
                    else if(finishRx&&gotoRx==recoveryRcvrLock)
                    begin
                        {substateTxnext,substateRxnext}= {recoveryRcvrLock,recoveryRcvrLock};
                    end                       

                end
                {phase0,phase0}:
                begin
                    //disableScrambler = 1'b0;
                    //mapping tx preset to coeff.
                    // BUGFIX-017d: GetLocalPresetCoeffcients/LocalPresetIndex/
                    // coefficient registers were latch-inferred combinational
                    // outputs. eqPhase0 enables their registered update in the
                    // clocked block below; handshaking semantics are preserved
                    // (request asserted for the whole phase0 substate,
                    // coefficients captured while LocalTxCoefficientsValid).
                    eqPhase0 = 1'b1;
                    for(i=0;i<16;i=i+1)
                    begin
                        if(DEVICETYPE)
					        LocalPresetIndex_c[(4*16-4)-i*4+:4]=TransmitterPresetHintUSP[4*i+:4];
                        else
                            LocalPresetIndex_c[(4*16-4)-i*4+:4]=TransmitterPresetHintDSP[4*i+:4];
				    end

                    if(LocalTxCoefficientsValid=={16{1'b1}})
                    begin
                        for(i=0;i<16;i=i+1)
                        begin
                            PreCursorCoff_c[6*i+:6] =LocalTxPresetCoefficients[(18*16-18)-18*i+:6];//[23:18][5:0]       [35:0][17:0]
                            CursorCoff_c[6*i+:6]    =LocalTxPresetCoefficients[(18*16-18)-18*i+6+:6];//[29:24][11:6]
                            PostCursorCoff_c[6*i+:6]=LocalTxPresetCoefficients[(18*16-18)-18*i+12+:6];//[35:30][17:12]
                            LF_register_c[6*i+:6] = LocalLF[(6*LANESNUMBER-6)-6*i+:6];
                            FS_register_c[6*i+:6] = LocalFS[(6*LANESNUMBER-6)-6*i+:6];
					    end
                        TxDeemph_c =  LocalTxPresetCoefficients; //use received coeff.
                    end

                    if(finishRx && gotoRx == phase1)
                         {substateTxnext,substateRxnext}= {phase1,phase1};
                end
                {phase1,phase1}:
                begin
                    //disableScrambler = 1'b0;
                    // BUGFIX-017d: LF/FS were latch-inferred combinational
                    // outputs; eqPhase1 enables their registered update.
                    eqPhase1 = 1'b1;
                    LF_c = LocalLF;
                    FS_c = LocalFS;
                    if(finishRx && gotoRx == phase2)
                         {substateTxnext,substateRxnext}= {recoveryRcvrLock,recoveryRcvrLock};
                end

                {recoveryIdle,recoveryIdle}:
                begin
                    //disableScrambler = 1'b0;
                    if((finishRx && gotoRx == L0) && (finishTx && gotoTx == L0))
                         {substateTxnext,substateRxnext}= {L0,L0};
                end
           endcase

        end 
        // FSM-002: the former 'default: nextState = reset_;' item was the
        // second combinational driver of nextState; it is removed - the
        // LPIF next-state block owns nextState and already maps unlisted
        // currentState encodings to reset_ via its own default.
       endcase 
        
    end

always @ (posedge clk)
begin
    if(~reset) 
    begin 
        PCLKRate <= 0; 
    end
    else begin
    if (GEN == 1)begin
        case(GEN1_PIPEWIDTH)
            8:PCLKRate<=2; //250
            16:PCLKRate<=1; //125
            32:PCLKRate<=0; //62.5
        endcase
    end
    else if (GEN == 2)
    begin
        case(GEN2_PIPEWIDTH)
            8:PCLKRate<=3; //500
            16:PCLKRate<=2; //250
            32:PCLKRate<=1; //125
    endcase
    end
    else if (GEN == 3)begin
        case(GEN3_PIPEWIDTH)
            8:PCLKRate<=4; //1000
            16:PCLKRate<=3; //500
            32:PCLKRate<=2; //250
        endcase
    end
    else if (GEN == 4)begin
        case(GEN4_PIPEWIDTH)
            8:PCLKRate<=5; //2000
            16:PCLKRate<=4; //1000
            32:PCLKRate<=3; //500
        endcase
    end
    else if (GEN == 5)begin
        case(GEN5_PIPEWIDTH)
            8:PCLKRate<=6; //4000
            16:PCLKRate<=5; //2000
            32:PCLKRate<=4; //1000
        endcase
    end
    end
end



    assign{numberOfDetectedLanesOut,linkNumberOutTx,linkNumberOutRx,rateIdOut,upConfigureCapabilityOut} = {numberOfDetectedLanes,linkNumber
    ,linkNumber,rateId,upConfigureCapability};
    

// BUGFIX-044: RxEqEval and InvalidRequest were declared as output regs but
// never assigned anywhere, leaving the two 16-bit PIPE RX-equalization
// handshake outputs floating (X in simulation, undriven nets in synthesis).
// Root cause: ports reserved for RX-directed equalization that the current
// implementation (TX-directed phase0..phase3) never drives. Fix: drive them
// to a defined constant 0 - no RX-directed EQ request, no invalid-request
// indication - which matches the implemented feature set. If RX-directed
// equalization is added later, these drivers must be replaced.
// Verified by: yosys check -noinit (no undriven-output warnings).
always @(*)
begin
    RxEqEval = 16'b0;
    InvalidRequest = 16'b0;
end

endmodule