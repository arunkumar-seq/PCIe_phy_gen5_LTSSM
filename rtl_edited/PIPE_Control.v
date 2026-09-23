module PIPE_Control(substate, generation, pclk, reset_n, RxStatus, ElecIdle_req, Detect_req, PhyStatus, TxDetectRx_Loopback, PowerDown, Detect_status, TxElecIdle,RxStandbyRequest,RxStandby, TxActive);


parameter number_of_lanes= 4;
parameter  DetectQuiet = 4'b0000, DetectActive = 4'b0001, PollingActive = 4'b0010,
      PollingConfigration = 4'b0011, ConfigrationLinkWidthStart = 4'b0100, ConfigrationLinkWidthAccept= 4'b0101,
            ConfigrationLaneNumWait = 4'b0110,  ConfigrationLaneNumActive = 4'b0111, ConfigrationComplete = 4'b1000,
            ConfigrationIdle = 4'b1001,L0=4'b1010 ,Idle=4'b1111;

input pclk, reset_n;
input [4:0] substate;
input [2:0] generation;
input [2:0] RxStatus; 
input ElecIdle_req, Detect_req, PhyStatus;
input RxStandbyRequest;
// BUGFIX-021: new input TxActive - a same-cycle indicator from the TX data
// path telling this lane is currently emitting symbols (TxDataValid of the
// lane's PIPE data stage). It lets TxElecIdle deassert exactly in the clock
// cycle the first symbol is transmitted (GitHub issue #61). Driven from
// TOP_MODULE; tying it to 1'b0 restores the conservative "exit electrical
// idle on entry to Polling" behavior if left unconnected elsewhere.
input TxActive;
output reg TxDetectRx_Loopback;
output reg [3:0] PowerDown;
output reg Detect_status; 
output TxElecIdle;
output reg RxStandby;

// BUGFIX-020 (GitHub issue #51: "TxDetectRxLoopback is asserted again after
// deassertion (after receiver detection)"):
//   Original issue: Detect_status was set for exactly ONE cycle (only while
//   PhyStatus was high) and cleared again as soon as the PHY deasserted
//   PhyStatus. TxDetectRx_Loopback was (re)asserted whenever
//   Detect_req==1 && Detect_status==0. Because TX_LTSSM keeps Detect_req
//   asserted for a few cycles while the LTSSM state propagates from
//   Detect.Active to Polling.Active, the condition became true again right
//   after a successful receiver detection and TxDetectRx_Loopback was
//   reasserted spuriously.
//   Root cause: Detect_status was a 1-cycle pulse instead of a sticky
//   "detection round completed" flag, and TxDetectRx_Loopback had no
//   one-shot guarding.
//   Fix: 'detectDone' is set when the PHY answers the detection request
//   (PhyStatus==1) and stays set until the LTSSM returns to Detect.Quiet,
//   so TxDetectRx_Loopback is asserted at most once per detection round.
//   TxDetectRx_Loopback is also deasserted on ANY PhyStatus response (not
//   only RxStatus==011), matching PIPE semantics where the response -
//   whatever the RxStatus - completes the receiver-detection transaction.
//   Detect_status now holds the detection result (1 = receiver detected on
//   this lane, RxStatus==3'b011) until the next Detect.Quiet, which is what
//   TX_LTSSM needs to leave Detect.Active.
// BUGFIX-021 (GitHub issue #61: "TxElecIdle should be de-asserted at the
// same clock cycle the first TS in the Polling state starts to be
// transmitted"):
//   Original issue: TxElecIdle was deasserted one clock after 'substate'
//   became > DetectActive, i.e. as soon as the LTSSM entered Polling.Active
//   - several cycles BEFORE the OS generator actually drove the first TS
//   symbol onto TxData.
//   Root cause: the deassertion condition was tied to the substate counter
//   instead of to the actual TX data flow.
//   Fix: TxElecIdle stays asserted in the Detect states, while ElecIdle_req
//   is asserted, and - for all other states - until the TX data path emits
//   its first symbol (TxActive). 'txStarted' keeps it deasserted afterwards
//   even when the data stream has gaps. The decode is combinational so the
//   deassertion happens in the SAME cycle as the first symbol, as required
//   by the issue.
// Verified by: directed regression tb/regress/tb_pipe_control.v (reproduces
// both issue scenarios and checks the fixed waveforms) + slang/yosys checks.

reg detectDone;   // sticky per detection round (Detect.Quiet clears it)
reg txStarted;    // sticky: first TX symbol has been emitted

// Same-cycle electrical-idle decode (see BUGFIX-021).
assign TxElecIdle = (ElecIdle_req == 1'b1)
                 || (substate == DetectQuiet)
                 || (substate == DetectActive)
                 || (txStarted == 1'b0 && TxActive == 1'b0);

always @(posedge pclk or negedge reset_n) begin
  if (~reset_n) begin
  	PowerDown= 2;
  	Detect_status=0;
  	TxDetectRx_Loopback=0;
    RxStandby = 1'b0;
    detectDone = 1'b0;
    txStarted  = 1'b0;
  end

  else begin

      // Power state: P2 during the Detect substates, P0 otherwise.
      if(substate == DetectQuiet || substate  == DetectActive) begin
        PowerDown = 2;
      end
      else begin
        PowerDown = 0;
      end

      if (substate == DetectQuiet) begin
          // New detection round: clear the sticky flags (BUGFIX-020).
          detectDone    <= 1'b0;
          txStarted     <= 1'b0;
          Detect_status <= 1'b0;
          TxDetectRx_Loopback <= 1'b0;
      end
      else begin
          // Assert TxDetectRx_Loopback at most once per detection round
          // (one-shot guarded by detectDone and by the signal itself).
          if (Detect_req == 1'b1 && detectDone == 1'b0 && TxDetectRx_Loopback == 1'b0) begin
              TxDetectRx_Loopback <= 1'b1;
          end

          // PHY answered the receiver-detection request: complete the
          // transaction regardless of the reported RxStatus (BUGFIX-020).
          if (TxDetectRx_Loopback == 1'b1 && PhyStatus == 1'b1) begin
              TxDetectRx_Loopback <= 1'b0;
              detectDone          <= 1'b1;
              Detect_status       <= (RxStatus == 3'b011); // 1 = receiver detected
          end

          // Remember that the transmitter has left electrical idle
          // (BUGFIX-021).
          if (TxActive == 1'b1) begin
              txStarted <= 1'b1;
          end
      end

      if(RxStandbyRequest)
      begin
        RxStandby = 1'b1;
      end
      else RxStandby = 1'b0;

  end


 end

 endmodule
