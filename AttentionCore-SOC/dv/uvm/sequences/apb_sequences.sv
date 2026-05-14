class apb_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_seq)

  rand bit [31:0] addr;
  rand bit [31:0] data;

  function new(string name = "apb_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_transaction txn;
    txn = apb_transaction::type_id::create("txn");
    start_item(txn);
    txn.addr = addr;
    txn.wdata = data;
    txn.write = 1'b1;
    txn.strb = 4'hF;
    finish_item(txn);
  endtask
endclass

class apb_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_read_seq)

  rand bit [31:0] addr;
  bit [31:0] rdata;

  function new(string name = "apb_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_transaction txn;
    txn = apb_transaction::type_id::create("txn");
    start_item(txn);
    txn.addr = addr;
    txn.write = 1'b0;
    finish_item(txn);
    rdata = txn.rdata;
  endtask
endclass

class apb_write_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(apb_write_read_seq)

  rand bit [31:0] addr;
  rand bit [31:0] data;
  bit [31:0] rdata;

  function new(string name = "apb_write_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_write_seq wr;
    apb_read_seq rd;

    wr = apb_write_seq::type_id::create("wr");
    wr.addr = addr;
    wr.data = data;
    wr.start(m_sequencer, this);

    rd = apb_read_seq::type_id::create("rd");
    rd.addr = addr;
    rd.start(m_sequencer, this);
    rdata = rd.rdata;
  endtask
endclass
