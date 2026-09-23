// ===========================================================================
// SIM-012  (tb.v - scratch bench for a PRE-REFACTOR os_checker interface)
//
// Root cause : this bench instantiates `os_checker #(0) test(...)` with 16
//              POSITIONAL port connections. The ordered-set checker in the
//              current design is rtl/OS_Checker.v, module name `osChecker`
//              (note the capitalisation - Verilog identifiers are case
//              sensitive, hence slang's "unknown module 'os_checker'"), and it
//              has 29 ANSI ports: the 16 this bench drives plus
//              directed_speed_change, gen and the whole per-lane equalization
//              read-back set (rateid/FS/LF, FSDSP, LFDSP, the four preset-hint
//              buses, CursorCoff, PreCursorCoff, PostCursorCoff, ...).
//              It also instantiates `counter #(8) Counter(...)` while rtl/
//              Counter.v declares `module counter` with NO parameters at all
//              (slang: "too many parameter assignments given for 'counter'").
//              So this is not a rename: the bench predates the equalization
//              support that was added to osChecker and cannot be connected to
//              today's module without inventing new stimulus.
//
// Why not "fix" it : making it elaborate would mean either (a) adding the 13
//              missing arguments with made-up values - i.e. writing a NEW
//              testbench and silently changing what this one checks, or
//              (b) adding parameters/ports to the DUT, which the mission
//              explicitly forbids. Neither is a bug fix, and the project rule
//              is not to delete tests to hide errors either.
//
// Fix        : the bench is preserved BYTE-FOR-BYTE but compiled only when
//              `INCLUDE_LEGACY_OS_CHECKER_TB` is defined, so it can never
//              break `vlog rtl/*.v` / the default elaboration again while
//              remaining available for reference or for a future rewrite.
//              To bring it back:
//                 vlog +define+INCLUDE_LEGACY_OS_CHECKER_TB rtl/tb.v
//
// STATUS     : NEEDS A USER DECISION - either rewrite this bench against the
//              29-port osChecker (new stimulus, out of scope of a bug fix) or
//              retire it. Until then it is opt-in, not deleted.
//
// Verification: slang elaboration of rtl/*.v --top PCIe goes from 2 errors to 0
//              for this file (executed in sandbox). Not run in QuestaSim
//              (NOT VERIFIED - simulator only exists on the user's machine).
// ===========================================================================
`ifdef INCLUDE_LEGACY_OS_CHECKER_TB
module tb;
    reg clk;
    reg linkNumber;
    reg laneNumber;
    reg [127:0]orderedset;
    reg valid;
    reg [3:0]substate;
    reg reset;
    wire countup;
    wire resetcounter;
    wire [7:0] rateid;
    wire upconfigure_capability;
wire[4:0]currentState,nextState;
wire [7:0]link,lane,id;
wire[7:0]currentcount;
 localparam [7:0]
    PAD = 8'b11110111, //F7
    TS1 = 8'b00101010,	//2A
    TS2 = 8'b00100101;  //25

localparam [3:0]
	detectQuiet =  3'd0,
	detectActive = 3'd1,
	pollingActive= 3'd2,
	pollingConfiguration= 3'd3,
    configurationLinkWidthStart = 3'd4,
    configurationLinkWidthAccept = 3'd5,
    configurationLanenumWait = 3'd6,
    configurationLanenumAccept = 3'd7,
    configurationComplete = 4'd8, // BUGFIX-033: was 3'd8 (value does not fit in 3 bits)
    configurationIdle = 4'd9;     // BUGFIX-033: was 3'd9 (value does not fit in 3 bits)

os_checker #(0) test(clk,
    linkNumber,
    laneNumber,
    orderedset,
    valid,
    substate,
    reset,
    countup,
    resetcounter,
    rateid,
    upconfigure_capability,currentState,nextState,link,lane,id);
counter #(8)Counter(resetcounter,clk,countup,currentcount);

initial
begin
clk = 0;
reset = 0;
#12
reset = 1;
substate = pollingActive;
#10
valid = 1'b1;
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 1
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 2
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 3
#10
orderedset = 128'h25252525252525AAAAAAAAAA; //counter = 0
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 1
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 2
#10
reset = 0;
#10
valid = 0;
reset = 1;
substate = pollingConfiguration;
#10
valid = 1'b1;
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 1
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 2
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 3
#10
orderedset = 128'h25252525252525AAAAAAAAAA; //counter = 0
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 1
#10
orderedset = 128'h25252525252525AAAAF7F7F7; //counter = 2
#10
reset = 0;

#10
valid = 0;
reset = 1;
substate = configurationLinkWidthStart;
linkNumber = 1;
#10
valid = 1'b1;
orderedset = 128'h2A2A2A2A2A2A2AAAAAF701F7; //counter = 1
#10
orderedset = 128'h2A2A2A2A2A2A2AAAAAF701F7; //counter = 2
#10
orderedset = 128'h2A2A2A2A2A2A2AAAAAF701F7; //counter = 3
#10
orderedset = 128'h25252525252525AAAAAAAAAA; //counter = 0
#10
orderedset = 128'h2A2A2A2A2A2A2AAAAAF701F7; //counter = 1
#10
orderedset = 128'h2A2A2A2A2A2A2AAAAAF701F7; //counter = 2
#10
reset = 0;

end


always #5 clk = ~clk;
endmodule

`endif // INCLUDE_LEGACY_OS_CHECKER_TB  (SIM-012)
