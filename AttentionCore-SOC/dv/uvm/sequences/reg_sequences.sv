// Attention Engine register access sequence
class attn_reg_write_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(attn_reg_write_seq)

  rand bit [7:0]  reg_offset;
  rand bit [31:0] reg_data;

  function new(string name = "attn_reg_write_seq");
    super.new(name);
  endfunction

  task body();
    apb_write_seq wr;
    wr = apb_write_seq::type_id::create("wr");
    wr.addr = 32'h2000_0000 + {24'h0, reg_offset};
    wr.data = reg_data;
    wr.start(m_sequencer, this);
  endtask
endclass

class attn_reg_read_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(attn_reg_read_seq)

  rand bit [7:0] reg_offset;
  bit [31:0] rdata;

  function new(string name = "attn_reg_read_seq");
    super.new(name);
  endfunction

  task body();
    apb_read_seq rd;
    rd = apb_read_seq::type_id::create("rd");
    rd.addr = 32'h2000_0000 + {24'h0, reg_offset};
    rd.start(m_sequencer, this);
    rdata = rd.rdata;
  endtask
endclass

// Full config register sweep sequence
// Writes values that match each register's actual width
class reg_sweep_seq extends uvm_sequence #(apb_transaction);
  `uvm_object_utils(reg_sweep_seq)

  function new(string name = "reg_sweep_seq");
    super.new(name);
  endfunction

  task body();
    // Test each register with width-appropriate values
    test_reg(8'h08, 32'h0000_0001, 32'h0000_0001, "IRQ_EN");         // 1-bit
    test_reg(8'h10, 32'h0000_000A, 32'h0000_FFFF, "CFG_SEQ_LEN");    // 16-bit
    test_reg(8'h14, 32'h0000_0020, 32'h0000_FFFF, "CFG_D_MODEL");    // 16-bit
    test_reg(8'h18, 32'h0000_0004, 32'h0000_FFFF, "CFG_N_HEAD");     // 16-bit
    test_reg(8'h1C, 32'h0000_0080, 32'h0000_FFFF, "CFG_D_FF");       // 16-bit
    test_reg(8'h20, 32'h0000_0004, 32'h0000_FFFF, "CFG_NUM_LAYERS"); // 16-bit
    test_reg(8'h2C, 32'h3000_1000, 32'hFFFF_FFFF, "WEIGHT_BASE");    // 32-bit
    test_reg(8'h30, 32'h3001_2000, 32'hFFFF_FFFF, "FEATURE_BASE");   // 32-bit
    test_reg(8'h34, 32'h3002_1000, 32'hFFFF_FFFF, "KVCACHE_BASE");   // 32-bit
    test_reg(8'h38, 32'h0000_0012, 32'h0000_FFFF, "LAYER_CFG");      // 16-bit
    test_reg(8'h3C, 32'h0000_0404, 32'h0000_FFFF, "TILE_CFG");       // 16-bit
    test_reg(8'h40, 32'h0000_3C00, 32'h0000_FFFF, "SCALE_FACTOR");   // 16-bit
  endtask

  task test_reg(bit [7:0] offset, bit [31:0] test_data, bit [31:0] mask, string name);
    attn_reg_write_seq wr;
    attn_reg_read_seq rd;
    bit [31:0] expected;

    wr = attn_reg_write_seq::type_id::create($sformatf("wr_%s", name));
    wr.reg_offset = offset;
    wr.reg_data = test_data;
    wr.start(m_sequencer, this);

    rd = attn_reg_read_seq::type_id::create($sformatf("rd_%s", name));
    rd.reg_offset = offset;
    rd.start(m_sequencer, this);

    expected = test_data & mask;
    if (rd.rdata !== expected) begin
      `uvm_error("REG_SEQ", $sformatf("[%s] MISMATCH offset=%02h: expected=%08h actual=%08h",
        name, offset, expected, rd.rdata))
    end else begin
      `uvm_info("REG_SEQ", $sformatf("[%s] MATCH offset=%02h: data=%08h", name, offset, rd.rdata), UVM_MEDIUM)
    end
  endtask
endclass
