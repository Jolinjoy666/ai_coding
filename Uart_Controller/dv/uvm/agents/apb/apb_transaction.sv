class apb_transaction extends uvm_sequence_item;
  `uvm_object_utils(apb_transaction)

  rand bit [7:0]  addr;
  rand bit [31:0] wdata;
  rand bit [3:0]  strb;
  rand bit        write;
  bit [31:0]      rdata;
  bit             slverr;
  bit             ready;

  function new(string name = "apb_transaction");
    super.new(name);
  endfunction

  function string convert2string();
    if (write)
      return $sformatf("WRITE addr=%02h wdata=%08h strb=%04b", addr, wdata, strb);
    else
      return $sformatf("READ addr=%02h rdata=%08h", addr, rdata);
  endfunction

  function void do_copy(uvm_object rhs);
    apb_transaction rhs_;
    super.do_copy(rhs);
    $cast(rhs_, rhs);
    addr = rhs_.addr;
    wdata = rhs_.wdata;
    strb = rhs_.strb;
    write = rhs_.write;
    rdata = rhs_.rdata;
    slverr = rhs_.slverr;
    ready = rhs_.ready;
  endfunction

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    apb_transaction rhs_;
    if (!$cast(rhs_, rhs)) return 0;
    if (write)
      return (addr == rhs_.addr) && (wdata == rhs_.wdata);
    else
      return (addr == rhs_.addr) && (rdata == rhs_.rdata);
  endfunction
endclass
