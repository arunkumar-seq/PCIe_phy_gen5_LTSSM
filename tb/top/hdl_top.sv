module hdl_top;

  `include "settings.svh"
  `include "uvm_macros.svh"

  import uvm_pkg::*;
  import common_pkg::*;
  import utility_pkg::*;
  import lpif_agent_pkg::*;
  import pipe_agent_pkg::*;
  import pcie_env_pkg::*;
  import pcie_seq_pkg::*;

  // clk and reset
  //
  logic clk;
  // logic reset;

  //
  
  initial begin
    string argument_value;
    uvm_cmdline_processor cmdline_proc;
    cmdline_proc = uvm_cmdline_processor::get_inst();
    cmdline_proc.get_arg_value("+IS_ENV_UPSTREAM=", argument_value);
    IS_ENV_UPSTREAM = `IS_ENV_UPSTREAM;
  end

  // Instantiate the pin interfaces:
  //
  lpif_if #(
    .lpif_bus_width(`LPIF_BUS_WIDTH)
  ) LPIF(
    .lclk(clk)
  );   // LPIF interface

  pipe_if #(
    .pipe_num_of_lanes(`NUM_OF_LANES),
    .pipe_max_width(`PIPE_MAX_WIDTH)
  ) PIPE(
    .PCLK(clk)
    // reset
  );  // PIPE Interface
  
  //
  // Instantiate the BFM interfaces:
  //
  lpif_driver_bfm #(
    .lpif_bus_width(`LPIF_BUS_WIDTH)
  ) LPIF_drv_bfm(
    .reset                  (LPIF.reset),
    .lclk                   (LPIF.lclk),
    .pl_trdy                (LPIF.pl_trdy),
    .pl_data                (LPIF.pl_data),
    .pl_valid               (LPIF.pl_valid),
    .lp_irdy                (LPIF.lp_irdy),
    .lp_data                (LPIF.lp_data),
    .lp_valid               (LPIF.lp_valid),
    .pl_linkup              (LPIF.pl_linkup),
    .lp_state_req           (LPIF.lp_state_req),
    .pl_state_sts           (LPIF.pl_state_sts),
    .lp_force_detect        (LPIF.lp_force_detect),
    .pl_speed_mode          (LPIF.pl_speed_mode),

    .pl_tlp_start           (LPIF.pl_tlp_start),
    .pl_tlp_end             (LPIF.pl_tlp_end),
    .pl_dllp_start          (LPIF.pl_dllp_start),
    .pl_dllp_end            (LPIF.pl_dllp_end),
    .pl_tlpedb              (LPIF.pl_tlpedb),

    .lp_tlp_start           (LPIF.lp_tlp_start),
    .lp_tlp_end             (LPIF.lp_tlp_end),
    .lp_dllp_start          (LPIF.lp_dllp_start),
    .lp_dllp_end            (LPIF.lp_dllp_end),
    .lp_tlpedb              (LPIF.lp_tlpedb)

  //	.pl_exit_cg_req         (LPIF.pl_exit_cg_req),
  //	.lp_exit_cg_ack         (LPIF.lp_exit_cg_ack),
  );

  lpif_monitor_bfm #(
    .lpif_bus_width(`LPIF_BUS_WIDTH)
  ) LPIF_mon_bfm(
    .reset                  (LPIF.reset),
    .lclk                   (LPIF.lclk),
    .pl_trdy                (LPIF.pl_trdy),
    .pl_data                (LPIF.pl_data),
    .pl_valid               (LPIF.pl_valid),
    .lp_irdy                (LPIF.lp_irdy),
    .lp_data                (LPIF.lp_data),
    .lp_valid               (LPIF.lp_valid),
    .pl_linkup              (LPIF.pl_linkup),
    .lp_state_req           (LPIF.lp_state_req),
    .pl_state_sts           (LPIF.pl_state_sts),
    .lp_force_detect        (LPIF.lp_force_detect),
    .pl_speed_mode          (LPIF.pl_speed_mode),

    .pl_tlp_start           (LPIF.pl_tlp_start),
    .pl_tlp_end             (LPIF.pl_tlp_end),
    .pl_dllp_start          (LPIF.pl_dllp_start),
    .pl_dllp_end            (LPIF.pl_dllp_end),
    .pl_tlpedb              (LPIF.pl_tlpedb),
  
    .lp_tlp_start           (LPIF.lp_tlp_start),
    .lp_tlp_end             (LPIF.lp_tlp_end),
    .lp_dllp_start          (LPIF.lp_dllp_start),
    .lp_dllp_end            (LPIF.lp_dllp_end),
    .lp_tlpedb              (LPIF.lp_tlpedb)

  //	.pl_exit_cg_req         (LPIF.pl_exit_cg_req),
  //	.lp_exit_cg_ack         (LPIF.lp_exit_cg_ack),
  );

  pipe_driver_bfm #(
    .pipe_num_of_lanes(`NUM_OF_LANES),
    .pipe_max_width(`PIPE_MAX_WIDTH)
  ) PIPE_drv_bfm(
    .PCLK                  (PIPE.PCLK), 
    .RxData                (PIPE.RxData),
    .RxDataValid           (PIPE.RxDataValid),
    .RxDataK               (PIPE.RxDataK),
    .RxValid               (PIPE.RxValid),
    .PhyStatus             (PIPE.PhyStatus),
    .RxElecIdle            (PIPE.RxElecIdle),
    .RxStatus              (PIPE.RxStatus),
    .RxStartBlock          (PIPE.RxStartBlock),
    .RxSyncHeader          (PIPE.RxSyncHeader),
    .TxData                (PIPE.TxData),
    .TxDataK               (PIPE.TxDataK),
    .TxDataValid           (PIPE.TxDataValid),
    .TxDetectRxLoopback    (PIPE.TxDetectRxLoopback),
    .TxElecIdle            (PIPE.TxElecIdle),
    .Width                 (PIPE.Width),
    .Rate                  (PIPE.Rate),
    .PCLKRate              (PIPE.PCLKRate),
    .Reset                 (PIPE.Reset),                      
    .TxStartBlock          (PIPE.TxStartBlock),
    .TxSyncHeader          (PIPE.TxSyncHeader),
    .PowerDown             (PIPE.PowerDown),
    .PclkChangeAck (PIPE.PclkChangeAck),
    .PclkChangeOk (PIPE.PclkChangeOk),
    .M2P_MessageBus (PIPE.M2P_MessageBus),
    .P2M_MessageBus (PIPE.P2M_MessageBus),
    .LocalTxPresetCoeffcients (PIPE.LocalTxPresetCoeffcients),
    .TxDeemph (PIPE.TxDeemph),
    .LocalFS (PIPE.LocalFS),
    .LocalLF (PIPE.LocalLF),
    .GetLocalPresetCoeffcients (PIPE.GetLocalPresetCoeffcients),
    .LocalTxCoeffcientsValid (PIPE.LocalTxCoeffcientsValid),
    .FS (PIPE.FS),
    .LF (PIPE.LF),
    .RxEqEval (PIPE.RxEqEval),
    .LocalPresetIndex (PIPE.LocalPresetIndex),
    .InvalidRequest (PIPE.InvalidRequest),
    .LinkEvaluationFeedbackDirectionChange (PIPE.LinkEvaluationFeedbackDirectionChange)
  );

  pipe_monitor_bfm #(
    .pipe_num_of_lanes(`NUM_OF_LANES),
    .pipe_max_width(`PIPE_MAX_WIDTH)
  ) PIPE_mon_bfm(
    .PCLK                  (PIPE.PCLK), 
    .RxData                (PIPE.RxData),
    .RxDataValid           (PIPE.RxDataValid),
    .RxDataK               (PIPE.RxDataK),
    .RxValid               (PIPE.RxValid),
    .PhyStatus             (PIPE.PhyStatus),
    .RxElecIdle            (PIPE.RxElecIdle),
    .RxStatus              (PIPE.RxStatus),
    .RxStartBlock          (PIPE.RxStartBlock),
    .RxSyncHeader          (PIPE.RxSyncHeader),
    .RxStandby             (PIPE.RxStandby),
    .TxData                (PIPE.TxData),
    .TxDataK               (PIPE.TxDataK),
    .TxDataValid           (PIPE.TxDataValid),
    .TxDetectRxLoopback    (PIPE.TxDetectRxLoopback),
    .TxElecIdle            (PIPE.TxElecIdle),
    .Width                 (PIPE.Width),
    .Rate                  (PIPE.Rate),
    .PCLKRate              (PIPE.PCLKRate),
    .Reset                 (PIPE.Reset),                      
    .TxStartBlock          (PIPE.TxStartBlock),
    .TxSyncHeader          (PIPE.TxSyncHeader),
    .PowerDown             (PIPE.PowerDown),
    .PclkChangeAck (PIPE.PclkChangeAck),
    .PclkChangeOk (PIPE.PclkChangeOk),
    .M2P_MessageBus (PIPE.M2P_MessageBus),
    .P2M_MessageBus (PIPE.P2M_MessageBus),
    .LocalTxPresetCoeffcients (PIPE.LocalTxPresetCoeffcients),
    .TxDeemph (PIPE.TxDeemph),
    .LocalFS (PIPE.LocalFS),
    .LocalLF (PIPE.LocalLF),
    .GetLocalPresetCoeffcients (PIPE.GetLocalPresetCoeffcients),
    .LocalTxCoeffcientsValid (PIPE.LocalTxCoeffcientsValid),
    .FS (PIPE.FS),
    .LF (PIPE.LF),
    .RxEqEval (PIPE.RxEqEval),
    .LocalPresetIndex (PIPE.LocalPresetIndex),
    .InvalidRequest (PIPE.InvalidRequest),
    .LinkEvaluationFeedbackDirectionChange (PIPE.LinkEvaluationFeedbackDirectionChange)
  );

    
  // DUT
  PCIe #(
    .MAXPIPEWIDTH (`PIPE_MAX_WIDTH),
    .DEVICETYPE (!`IS_ENV_UPSTREAM), //0 for downstream 1 for upstream
    .LANESNUMBER (`NUM_OF_LANES),
    .GEN1_PIPEWIDTH (`GEN1_PIPEWIDTH) ,	
    .GEN2_PIPEWIDTH (`GEN2_PIPEWIDTH) ,	
    .GEN3_PIPEWIDTH (`GEN3_PIPEWIDTH) ,								
    .GEN4_PIPEWIDTH (`GEN4_PIPEWIDTH) ,	
    .GEN5_PIPEWIDTH (`GEN5_PIPEWIDTH) ,	
    .MAX_GEN (`MAX_GEN_DUT)
  ) DUT (
  . CLK (clk),
  . lpreset                               (LPIF.reset),
  . phy_reset                             (PIPE.Reset),
  . width                                 (PIPE.Width),
  . TxData                                (PIPE.TxData),
  . TxDataValid                           (PIPE.TxDataValid),
  . TxElecIdle                            (PIPE.TxElecIdle),
  . TxStartBlock                          (PIPE.TxStartBlock),
  . TxDataK                               (PIPE.TxDataK),
  . TxSyncHeader                          (PIPE.TxSyncHeader),
  . TxDetectRx_Loopback                   (PIPE.TxDetectRxLoopback),
  . RxData                                (PIPE.RxData),
  . RxDataValid                           (PIPE.RxDataValid),
  // ---------------------------------------------------------------------
  // SIM-003  (hdl_top.sv - RxDataK was wired to RxDataValid)
  // Root cause : the DUT's RxDataK port was connected to PIPE.RxDataValid
  //              instead of PIPE.RxDataK. RxDataValid is 1 bit per lane
  //              ([pipe_num_of_lanes-1:0] = 16 bits) while RxDataK is 1 bit
  //              per *byte* ([bus_data_kontrol_param:0] = (32/8)*16 = 64 bits)
  //              and the DUT port is [(MAXPIPEWIDTH/8)*LANESNUMBER-1:0] = 64
  //              bits. So the connection was both the wrong signal and the
  //              wrong width: every K-character (control-symbol) indicator
  //              reaching the DUT was actually the lane's data-valid bit, and
  //              the upper 48 bits were implicitly zero-extended.
  // Impact     : the RX ordered-set checker (osChecker) classifies symbols as
  //              data vs. control purely from RxDataK, so TS1/TS2/SKP/EIOS/SDS
  //              detection and therefore the whole RX LTSSM was fed garbage.
  // Fix        : connect the intended interface member, PIPE.RxDataK, whose
  //              width (64) matches the DUT port exactly. No DUT or interface
  //              declaration was changed.
  // Expected   : RxDataK carries per-byte K indicators from the PIPE driver
  //              BFM into the DUT; ordered sets are recognised correctly.
  // Verification: width/decl cross-check against rtl/PCIE.v:31 and
  //              tb/agents/pipe_agent/pipe_if.sv:19 (done in sandbox).
  //              QuestaSim re-run: NOT VERIFIED (simulator only exists on the
  //              user's Windows machine). Fix originally found by the user.
  // ---------------------------------------------------------------------
  . RxDataK                               (PIPE.RxDataK),
  . RxStartBlock                          (PIPE.RxStartBlock),
  . RxSyncHeader                          (PIPE.RxSyncHeader),
  //. RxStandby                             (PIPE.RxStandby), // missing the design now 
  . RxStatus                              (PIPE.RxStatus),
  // ---------------------------------------------------------------------
  // WIDTH-001  (hdl_top.sv - RxElectricalIdle 1-bit vs 16-bit port)
  // Root cause : the DUT port is `input [15:0] RxElectricalIdle`
  //              (rtl/PCIE.v:35 - one electrical-idle indicator per lane,
  //              LANESNUMBER=16), but pipe_if declares RxElecIdle as a SCALAR
  //              (`logic RxElecIdle;`, pipe_if.sv:25). Connecting a 1-bit net
  //              to a 16-bit port relies on implicit zero-extension, so lanes
  //              1..15 were permanently tied to "not in electrical idle" and
  //              only lane 0 ever saw the driver's value. QuestaSim reports
  //              this as a port-width mismatch warning and the per-lane RX
  //              logic then behaves inconsistently across lanes.
  // Fix        : replicate the scalar explicitly to all 16 lanes with
  //              {16{PIPE.RxElecIdle}}. This keeps the interface declaration
  //              untouched (no architecture change) and makes the intent -
  //              "one common electrical-idle indicator broadcast to every
  //              lane" - explicit and width-correct.
  // Expected   : all 16 lane slices of RxElectricalIdle follow the PIPE
  //              driver's single RxElecIdle; no width-mismatch warning.
  // Verification: widths cross-checked against rtl/PCIE.v:35 and pipe_if.sv:25
  //              (done in sandbox). QuestaSim re-run: NOT VERIFIED. Fix
  //              originally found by the user.
  // ---------------------------------------------------------------------
  . RxElectricalIdle                      ({16{PIPE.RxElecIdle}}),
  . PowerDown                             (PIPE.PowerDown),
  . Rate                                  (PIPE.Rate),
  . PhyStatus                             (PIPE.PhyStatus),  
  . PCLKRate                              (PIPE.PCLKRate),
  . PclkChangeAck                         (PIPE.PclkChangeAck),
  . PclkChangeOk                          (PIPE.PclkChangeOk),
  .	LocalTxPresetCoefficients             (PIPE.LocalTxPresetCoeffcients),
  .	TxDeemph                              (PIPE.TxDeemph),
  .	LocalFS                               (PIPE.LocalFS),
  .	LocalLF                               (PIPE.LocalLF),
  .	LocalPresetIndex                      (PIPE.LocalPresetIndex),
  .	GetLocalPresetCoeffcients             (PIPE.GetLocalPresetCoeffcients),
  .	LocalTxCoefficientsValid              (PIPE.LocalTxCoeffcientsValid),
  .	LF                                    (PIPE.LF),
  .	FS                                    (PIPE.FS),
  .	RxEqEval                              (PIPE.RxEqEval),
  .	InvalidRequest                        (PIPE.InvalidRequest),
  .	LinkEvaluationFeedbackDirectionChange (PIPE.LinkEvaluationFeedbackDirectionChange),
  
  . pl_trdy         (LPIF.pl_trdy),
  . lp_irdy         (LPIF.lp_irdy),
  . lp_data         (LPIF.lp_data),
  . lp_valid        (LPIF.lp_valid),
  . pl_data         (LPIF.pl_data),
  . pl_valid        (LPIF.pl_valid),
  . lp_state_req    (LPIF.lp_state_req),
  . pl_state_sts    (LPIF.pl_state_sts),
  . pl_speedmode    (LPIF.pl_speed_mode),
  . lp_force_detect (LPIF.lp_force_detect),
  . lp_dlpstart     (LPIF.lp_dllp_start) ,
  . lp_dlpend       (LPIF.lp_dllp_end),
  . lp_tlpstart     (LPIF.lp_tlp_start),
  . lp_tlpend       (LPIF.lp_tlp_end),
  . pl_dlpstart     (LPIF.pl_dllp_start),
  . pl_dlpend       (LPIF.pl_dllp_end),
  . pl_tlpstart     (LPIF.pl_tlp_start),
  . pl_tlpend       (LPIF.pl_tlp_end),
  . pl_tlpedb       (LPIF.pl_tlpedb),
  . pl_linkUp          (LPIF.pl_linkup)
  );


  // UVM initial block:
  // Virtual interface wrapping & run_test()
  initial begin //tbx vif_binding_block
    import uvm_pkg::uvm_config_db;
    uvm_config_db #(lpif_driver_bfm_param) ::set(null, "uvm_test_top", "lpif_driver_bfm", LPIF_drv_bfm);
    uvm_config_db #(lpif_monitor_bfm_param)::set(null, "uvm_test_top", "lpif_monitor_bfm", LPIF_mon_bfm);
    uvm_config_db #(pipe_driver_bfm_param) ::set(null, "uvm_test_top", "pipe_driver_bfm", PIPE_drv_bfm);
    uvm_config_db #(pipe_monitor_bfm_param)::set(null, "uvm_test_top", "pipe_monitor_bfm", PIPE_mon_bfm);
  end

  //
  // Clock and reset initial block:
  //
  initial begin
    clk = 0;
    forever #1 clk = ~clk;
  end
  // initial begin 
  //   reset = 0;
  //   repeat(4) @(posedge clk);
  //   reset = 1;
  // end

  // -------------------------------------------------------------------------
  // SIM-009  (hdl_top.sv - progress heartbeat could not be silenced)
  // Root cause : the 50 us progress heartbeat was issued at UVM_NONE. UVM_NONE
  //              messages are printed UNCONDITIONALLY - UVM verbosity filtering
  //              (+UVM_VERBOSITY=...) does not apply to them - so a pure
  //              debug/progress trace polluted every transcript and could not
  //              be turned off, which matters because `make run` output is what
  //              the user reads to spot real errors.
  // Fix        : issue it at UVM_DEBUG, the verbosity reserved for debug-only
  //              tracing. It still appears when the user explicitly asks for
  //              maximum verbosity and is silent otherwise. Testbench-only
  //              change; no DUT, interface or message text affected.
  // Expected   : quiet transcripts by default, heartbeat available on demand.
  // Verification: change originally made by the user in tb_edited/; adopted
  //              here. NOT VERIFIED in sandbox (no QuestaSim).
  // -------------------------------------------------------------------------
  initial begin
    forever #50000 `uvm_info("hdl_top", $sformatf("Time: %t", $time), UVM_DEBUG)
  end

  initial begin
    `uvm_info("hdl_top", $sformatf("DEVICETYPE (%b)", !`IS_ENV_UPSTREAM), UVM_NONE)
  end

endmodule: hdl_top
