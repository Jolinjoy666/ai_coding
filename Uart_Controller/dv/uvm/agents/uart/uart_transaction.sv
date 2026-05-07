class uart_transaction extends uvm_sequence_item;
  `uvm_object_utils(uart_transaction)

  rand bit [7:0] data;
  rand bit       is_start;  // 1 = start bit (low), 0 = data
  rand bit       is_stop;   // 1 = stop bit (high)
  bit            framing_error;

  function new(string name = "uart_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=%02h is_start=%0b is_stop=%0b framing_err=%0b",
                     data, is_start, is_stop, framing_error);
  endfunction

  function void do_copy(uvm_object rhs);
    uart_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    data = rhs_.data;
    is_start = rhs_.is_start;
    is_stop = rhs_.is_stop;
    framing_error = rhs_.framing_error;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    uart_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    return (data == rhs_.data) &&
           (is_start == rhs_.is_start) &&
           (is_stop == rhs_.is_stop);
  endfunction
endclass
