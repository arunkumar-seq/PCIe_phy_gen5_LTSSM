
module osDecoder #(
parameter Width = 32,
parameter GEN1_PIPEWIDTH = 64 ,	
parameter GEN2_PIPEWIDTH = 8 ,	
parameter GEN3_PIPEWIDTH = 8 ,	
parameter GEN4_PIPEWIDTH = 8 ,	
parameter GEN5_PIPEWIDTH = 8 )
(
input clk,
input [2:0]gen,
input reset,
input [4:0]numberOfDetectedLanes,
input [511:0]data,
input validFromLMC,	
input linkUp,
input [4:0] substate,
input [2*16-1:0] syncHeader,
output reg valid,
output reg [2047:0]outOs);

reg [9:0]width;
reg [2047:0]orderedSets,orderedSetsnext,out;
reg [2:0]numberOfShifts;
reg found;
reg validnext;
reg [3:0] lane_iter;
reg [6:0] index_iter;
reg [11:0]capacity,capacitynext;
integer i,j;
parameter[7:0]
COM = 	8'b10111100, //BC
gen3TS1 = 8'h1E,
gen3TS2 = 8'h2D,
gen3SKIP =8'hAA,
gen3EIOS = 8'h66,
gen3EIEOSsymb1 = 8'h00,
gen3EIEOSsymb2 = 8'hFF, 
STP = 8'b11111011,
SDP = 8'b01011100,
SDS = 8'hE1;


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



// ---------------------------------------------------------------------
// BUGFIX-048  (osDecoder.v - named constant for the de-interleave loop bound)
// 2048 is the maximum value `128<<numberOfShifts` can take for any legal lane
// count (numberOfShifts is 0..4 for 1/2/4/8/16 lanes), and it is also exactly
// the width of `out`, so it is the largest bound for which `out[j+:8]` stays in
// range. See the loop below for the full argument.
// ---------------------------------------------------------------------
localparam integer OSD_OUT_BITS = 2048;

