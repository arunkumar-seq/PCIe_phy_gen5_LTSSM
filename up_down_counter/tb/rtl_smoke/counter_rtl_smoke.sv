`timescale 1ns/1ps
// Portable RTL-only test. This supplements, not replaces, the UVM regression.
module counter_rtl_smoke;
  parameter integer WIDTH=8;
  reg clk=0;
  always #5 clk=~clk;
  reg rst_n=1, clear=0, load=0, enable=0, up=1;
  reg [WIDTH-1:0] load_value=0;
  wire [WIDTH-1:0] count;
  reg [WIDTH-1:0] expected=0;
  reg [WIDTH-1:0] max_count={WIDTH{1'b1}};
  integer checked=0;
  integer i;
  up_down_counter #(.WIDTH(WIDTH)) dut(.*);

  task step(input reg r, c, l, e, u, input reg [WIDTH-1:0] v);
    begin
      @(negedge clk);
      rst_n=r; clear=c; load=l; enable=e; up=u; load_value=v;
      if (!r || c) expected=0;
      else if (l) expected=v;
      else if (e && u) expected=expected+1'b1;
      else if (e) expected=expected-1'b1;
      @(posedge clk); #1;
      checked=checked+1;
      if (count !== expected)
        $fatal(1,"sample %0d: expected %h got %h",checked,expected,count);
    end
  endtask

  initial begin
    if (WIDTH < 1) $fatal(1,"WIDTH must be positive");
    step(0,0,0,0,1,0);
    step(1,0,1,1,1,max_count);
    step(1,0,0,1,1,0); // overflow
    step(1,0,0,1,0,0); // underflow
    step(1,0,0,0,0,0); // hold
    step(1,1,1,1,1,max_count); // clear wins over load and enable
    step(1,0,1,0,0,max_count); // load works with enable low
    // Assert reset BETWEEN active clock edges and check before the next edge.
    #1; rst_n=0; #1;
    if (count !== 0) $fatal(1,"Asynchronous reset failed before clock edge");
    expected=0;
    step(0,1,1,1,0,max_count); // reset wins over all controls
    step(1,0,0,0,1,0);
    for (i=0;i<2000;i=i+1)
      step(($urandom_range(0,49)!=0), ($urandom_range(0,19)==0),
           ($urandom_range(0,9)==0), $urandom_range(0,1),
           $urandom_range(0,1), $urandom);
    $display("RTL SMOKE PASS: WIDTH=%0d, %0d checked cycles", WIDTH, checked);
    $finish;
  end
  initial begin #1ms; $fatal(1,"Smoke watchdog expired"); end
endmodule
