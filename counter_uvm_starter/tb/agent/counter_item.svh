// One item describes one clock cycle. No rand fields or constraints needed.
class counter_item extends uvm_sequence_item;
  `uvm_object_utils(counter_item)
  bit rst_n;
  bit enable;
  bit up;
  logic [7:0] count; // Response filled by monitor, not sequence.

  function new(string name = "counter_item");
    super.new(name);
  endfunction
endclass
