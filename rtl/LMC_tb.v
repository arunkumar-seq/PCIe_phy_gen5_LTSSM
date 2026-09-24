// ===========================================================================
// SIM-013  (LMC_tb.v - bench instantiated the wrong lane-management module)
//
// Root cause : the bench instantiated `LMC`, but every port it connects -
//              clk, reset, GEN, descramblerSyncHeader, descramblerDataValid,
//              LANESNUMBER, LMCIn, descramblerDataK, LMCValid, LMCDataK,
//              LMCData - and the parameter it overrides (GEN1_PIPEWIDTH) are
//              the interface of `LMC_RX`, not of `LMC`. The design has TWO
//              lane-management blocks:
//                * LMC     (rtl/LMC.v)                     - TX side, 16 lanes,
//                  ports reset_n/pclk/generation/data_valid/data/d_k_in/
//                  MUXSyncHeader/PIPEWIDTH plus per-lane dataout_n, d_k_out_n,
//                  data_valid_out_n, LMCSyncHeader_n;
//                * LMC_RX  (rtl/Lane_Management_Control.v) - RX side, ports
//                  clk/reset/GEN/descramblerSyncHeader/descramblerDataValid/
//                  LANESNUMBER/LMCIn/descramblerDataK -> LMCValid/LMCSyncHeader/
//                  LMCDataK/LMCData, parameters GEN1..GEN5_PIPEWIDTH.
//              LMC_RX is the one actually instantiated by the RX block
//              (rtl/Modules Integration.v:103) with precisely this connection
//              list. So the bench is correct in substance and simply names the
//              wrong module - slang reported 11 "port ... does not exist in
//              'LMC'" errors, one per connection, and QuestaSim's vlog rejects
//              the instantiation the same way, which is why this file had to be
//              excluded from the compile list.
//
// Fix        : instantiate LMC_RX instead of LMC. One identifier changes; no
//              port connection, no stimulus, no DUT and no parameter is
//              touched. LMC_RX has no GEN1_PIPEWIDTH-only parameter list
//              problem either - it declares GEN1..GEN5_PIPEWIDTH, so the
//              existing `#(.GEN1_PIPEWIDTH(8))` override is valid as written.
//              The bench leaves LMC_RX's `LMCSyncHeader` output unconnected;
//              that is intentional here (the bench only watches LMCData /
//              LMCDataK / LMCValid) and produces at most an unconnected-port
//              warning, not an error.
//
// Expected   : LMC_tb elaborates and drives the RX lane-management block with
//              its original PIPEWIDTH 8/16/32 x LANESNUMBER 1/2/4/8/16 stimulus
//              sweep, unchanged.
//
// Verification: slang elaboration of rtl/*.v goes from 11 errors to 0 for this
//              file, and LMC_tb is one of the elaborated top-level candidates
//              (executed in sandbox). Port/parameter list cross-checked against
//              rtl/Lane_Management_Control.v:1 and rtl/Modules Integration.v:103.
//              QuestaSim re-run: NOT VERIFIED (simulator only exists on the
//              user's Windows machine).
// ===========================================================================
module LMC_tb();

	reg [2:0]GEN = 1;
	reg [4:0]LANESNUMBER;
	reg clk, reset;
	reg [511:0]LMCIn;
	reg [63:0]descramblerDataK;
	wire [511:0]LMCData;
	wire LMCValid;
	wire [63:0]LMCDataK;

	// SIM-013: was `LMC #(.GEN1_PIPEWIDTH(8)) lmc(...)` - see the header.
	LMC_RX #(.GEN1_PIPEWIDTH(8)) lmc(.clk(clk), .reset(reset), .GEN(GEN), .descramblerSyncHeader(2'b00), .descramblerDataValid(16'hFFFF), .LANESNUMBER(LANESNUMBER), 
									.LMCIn(LMCIn), .descramblerDataK(descramblerDataK), .LMCValid(LMCValid), .LMCDataK(LMCDataK), .LMCData(LMCData));

    always
	begin
		#50
		clk = ~clk;
	end

	always@(posedge clk)
		$monitor ("%0dns: $monitor:GEN = %d LANESNUMBER = %d descramblerDataK = %h LMCDataK = %b LMCIn = %h LMCData = %h", $stime, GEN, LANESNUMBER, descramblerDataK, LMCDataK, LMCIn, LMCData);

	initial 
	begin
		//==== initialize clk ====
		clk = 1;
		//==== reset ====
		reset = 0;
		#50
		reset = 1;
		#50;
		//=== PIPEWIDTH = 8 & any LANESNUMBER===
		GEN = 1;
		LANESNUMBER = 8;
		descramblerDataK = 64'b1111_0000_1010_0110_1001_0011_1000_0111_1111_0000_1111_1011_0110_1001_0011_1000;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 16 & LANESNUMBER = 1===
		GEN = 2;
		LANESNUMBER = 1;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 16 & LANESNUMBER = 2===
		LANESNUMBER = 2;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 16 & LANESNUMBER = 4===
		LANESNUMBER = 4;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 16 & LANESNUMBER = 8===
		LANESNUMBER = 8;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 16 & LANESNUMBER = 16===
		LANESNUMBER = 16;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 32 & LANESNUMBER = 1===
		GEN = 3;
		LANESNUMBER = 1;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 32 & LANESNUMBER = 2===
		LANESNUMBER = 2;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 32 & LANESNUMBER = 4===
		LANESNUMBER = 4;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 32 & LANESNUMBER = 8===
		LANESNUMBER = 8;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== PIPEWIDTH = 32 & LANESNUMBER = 16===
		LANESNUMBER = 16;
		LMCIn = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		LMCIn = 0;
	end
		

endmodule