parameter [175:0] lanesOffsets ={11'd1920,11'd1792,11'd1664,11'd1536,11'd1408,11'd1280,11'd1152
,11'd1024,11'd896,11'd768,11'd640,11'd512,11'd384,11'd256,11'd128,11'd0};
always@(posedge clk or negedge reset)
begin
if(!reset)
begin
// ---------------------------------------------------------------------
// BUGFIX-050  (osDecoder.v - lane_iter / index_iter removed from this reset)
// These two were driven from BOTH here (non-blocking, reset branch only) and
// from the combinational de-interleave block at the bottom of this file
// (blocking, every evaluation). Two processes assigning the same `reg` is a
// multiple-driver conflict: in simulation the result depends on evaluation
// order, and synthesis cannot merge a clocked and a combinational driver into
// one net. They are loop iterators, not state - the de-interleave block now
// initializes them itself at entry (see BUGFIX-050 there), so they are removed
// from this reset. `orderedSets`, `capacity` and `valid` are genuine state and
// are untouched.
// ---------------------------------------------------------------------
orderedSets <=2048'b0;
capacity<=12'd0;
valid<=1'b0;
end
else
begin
	capacity <= capacitynext;
	orderedSets<=orderedSetsnext;
	valid <= validnext;
end
end
always@(*)
begin
validnext=1'b0;
found = 1'b0;
if(validFromLMC)
begin
		// -----------------------------------------------------------------
		// BUGFIX-054  (osDecoder.v - `valid` had two conflicting drivers)
		//
		// Root cause : `valid` is an `output reg` that the clocked block owns -
		//              reset at line ~98 (`valid<=1'b0`) and updated at line
		//              ~104 (`valid <= validnext`). This line ALSO drove it
		//              combinationally, via the concatenation
		//                  {out,valid} = {data,1'b1}
		//              so for substate 9 (configurationIdle) and 18
		//              (recoveryIdle) `valid` had BOTH a clocked and a
		//              combinational driver. yosys reports it on the whole
		//              closure as `multiple conflicting drivers for
		//              ...\osDecoder.\valid`; in simulation the resolved value
		//              depends on process evaluation order, i.e. it is a race.
		//
		// Fix        : drive `validnext` instead, which is the signal the
		//              clocked block already consumes. `valid` then has exactly
		//              one driver on every path, matching how every other branch
		//              of this module already works (they all set validnext and
		//              leave `valid` to the register).
		//              The concatenation is unrolled into its two halves so the
		//              bit mapping stays explicit. {out,valid} is 2049 bits and
		//              {data,1'b1} is 513, so the old statement zero-extended:
		//              valid=1, out[511:0]=data, out[2047:512]=0. `out = data`
		//              into a 2048-bit reg produces exactly the same value.
		//
		// Behavioural note (deliberate, and the point of the fix): for these
		//              two substates `valid` now asserts one Pclk later than it
		//              used to, because it is registered like everywhere else.
		//              `out`/`outOs` stay combinational, exactly as before. This
		//              makes the idle-passthrough path consistent with every
		//              other path in the module rather than the one exception.
		//
		// Verification: yosys closure `check` - `multiple conflicting drivers
		//              for ...osDecoder.valid` present before, gone after.
		//              slang: 0 errors. QuestaSim: NOT VERIFIED.
		// -----------------------------------------------------------------
		if(substate==5'd9 || substate==5'd18) begin out = data; validnext = 1'b1; end
		else
		begin


			if (substate == recoverySpeedeieos) begin
				for(i=0;i<=504;i=i+8)
				begin	
				if(substate == recoverySpeedeieos&&syncHeader == {8{4'hA}}&&data[i+:8]==gen3EIEOSsymb1&&!found)
				begin
				found = 1'b1;
				if((substate !=recoverySpeed && capacity+i>= 128<<numberOfShifts)
					||(substate==recoverySpeed&&gen<3'd3&&capacity+i >= 32<<numberOfShifts))
				begin
				validnext = 1'b1;
				out = orderedSets|(data)<<capacity;
				end
				orderedSetsnext = data>>i;
				capacitynext = width-i;
				end

				end
				
			end
			else 
			begin
				for(i=504;i>=0;i=i-8)
				begin	
				if((data[i+:8]==COM||data[i+:8]==gen3TS1||data[i+:8]==gen3TS2||data[i+:8]==gen3SKIP||
					data[i+:8]==gen3EIOS) && !found)
				begin
				found = 1'b1;
				if((substate !=recoverySpeed && capacity+i-((numberOfDetectedLanes-1)<<3) >= 128<<numberOfShifts)
					||(substate==recoverySpeed&&gen<3'd3&&capacity+i-((numberOfDetectedLanes-1)<<3) >= 32<<numberOfShifts))
				begin
				validnext = 1'b1;
				out = orderedSets|(data)<<capacity;
				end
				orderedSetsnext = data>>i-((numberOfDetectedLanes-1)<<3);
				capacitynext = width-i+((numberOfDetectedLanes-1)<<3);
				end

				end
			end
			
			if(!found)
			begin
				orderedSetsnext = orderedSets|((2048'b0|data) << capacity);
				capacitynext = capacity + width;
				if((substate==recoverySpeed&&gen<3'd3&&capacity>= (32<<numberOfShifts))
				||(substate !=recoverySpeed && capacity>= (128<<numberOfShifts)))
				begin
				validnext = 1'b1;
				out = orderedSets;
				capacitynext=12'd0;
				end
			end
		end
end
end

always@(*)
begin
// ---------------------------------------------------------------------
// BUGFIX-051  (osDecoder.v - this case had no default, so it inferred a
//              latch and held a stale value)
// `numberOfDetectedLanes` is 5 bits, so 0 and 3,5,6,7,...,15,17..31 are all
// reachable - notably 0 before lane detection completes. With no default the
// synthesizer infers a latch and simulation holds whatever value the signal
// last had, which then feeds `128<<numberOfShifts` in the de-interleave loop
// and the `<<numberOfShifts` scaling of `width` below. A stale numberOfShifts
// of 5, 6 or 7 makes that bound 4096/8192/16384, i.e. it reads past the end of
// the 2048-bit `out`.
// Default chosen as 3'd0 (the 1-lane case): it is the smallest bound, so it is
// the fail-safe direction, and it cannot alter behaviour for any lane count
// this case already handles.
// ---------------------------------------------------------------------
case(numberOfDetectedLanes)
5'd1:numberOfShifts = 3'd0;
5'd2:numberOfShifts = 3'd1;
5'd4:numberOfShifts = 3'd2;
5'd8:numberOfShifts = 3'd3;
5'd16:numberOfShifts= 3'd4;
default:numberOfShifts = 3'd0;
endcase
end


always@(*)
begin
// BUGFIX-051  (osDecoder.v - no default => inferred latch on `width`)
// `gen` is 3 bits, so 3'b000, 3'b110 and 3'b111 are reachable. Same class and
// same fix as the numberOfDetectedLanes case above. Default takes the Gen1
// width, matching 3'b001, so no handled generation changes behaviour.
case (gen)
3'b001 : width = GEN1_PIPEWIDTH<<(numberOfShifts);
3'b010 : width = GEN2_PIPEWIDTH<<(numberOfShifts);
3'b011 : width = GEN3_PIPEWIDTH<<(numberOfShifts);
3'b100 : width = GEN4_PIPEWIDTH<<(numberOfShifts);
3'b101 : width = GEN5_PIPEWIDTH<<(numberOfShifts);
default : width = GEN1_PIPEWIDTH<<(numberOfShifts);
endcase
end

// ---------------------------------------------------------------------
// BUGFIX-049  (osDecoder.v - incomplete sensitivity list)
// This block was declared `always@(out)`, but it also READS numberOfShifts,
// numberOfDetectedLanes, lane_iter and index_iter. Simulation therefore only
// re-evaluated it when `out` changed: if the detected lane count changed while
// `out` happened to hold its value, `outOs` kept a stale de-interleaving.
// Synthesis ignores hand-written sensitivity lists entirely and always treats
// the block as fully combinational, so SIMULATION AND SYNTHESIS DISAGREED -
// the most dangerous class of RTL bug, because the design can simulate clean
// and still misbehave in silicon. `always@(*)` makes the list complete and the
// two views consistent. Safe to do only because BUGFIX-050 below removes the
// combinational feedback that would otherwise make `@(*)` self-triggering.
// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
// BUGFIX-050  (osDecoder.v - lane_iter / index_iter were uninitialized loop
//              accumulators, and were driven from two processes)
// Root cause : both are read AND written inside the loop below, but neither was
//              assigned at block entry, so each evaluation continued from the
//              values the previous evaluation left behind - combinational
//              feedback through a block that is meant to be a pure function of
//              its inputs. On top of that the clocked reset block also drove
//              them (removed there under the same ID), which is a
//              multiple-driver conflict between a clocked and a combinational
//              process.
//              It only ever appeared to work by coincidence: the trip count is
//              always 16*numberOfDetectedLanes, so after a full evaluation
//              lane_iter wrapped back to 0 and index_iter reached 128 and
//              wrapped to 0 in its 7 bits. That coincidence breaks for any lane
//              count outside {1,2,4,8,16} - exactly the counts BUGFIX-051 now
//              defaults - after which the iterators never return to zero and
//              every subsequent de-interleave is written to the wrong lanes.
// Fix        : assign both at block entry. They become ordinary loop
//              temporaries with no feedback, which is what makes the block
//              synthesizable and what makes BUGFIX-049's `@(*)` safe.
// ---------------------------------------------------------------------
// ---------------------------------------------------------------------
// BUGFIX-052  (osDecoder.v - `outOs` was only partially assigned, inferring a
//              2048-bit latch)
// The loop writes 128<<numberOfShifts bits of the 2048-bit `outOs`, so for any
// lane count below 16 the bits belonging to the unused lanes were never written
// and held their previous value - a latch on a 2048-bit output, and stale
// ordered-set data presented on lanes that are not part of the link. Cleared at
// entry so the block is a pure combinational function and unused lane regions
// read as a defined 0.
// ---------------------------------------------------------------------
always@(*)
begin
lane_iter = 4'd0;
index_iter = 7'd0;
outOs = 2048'b0;

	// -----------------------------------------------------------------
	// BUGFIX-048  (osDecoder.v - non-constant procedural for-loop bound
	//              replaced by a constant bound plus a guard that keeps
	//              the original data-dependent trip count)
	//
	// Root cause : the loop was written
	//                  for (j = 0; j < 128<<numberOfShifts; j = j+8)
	//              `numberOfShifts` is a `reg` driven by the combinational
	//              case on `numberOfDetectedLanes` above, so the bound was a
	//              RUNTIME value. Hardware can only be built from such a loop
	//              by unrolling it, which needs a constant trip count. yosys
	//              therefore refused to even read the file:
	//                  osDecoder.v:181: ERROR: 2nd expression of procedural
	//                                    for-loop is not constant!
	//              Any commercial synthesis tool rejects it the same way.
	//              Since RX instantiates osDecoder (rtl/Modules
	//              Integration.v:107) this blocked synthesis of the ENTIRE
	//              closure, not just this leaf.
	//
	// Fix        : loop to the constant maximum and run the body only while
	//              the original bound holds:
	//                  lanes            1    2    4    8    16
	//                  numberOfShifts   0    1    2    3     4
	//                  128<<ns        128  256  512 1024  2048
	//                  iterations      16   32   64  128   256   (= bound/8)
	//              The largest is 2048, so iterating j = 0,8,...,2040 and
	//              gating on `j < (128<<numberOfShifts)` executes EXACTLY the
	//              same iterations, in the same order, with the same values.
	//              The body - including the lane_iter/index_iter stepping - is
	//              byte-for-byte unchanged, only indented one level.
	//
	// Side benefit : `numberOfShifts` is 3 bits wide and, before BUGFIX-051
	//              gave its case a default, could hold a latched stale 5/6/7,
	//              making the old bound 4096/8192/16384 and reading past the
	//              end of the 2048-bit `out`. The constant bound makes that
	//              out-of-range read impossible.
	//
	// Expected   : identical outOs for every legal lane count.
	// Verification: the line-181 read ERROR is gone - see docs/RTL_CHANGELOG.md
	//              section 5.1 for what still does NOT elaborate, and why this
	//              fix alone is necessary but not sufficient. slang: 0 errors.
	//              yosys and QuestaSim on this module: NOT VERIFIED / DID NOT
	//              COMPLETE.
	// -----------------------------------------------------------------
	for(j = 0;j<OSD_OUT_BITS;j=j+8)
	begin
	if(j < (128<<numberOfShifts))
	begin
	outOs[(lanesOffsets[11*lane_iter +: 11]+index_iter)+:8] = out[j+:8];
	if(lane_iter==numberOfDetectedLanes-1)
	begin
	lane_iter = 4'd0;
	index_iter = index_iter + 8; 
	end
	else lane_iter = lane_iter + 1'b1;
	end
	end
	
end
endmodule








module osDecoderTB;
reg clk;
reg reset;
reg [4:0]numberOfDetectedLanes;
reg [511:0]data;
reg validFromLMC;
reg linkUp;
wire valid;
wire [2047:0]outOs;
osDecoder os(
clk,
3'b001,
reset,
numberOfDetectedLanes,
data,
validFromLMC,
linkUp,
valid,
outOs);

initial
begin
clk = 0;
reset = 0;
validFromLMC = 1'b1;
numberOfDetectedLanes = 5'd2;
#8
reset = 1;
#10
data = 512'hAABBAABBBCBC00000000000000000000;
#10
data = 512'hAABBAABBAABBAABBAABBAABBAABBAABB;
#10
data = 512'h000000000000AABBAABBAABBAABBAABB;
#10
data = 512'd0;
#10
validFromLMC=1'b0;
end
always #5 clk = ~clk;
endmodule