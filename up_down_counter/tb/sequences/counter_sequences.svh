class counter_base_seq extends uvm_sequence #(counter_item);
  `uvm_object_utils(counter_base_seq)
  function new(string name="counter_base_seq"); super.new(name); endfunction
  task drive(bit rst_n=1, bit clear=0, bit load=0, bit enable=0,
             bit up=1, bit [WIDTH-1:0] value='0);
    counter_item t=counter_item::type_id::create("t");
    start_item(t);
    t.rst_n=rst_n; t.clear=clear; t.load=load;
    t.enable=enable; t.up=up; t.load_value=value;
    finish_item(t);
  endtask
  task reset_dut(); repeat (2) drive(.rst_n(0)); drive(); endtask
endclass

class counter_reset_seq extends counter_base_seq;
  `uvm_object_utils(counter_reset_seq)
  function new(string name="counter_reset_seq"); super.new(name); endfunction
  task body();
    reset_dut();
    drive(.load(1), .value(MAX_COUNT));
    drive(.rst_n(0), .clear(1), .load(1), .enable(1), .value(MAX_COUNT));
    drive();
    drive(.load(1), .value(MAX_COUNT));
    drive(.rst_n(0), .load(1), .enable(1), .value(MAX_COUNT));
    drive();
  endtask
endclass

class counter_directed_seq extends counter_base_seq;
  `uvm_object_utils(counter_directed_seq)
  function new(string name="counter_directed_seq"); super.new(name); endfunction
  task body();
    reset_dut();
    repeat (12) drive(.enable(1));
    repeat (6) drive(.enable(1), .up(0));
    repeat (4) drive(.up(0)); // disabled hold in both directions
    repeat (4) drive();
    drive(.load(1), .value(MAX_COUNT >> 1));
    drive(.load(1), .enable(1), .up(0), .value(MAX_COUNT));
    drive(.clear(1), .load(1), .enable(1), .value(MAX_COUNT));
    drive(.clear(1), .enable(1));
    // Immediate reversals.
    repeat (8) begin drive(.enable(1)); drive(.enable(1), .up(0)); end
  endtask
endclass

class counter_wrap_seq extends counter_base_seq;
  `uvm_object_utils(counter_wrap_seq)
  function new(string name="counter_wrap_seq"); super.new(name); endfunction
  task body();
    reset_dut();
    drive(.load(1), .value(MAX_COUNT));
    drive(.enable(1)); // maximum -> zero
    drive(.enable(1), .up(0)); // zero -> maximum
    drive(.enable(1));
    repeat (3) drive(.enable(1), .up(0));
  endtask
endclass

class counter_random_seq extends counter_base_seq;
  `uvm_object_utils(counter_random_seq)
  int unsigned num_items=1000;
  function new(string name="counter_random_seq"); super.new(name); endfunction
  task body();
    counter_item t;
    reset_dut();
    void'($value$plusargs("NUM_ITEMS=%d", num_items));
    repeat (num_items) begin
      t=counter_item::type_id::create("random_t");
      start_item(t);
      if (!t.randomize()) `uvm_fatal("RANDFAIL", "counter_item randomization failed")
      finish_item(t);
    end
  endtask
endclass
