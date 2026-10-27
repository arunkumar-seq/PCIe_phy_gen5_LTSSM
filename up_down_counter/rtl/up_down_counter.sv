`timescale 1ns/1ps
module up_down_counter #(
  parameter int unsigned WIDTH = 8
) (
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 clear,
  input  logic                 load,
  input  logic                 enable,
  input  logic                 up,
  input  logic [WIDTH-1:0]     load_value,
  output logic [WIDTH-1:0]     count
);
  // Priority: asynchronous reset > synchronous clear > load > count > hold.
  // Assignment truncation implements modulo 2**WIDTH arithmetic.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)       count <= '0;
    else if (clear)   count <= '0;
    else if (load)    count <= load_value;
    else if (enable) begin
      if (up) count <= count + 1'b1;
      else    count <= count - 1'b1;
    end
  end
endmodule
