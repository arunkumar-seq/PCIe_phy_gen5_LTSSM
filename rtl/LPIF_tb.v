module LPIF_tb();

	reg [2:0]GEN;
	reg [3:0]state;
	reg clk, reset, lp_force_detect;
	reg [511:0]packetData;
	reg [63:0]stp, sdp, tlpEND, dllpEND, EDB, packetValid;
	wire [511:0]lpifData;
	wire [2:0]pl_speedmode;
	wire [3:0]pl_state_sts;
	wire [63:0]pl_dllpend, pl_dllpstart, pl_tlpStart, pl_tlpedb, pl_tlpend, pl_valid;

	// ---------------------------------------------------------------------
	// SIM-010  (LPIF_tb.v - four port connections to ports that no longer
	//           exist on LPIF_RX_Control_DataFlow)
	//
	// Root cause : this scratch bench was written against an older
	//              LPIF_RX_Control_DataFlow that also passed LTSSM state
	//              through the LPIF block. The module in
	//              rtl/LPIF RX Control & Data Flow.v now has exactly 18 ports:
	//                clk, reset, tlpstart, dllpstart, tlpend, dllpend, edb,
	//                packetValid, packetData, GEN,
	//                pl_tlpstart, pl_dllpstart, pl_tlpend, pl_dllpend,
	//                pl_tlpedb, pl_valid, pl_data, pl_speedmode
	//              The bench still connected .lp_force_detect(), .state(),
	//              .pl_state_sts() and .ltssmForceDetect(), none of which
	//              exist. slang reports one "port ... does not exist in
	//              'LPIF_RX_Control_DataFlow'" error per connection (4 errors)
	//              and QuestaSim's vlog rejects the instantiation, which is why
	//              this file had to be excluded from the compile list.
	//              `ltssmForceDetect` was not even declared in the bench, so it
	//              also relied on an implicit 1-bit net.
	// Fix        : drop the four dead connections. Adding the ports back to the
	//              DUT is NOT an option - the mission forbids changing DUT
	//              interfaces, and the LTSSM force-detect / state paths now live
	//              in mainLTSSM (rtl/maintlssm.v) and PCIe (rtl/PCIE.v), not in
	//              the LPIF RX control/data-flow block. The local `state`,
	//              `lp_force_detect` and `pl_state_sts` declarations and their
	//              stimulus in the initial block are kept (they are simply
	//              unconnected now) so no stimulus history is lost.
	// Expected   : the bench elaborates and still exercises the packet
	//              framing/pl_speedmode behaviour of the real module.
	// Verification: slang elaboration of rtl/*.v --top PCIe goes from 4 errors
	//              to 0 for this file (executed in sandbox). QuestaSim re-run:
	//              NOT VERIFIED (simulator only exists on the user's machine).
	// ---------------------------------------------------------------------
	LPIF_RX_Control_DataFlow lpif(.clk(clk),  .reset(reset), .tlpstart(stp), .dllpstart(sdp), .tlpend(tlpEND), .dllpend(dllpEND), .edb(EDB), 
							.packetValid(packetValid), .packetData(packetData), .GEN(GEN), 
							.pl_tlpstart(pl_tlpStart), .pl_dllpstart(pl_dllpstart), .pl_tlpend(pl_tlpend), .pl_dllpend(pl_dllpend), 
							.pl_tlpedb(pl_tlpedb), .pl_valid(pl_valid), .pl_data(lpifData), .pl_speedmode(pl_speedmode));

    always
	begin
		#50
		clk = ~clk;
	end

	always@(posedge clk)
		$monitor ("%0dns: $monitor:packetData = %h LPIF Data = %h", $stime, packetData, lpifData);

	initial 
	begin
		//==== initialize clk ====
		clk = 1;
		//==== reset ====
		reset = 0;
		#50
		reset = 1;
		#50;
		//=== test===
		GEN = 1;
		state = 1;
		lp_force_detect = 1;
		stp = 64'b0; 
		sdp = 64'b0;
		tlpEND = 64'b0;
		dllpEND = 64'b0;
		EDB = 64'b0;
		packetValid = 64'hFFFFFFFFFFFFFFFF;
		packetData = 512'h01_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== test===
		GEN = 2;
		state = 2;
		lp_force_detect = 0;
		stp = {1'b1, 63'b0}; 
		sdp = 0;
		tlpEND = 0;
		dllpEND = 0;
		EDB = 0;
		packetValid = {4'b0111,60'hFFFFFFFFFFFFFFF};
		packetData = 512'hFB_05_0A_0E__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		//=== test===
		GEN = 3;
		state = 3;
		lp_force_detect = 1;
		stp = 0; 
		sdp = {4'b1,60'b0};
		tlpEND = 0;
		dllpEND = 0;
		EDB = 0;
		packetValid = {4'b1110,60'hFFFFFFFFFFFFFFF};
		packetData = 512'h01_05_0A_5C__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_3A;
		#100;
		sdp = 0;
		tlpEND = 64'b1;
		packetValid = {60'hFFFFFFFFFFFFFFF,4'b1110};
		packetData = 512'h01_05_0A_4B__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_FD;
		#100;
		tlpEND = 0;
		EDB = {4'b1000,60'b0};
		sdp = {4'b1,60'b0};
		dllpEND = {63'b0,1'b1};
		packetValid = {4'b0110,60'hFFFFFFFFFFFFFFE};
		packetData = 512'hFE_05_0A_5C__02_06_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_FD;
		#100;
		dllpEND = 0;
		EDB = {1'b1, 63'b0};
		sdp = {8'b00010100,56'b0};
		packetValid = {8'b01101011,56'hFFFFFFFFFFFFFF};
		packetData = 512'hFE_05_0A_5C__02_5C_0B_0F__03_07_0C_1A__04_08_0D_1B__05_09_0E_1C__06_10_0F_1D__07_11_1A_1E__08_12_1B_1F__09_13_1C_0E__10_14_1D_2A__11_15_1E_2B__12_16_1F_2C__13_17_2A_2D__14_18_2B_2E__15_19_2C_2F__16_20_2D_FD;
		#100;
		$stop;
	end

endmodule
