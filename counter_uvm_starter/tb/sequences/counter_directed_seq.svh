// The ONLY sequence: reset -> hold -> UP x12 -> DOWN x6 -> hold x2.
class counter_directed_seq extends uvm_sequence #(counter_item);
  `uvm_object_utils(counter_directed_seq)
  function new(string name = "counter_directed_seq");
    super.new(name);
  endfunction

  task send_cycle(bit reset_n, bit count_enable, bit direction);
    counter_item item;
    item = counter_item::type_id::create("item");
    start_item(item);
    item.rst_n = reset_n;
    item.enable = count_enable;
    item.up = direction;
    finish_item(item);
  endtask

  task body();
    repeat (2) send_cycle(0, 0, 1); // Reset count to zero.
    send_cycle(1, 0, 1);            // Release reset, hold zero.
    repeat (12) send_cycle(1, 1, 1); // 1, 2, ... 12.
    repeat (6) send_cycle(1, 1, 0);  // 11, 10, ... 6.
    repeat (2) send_cycle(1, 0, 0);  // Hold 6.
  endtask
endclass
