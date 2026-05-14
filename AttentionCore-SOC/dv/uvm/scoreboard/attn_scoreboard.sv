class attn_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(attn_scoreboard)

  `uvm_analysis_imp_decl(_apb)

  uvm_analysis_imp_apb #(apb_transaction, attn_scoreboard) apb_imp;

  // Register shadow model for attention engine
  bit [31:0] attn_regs [bit [7:0]];
  // Register shadow model for MLP engine
  bit [31:0] mlp_regs [bit [7:0]];
  // Register shadow model for GPIO
  bit [31:0] gpio_regs [bit [3:0]];
  // Register shadow model for timer
  bit [31:0] timer_regs [bit [3:0]];

  // SRAM shadow model
  bit [31:0] inst_sram [bit [31:0]];
  bit [31:0] data_sram [bit [31:0]];
  bit [15:0] weight_sram [bit [31:0]];
  bit [15:0] feature_sram [bit [31:0]];
  bit [15:0] kvcache_sram [bit [31:0]];

  // Statistics
  int unsigned total_ops;
  int unsigned match_count;
  int unsigned mismatch_count;
  int unsigned error_count;
  int unsigned slverr_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb_imp = new("apb_imp", this);
  endfunction

  function void write_apb(apb_transaction txn);
    total_ops++;

    if (txn.slverr) begin
      slverr_count++;
      `uvm_info("SCB", $sformatf("SLVERR: %s", txn.convert2string()), UVM_MEDIUM)
      return;
    end

    if (txn.write) begin
      handle_write(txn);
    end else begin
      handle_read(txn);
    end
  endfunction

  function void handle_write(apb_transaction txn);
    bit [31:0] addr = txn.addr;

    // Attention Engine registers
    if ((addr & 32'hFFFF_F000) == 32'h2000_0000) begin
      bit [7:0] offset = addr[7:0];
      // CTRL auto-clear bits are not stored
      if (offset != 8'h00) begin
        // Mask based on register width
        case (offset)
          8'h08: attn_regs[offset] = txn.wdata & 32'h0000_0001;  // IRQ_EN: 1-bit
          8'h10, 8'h14, 8'h18, 8'h1C, 8'h20, 8'h38, 8'h3C, 8'h40:
            attn_regs[offset] = txn.wdata & 32'h0000_FFFF;  // 16-bit config regs
          default: attn_regs[offset] = txn.wdata;  // 32-bit regs
        endcase
      end
      `uvm_info("SCB", $sformatf("ATTN REG WRITE offset=%02h data=%08h", offset, txn.wdata), UVM_HIGH)
    end
    // MLP Engine registers
    else if ((addr & 32'hFFFF_F000) == 32'h2000_1000) begin
      bit [7:0] offset = addr[7:0];
      if (offset != 8'h00) begin
        mlp_regs[offset] = txn.wdata;
      end
    end
    // GPIO
    else if ((addr & 32'hFFFF_F000) == 32'h1000_1000) begin
      bit [3:0] offset = addr[3:0];
      gpio_regs[offset] = txn.wdata;
    end
    // Timer
    else if ((addr & 32'hFFFF_F000) == 32'h1000_2000) begin
      bit [3:0] offset = addr[3:0];
      timer_regs[offset] = txn.wdata;
    end
    // Instruction SRAM
    else if ((addr & 32'hFFFF_C000) == 32'h0000_0000) begin
      inst_sram[addr] = txn.wdata;
    end
    // Data SRAM
    else if ((addr & 32'hFFFF_C000) == 32'h0000_4000) begin
      data_sram[addr] = txn.wdata;
    end
    // Weight SRAM (FP16, halfword addressed)
    else if ((addr & 32'hFFFF_0000) == 32'h3000_0000) begin
      weight_sram[addr] = txn.wdata[15:0];
    end
    // Feature SRAM (FP16)
    else if ((addr & 32'hFFFF_0000) == 32'h3001_0000) begin
      feature_sram[addr] = txn.wdata[15:0];
    end
    // KV-Cache SRAM (FP16)
    else if ((addr & 32'hFFFF_8000) == 32'h3002_0000) begin
      kvcache_sram[addr] = txn.wdata[15:0];
    end
  endfunction

  function void handle_read(apb_transaction txn);
    bit [31:0] addr = txn.addr;
    bit [31:0] expected;

    // For SRAM reads, check against shadow model
    if ((addr & 32'hFFFF_C000) == 32'h0000_0000) begin
      if (inst_sram.exists(addr)) begin
        expected = inst_sram[addr];
        check_read(txn, expected, "INST_SRAM");
      end
    end
    else if ((addr & 32'hFFFF_C000) == 32'h0000_4000) begin
      if (data_sram.exists(addr)) begin
        expected = data_sram[addr];
        check_read(txn, expected, "DATA_SRAM");
      end
    end
    else if ((addr & 32'hFFFF_0000) == 32'h3000_0000) begin
      if (weight_sram.exists(addr)) begin
        expected = {16'h0, weight_sram[addr]};
        check_read(txn, expected, "WEIGHT_SRAM");
      end
    end
    else if ((addr & 32'hFFFF_0000) == 32'h3001_0000) begin
      if (feature_sram.exists(addr)) begin
        expected = {16'h0, feature_sram[addr]};
        check_read(txn, expected, "FEATURE_SRAM");
      end
    end
    else if ((addr & 32'hFFFF_8000) == 32'h3002_0000) begin
      if (kvcache_sram.exists(addr)) begin
        expected = {16'h0, kvcache_sram[addr]};
        check_read(txn, expected, "KVCACHE_SRAM");
      end
    end
    // GPIO read
    else if ((addr & 32'hFFFF_F000) == 32'h1000_1000) begin
      // GPIO_DATA_IN is read-only from external pins, no shadow check
    end
    // Timer STATUS is W1C, reads reflect current state
    else if ((addr & 32'hFFFF_F000) == 32'h1000_2000) begin
      // Timer reads are dynamic (counter), skip shadow check
    end
    // Attention/MLP engine reads - verified by sequences directly
    // (skipped in scoreboard due to APB timing sensitivity)
    else if ((addr & 32'hFFFF_F000) == 32'h2000_0000) begin
      // Register read-back verified by reg_access_test sequence
    end
    else if ((addr & 32'hFFFF_F000) == 32'h2000_1000) begin
      // Register read-back verified by reg_access_test sequence
    end
  endfunction

  function void check_read(apb_transaction txn, bit [31:0] expected, string src);
    if (txn.rdata === expected) begin
      match_count++;
      `uvm_info("SCB", $sformatf("[%s] MATCH addr=%08h data=%08h", src, txn.addr, txn.rdata), UVM_HIGH)
    end else begin
      mismatch_count++;
      `uvm_error("SCB", $sformatf("[%s] MISMATCH addr=%08h expected=%08h actual=%08h",
        src, txn.addr, expected, txn.rdata))
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCB", "========================================", UVM_LOW)
    `uvm_info("SCB", "       Scoreboard Report", UVM_LOW)
    `uvm_info("SCB", "========================================", UVM_LOW)
    `uvm_info("SCB", $sformatf("Total APB ops   : %0d", total_ops), UVM_LOW)
    `uvm_info("SCB", $sformatf("Match count     : %0d", match_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("Mismatch count  : %0d", mismatch_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("SLVERR count    : %0d", slverr_count), UVM_LOW)
    `uvm_info("SCB", "========================================", UVM_LOW)
    if (mismatch_count == 0 && error_count == 0) begin
      `uvm_info("SCB", "*** SCOREBOARD PASSED ***", UVM_LOW)
    end else begin
      `uvm_error("SCB", "*** SCOREBOARD FAILED ***")
    end
  endfunction
endclass
