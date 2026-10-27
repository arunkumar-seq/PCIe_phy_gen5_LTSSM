class counter_item extends uvm_sequence_item;
  rand bit rst_n, clear, load, enable, up;
  rand bit [WIDTH-1:0] load_value;
  logic [WIDTH-1:0] count;

  constraint typical_traffic {
    rst_n dist {1 := 98, 0 := 2};
    clear dist {0 := 95, 1 := 5};
    load dist {0 := 85, 1 := 15};
    enable dist {1 := 80, 0 := 20};
    load_value dist {'0 := 10, MAX_COUNT := 10, [1:MAX_COUNT-1] :/ 80};
  }
  `uvm_object_utils_begin(counter_item)
    `uvm_field_int(rst_n, UVM_DEFAULT)
    `uvm_field_int(clear, UVM_DEFAULT)
    `uvm_field_int(load, UVM_DEFAULT)
    `uvm_field_int(enable, UVM_DEFAULT)
    `uvm_field_int(up, UVM_DEFAULT)
    `uvm_field_int(load_value, UVM_DEFAULT)
    `uvm_field_int(count, UVM_DEFAULT)
  `uvm_object_utils_end
  function new(string name = "counter_item"); super.new(name); endfunction
endclass
