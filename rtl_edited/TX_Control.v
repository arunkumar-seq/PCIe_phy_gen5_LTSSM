module TX_CONTROL#
(
parameter MAXPIPEWIDTH =32,
parameter LANESNUMBER = 8,
parameter GEN1_PIPEWIDTH = 8,
parameter GEN2_PIPEWIDTH = 16,	
parameter GEN3_PIPEWIDTH = 32,	
parameter GEN4_PIPEWIDTH = 8,
parameter GEN5_PIPEWIDTH = 8 	
)
(reset_n,data_in,wr,wr_valid,pclk,STP_IN,SDP_IN,END_IN,Gen,DetectedLanes,Hold,full,DataOut,ValidOut,DKOut);

input reset_n;
input wr;
input pclk;
input [2:0] Gen;
input [LANESNUMBER-1:0]DetectedLanes;
input Hold;
input[63:0] wr_valid;
input[63:0] STP_IN;
input[63:0] SDP_IN;
input[63:0] END_IN;
input[511:0] data_in;
output[MAXPIPEWIDTH*LANESNUMBER-1:0]DataOut;
output [MAXPIPEWIDTH/8*LANESNUMBER-1:0]ValidOut;
output [MAXPIPEWIDTH/8*LANESNUMBER-1:0]DKOut;
output full;
wire empty;
wire[63:0] rd_valid;
wire[63:0] STP_OUT;
wire[63:0] SDP_OUT;
wire[63:0] END_OUT;
wire[511:0] data_out;
wire ReadEn;
// BUGFIX-005:
// Original issue: unknown module 'FIFO' - elaboration error. No module named
// 'FIFO' exists anywhere in the repository; the repository's FIFO is FIFOV2
// (rtl/FIFOV2.v), which is what the current TX control path (Tx_CTRL) uses.
// Root cause: this legacy Gen1/2 control path was written against an earlier
// FIFO interface; when FIFOV2 added the length_in/length_out ports this
// instantiation was never updated. (Note: TOP_MODULE instantiates Tx_CTRL,
// not TX_CONTROL, so this module is the legacy predecessor kept for
// compatibility - its behavior is unchanged apart from binding a FIFO that
// actually exists.)
// Fix: bind FIFOV2. The two length ports introduced by FIFOV2 are left
// unconnected here because this legacy path has no LENGTH_COUNTER stage
// (Tx_CTRL adds that stage); unconnected outputs and a tied-off input
// preserve the original data-path behavior.
// Verified by: slang elaboration of rtl/*.v (unknown-module error gone).
FIFOV2 m1 (.reset_n(reset_n),.data_in(data_in),.wr(wr),.rd(ReadEn),.wr_valid(wr_valid),.pclk(pclk),.STP_IN(STP_IN),.SDP_IN(SDP_IN),.END_IN(END_IN),.length_in(80'b0),.length_out(),.empty(empty),.full(full),.data_out(data_out),.STP_OUT(STP_OUT),.SDP_OUT(SDP_OUT),.END_OUT(END_OUT),.rd_valid(rd_valid));
InsertTokenBlock #(.MAXPIPEWIDTH(MAXPIPEWIDTH),.LANESNUMBER(LANESNUMBER),.GEN1_PIPEWIDTH(GEN1_PIPEWIDTH),
.GEN2_PIPEWIDTH(GEN1_PIPEWIDTH),.GEN3_PIPEWIDTH(GEN3_PIPEWIDTH),.GEN4_PIPEWIDTH(GEN4_PIPEWIDTH),.GEN5_PIPEWIDTH(GEN5_PIPEWIDTH)) 
m2 (pclk,reset_n,data_out,rd_valid,STP_OUT,SDP_OUT,END_OUT,Gen,DetectedLanes,Hold,empty,ReadEn,DataOut,ValidOut,DKOut);
endmodule

