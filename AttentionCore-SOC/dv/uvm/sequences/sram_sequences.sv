// SRAM write sequence: write a pattern to a range of SRAM addresses
class sram_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(sram_write_seq)

  rand bit [31:0] base_addr;
  rand int unsigned num_words;
  rand bit [31:0] pattern_base;

  constraint c_reasonable {
    num_words inside {[1:16]};
    base_addr[1:0] == 2'b00;
  }

  function new(string name = "sram_write_seq");
    super.new(name);
  endfunction

  task body();
    for (int i = 0; i < num_words; i++) begin
      apb_write_seq wr;
      wr = apb_write_seq::type_id::create($sformatf("wr_%0d", i));
      wr.addr = base_addr + (i * 4);
      wr.data = pattern_base + i;
      wr.start(m_sequencer, this);
    end
  endtask
endclass

// SRAM read sequence: read and return data from a range of SRAM addresses
class sram_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(sram_read_seq)

  rand bit [31:0] base_addr;
  rand int unsigned num_words;
  bit [31:0] rdata_q[$];

  constraint c_reasonable {
    num_words inside {[1:16]};
    base_addr[1:0] == 2'b00;
  }

  function new(string name = "sram_read_seq");
    super.new(name);
  endfunction

  task body();
    rdata_q.delete();
    for (int i = 0; i < num_words; i++) begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create($sformatf("rd_%0d", i));
      rd.addr = base_addr + (i * 4);
      rd.start(m_sequencer, this);
      rdata_q.push_back(rd.rdata);
    end
  endtask
endclass

// SRAM write-then-read verify sequence
class sram_write_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(sram_write_read_seq)

  rand bit [31:0] base_addr;
  rand int unsigned num_words;
  rand bit [31:0] pattern_base;

  constraint c_reasonable {
    num_words inside {[1:16]};
    base_addr[1:0] == 2'b00;
  }

  function new(string name = "sram_write_read_seq");
    super.new(name);
  endfunction

  task body();
    sram_write_seq wr;
    sram_read_seq rd;

    wr = sram_write_seq::type_id::create("wr");
    wr.base_addr = base_addr;
    wr.num_words = num_words;
    wr.pattern_base = pattern_base;
    wr.start(m_sequencer, this);

    rd = sram_read_seq::type_id::create("rd");
    rd.base_addr = base_addr;
    rd.num_words = num_words;
    rd.start(m_sequencer, this);

    // Verify
    for (int i = 0; i < num_words; i++) begin
      bit [31:0] expected = pattern_base + i;
      if (rd.rdata_q[i] !== expected) begin
        `uvm_error("SRAM_SEQ", $sformatf("MISMATCH at addr=%08h: expected=%08h actual=%08h",
          base_addr + (i * 4), expected, rd.rdata_q[i]))
      end else begin
        `uvm_info("SRAM_SEQ", $sformatf("MATCH at addr=%08h: data=%08h",
          base_addr + (i * 4), rd.rdata_q[i]), UVM_HIGH)
      end
    end
  endtask
endclass
