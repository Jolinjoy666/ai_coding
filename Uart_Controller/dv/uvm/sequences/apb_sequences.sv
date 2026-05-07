class apb_read_sequence extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_read_sequence)
  
  rand bit [7:0] addr;
  bit [31:0] rdata;

  function new(string name = "apb_read_sequence");
    super.new(name);
  endfunction

  task body();
    apb_transaction txn;
    txn = apb_transaction::type_id::create("txn");
    txn.addr = addr;
    txn.write = 1'b0;
    start_item(txn);
    finish_item(txn);
    rdata = txn.rdata;
  endtask
endclass

class apb_write_sequence extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_sequence)
  
  rand bit [7:0]  addr;
  rand bit [31:0] wdata;
  rand bit [3:0]  strb;

  function new(string name = "apb_write_sequence");
    super.new(name);
    strb = 4'b0001;
  endfunction

  task body();
    apb_transaction txn;
    txn = apb_transaction::type_id::create("txn");
    txn.addr = addr;
    txn.wdata = wdata;
    txn.strb = strb;
    txn.write = 1'b1;
    start_item(txn);
    finish_item(txn);
  endtask
endclass
