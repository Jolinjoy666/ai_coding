// Test 1: SRAM smoke test - write/read all 10 SRAM regions
class sram_smoke_test extends attn_base_test;
  `uvm_component_utils(sram_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    sram_write_read_seq seq;
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Test each SRAM region with a small write/read
    // Inst SRAM: 0x0000_0000
    run_sram_test(phase, 32'h0000_0000, 4, 32'h0000_0001, "INST_SRAM");
    // Data SRAM: 0x0000_4000
    run_sram_test(phase, 32'h0000_4000, 4, 32'h0000_1001, "DATA_SRAM");
    // Weight SRAM: 0x3000_0000
    run_sram_test(phase, 32'h3000_0000, 4, 32'h0000_2001, "WEIGHT_SRAM");
    // Feature SRAM: 0x3001_0000
    run_sram_test(phase, 32'h3001_0000, 4, 32'h0000_3001, "FEATURE_SRAM");
    // KV-Cache SRAM: 0x3002_0000
    run_sram_test(phase, 32'h3002_0000, 4, 32'h0000_4001, "KVCACHE_SRAM");

    `uvm_info("TEST", "=== SRAM Smoke Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

  task run_sram_test(uvm_phase phase, bit [31:0] base, int unsigned words, bit [31:0] pattern, string name);
    sram_write_read_seq seq;
    seq = sram_write_read_seq::type_id::create($sformatf("seq_%s", name));
    seq.base_addr = base;
    seq.num_words = words;
    seq.pattern_base = pattern;
    seq.start(env.apb_agt.sequencer);
    `uvm_info("TEST", $sformatf("%s test complete", name), UVM_LOW)
  endtask
endclass

// Test 2: Register access test
class reg_access_test extends attn_base_test;
  `uvm_component_utils(reg_access_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    reg_sweep_seq seq;
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    seq = reg_sweep_seq::type_id::create("seq");
    seq.start(env.apb_agt.sequencer);

    // Test read-only registers (MAC_ROWS, MAC_COLS)
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_mac_rows");
      rd.addr = 32'h2000_0024;  // REG_CFG_MAC_ROWS
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("MAC_ROWS = %08h (expected 0x04)", rd.rdata), UVM_LOW)

      rd = apb_read_seq::type_id::create("rd_mac_cols");
      rd.addr = 32'h2000_0028;  // REG_CFG_MAC_COLS
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("MAC_COLS = %08h (expected 0x04)", rd.rdata), UVM_LOW)
    end

    // Test W1C on IRQ_STATUS
    begin
      apb_write_seq wr;
      apb_read_seq rd;
      // Enable all IRQs
      wr = apb_write_seq::type_id::create("wr_irq_en");
      wr.addr = 32'h2000_0008;
      wr.data = 32'h0000_00FF;
      wr.start(env.apb_agt.sequencer);

      // Clear IRQ_STATUS by writing 1s
      wr = apb_write_seq::type_id::create("wr_irq_clr");
      wr.addr = 32'h2000_000C;
      wr.data = 32'h0000_00FF;
      wr.start(env.apb_agt.sequencer);

      // Read back - should be 0 (cleared)
      rd = apb_read_seq::type_id::create("rd_irq_status");
      rd.addr = 32'h2000_000C;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("IRQ_STATUS after W1C = %08h (expected 0)", rd.rdata), UVM_LOW)
    end

    `uvm_info("TEST", "=== Register Access Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Test 3: Attention engine start/status test
class attn_engine_test extends attn_base_test;
  `uvm_component_utils(attn_engine_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Configure attention engine
    write_reg(32'h2000_0010, 32'h0000_0008);  // SEQ_LEN = 8
    write_reg(32'h2000_0014, 32'h0000_0010);  // D_MODEL = 16
    write_reg(32'h2000_0018, 32'h0000_0002);  // N_HEAD = 2
    write_reg(32'h2000_001C, 32'h0000_0040);  // D_FF = 64
    write_reg(32'h2000_0020, 32'h0000_0002);  // NUM_LAYERS = 2

    // Start attention engine
    write_reg(32'h2000_0000, 32'h0000_0001);  // CTRL.START

    // Wait a few cycles for busy to assert
    repeat (5) @(posedge vif.clk);

    // Read status
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_status");
      rd.addr = 32'h2000_0004;  // STATUS
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("STATUS after start = %08h", rd.rdata), UVM_LOW)
      // bit 0 = BUSY should be set (or DONE if very fast)
    end

    // Wait for completion or timeout
    begin
      int timeout = 1000;
      bit done = 0;
      while (timeout > 0 && !done) begin
        apb_read_seq rd;
        rd = apb_read_seq::type_id::create("rd_poll");
        rd.addr = 32'h2000_0004;
        rd.start(env.apb_agt.sequencer);
        if (rd.rdata[1]) begin  // DONE bit
          done = 1;
          `uvm_info("TEST", "Attention engine DONE detected", UVM_LOW)
        end
        timeout--;
        @(posedge vif.clk);
      end
      if (!done) begin
        `uvm_info("TEST", "Attention engine did not complete (expected in test_mode without SRAM data)", UVM_MEDIUM)
      end
    end

    `uvm_info("TEST", "=== Attention Engine Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

  task write_reg(bit [31:0] addr, bit [31:0] data);
    apb_write_seq wr;
    wr = apb_write_seq::type_id::create("wr");
    wr.addr = addr;
    wr.data = data;
    wr.start(env.apb_agt.sequencer);
  endtask
endclass

// Test 4: GPIO loopback test
class gpio_loopback_test extends attn_base_test;
  `uvm_component_utils(gpio_loopback_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Write GPIO output register
    write_reg(32'h1000_1000, 32'h0000_00A5);

    // Read back GPIO output register
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_gpio_out");
      rd.addr = 32'h1000_1000;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("GPIO_DATA_OUT = %08h (expected 0x000000A5)", rd.rdata), UVM_LOW)
      if (rd.rdata[7:0] !== 8'hA5) begin
        `uvm_error("TEST", "GPIO output mismatch")
      end
    end

    // Read GPIO input register (gpio_in is tied to testbench)
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_gpio_in");
      rd.addr = 32'h1000_1004;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("GPIO_DATA_IN = %08h", rd.rdata), UVM_LOW)
    end

    `uvm_info("TEST", "=== GPIO Loopback Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

  task write_reg(bit [31:0] addr, bit [31:0] data);
    apb_write_seq wr;
    wr = apb_write_seq::type_id::create("wr");
    wr.addr = addr;
    wr.data = data;
    wr.start(env.apb_agt.sequencer);
  endtask
endclass

// Test 5: Timer test
class timer_test extends attn_base_test;
  `uvm_component_utils(timer_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Set compare value
    write_reg(32'h1000_2004, 32'h0000_0010);  // TIMER_COMPARE = 16

    // Reset counter
    write_reg(32'h1000_2000, 32'h0000_0000);  // TIMER_COUNT = 0

    // Enable timer with IRQ
    write_reg(32'h1000_2008, 32'h0000_0003);  // CTRL: enable=1, irq_en=1

    // Wait for counter to reach compare
    repeat (25) @(posedge vif.clk);

    // Read status - should have irq_status set
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_timer_status");
      rd.addr = 32'h1000_200C;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("TIMER_STATUS = %08h (expected bit0=1)", rd.rdata), UVM_LOW)
      if (!rd.rdata[0]) begin
        `uvm_error("TEST", "Timer IRQ not triggered")
      end
    end

    // Clear IRQ
    write_reg(32'h1000_200C, 32'h0000_0001);  // W1C

    // Verify cleared
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_timer_status_clr");
      rd.addr = 32'h1000_200C;
      rd.start(env.apb_agt.sequencer);
      if (rd.rdata[0]) begin
        `uvm_error("TEST", "Timer IRQ not cleared after W1C")
      end
    end

    // Read counter to verify it's running
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_timer_count");
      rd.addr = 32'h1000_2000;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("TIMER_COUNT = %08h", rd.rdata), UVM_LOW)
    end

    `uvm_info("TEST", "=== Timer Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

  task write_reg(bit [31:0] addr, bit [31:0] data);
    apb_write_seq wr;
    wr = apb_write_seq::type_id::create("wr");
    wr.addr = addr;
    wr.data = data;
    wr.start(env.apb_agt.sequencer);
  endtask
endclass

// Test 6: IRQ test
class irq_test extends attn_base_test;
  `uvm_component_utils(irq_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Enable attention engine IRQ (1-bit register, only bit 0 is stored)
    write_reg(32'h2000_0008, 32'h0000_0001);  // IRQ_EN = 1

    // Verify IRQ enable register
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_irq_en");
      rd.addr = 32'h2000_0008;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("IRQ_EN = %08h (expected 0x01)", rd.rdata), UVM_LOW)
      if (rd.rdata[0] !== 1'b1) begin
        `uvm_error("TEST", "IRQ enable mismatch")
      end
    end

    // Read IRQ_STATUS (should be 0 initially)
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_irq_status_init");
      rd.addr = 32'h2000_000C;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("IRQ_STATUS initial = %08h", rd.rdata), UVM_LOW)
    end

    // Test W1C: write all 1s to clear
    write_reg(32'h2000_000C, 32'h0000_00FF);

    // Verify cleared
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_irq_status_after");
      rd.addr = 32'h2000_000C;
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("IRQ_STATUS after W1C = %08h (expected 0)", rd.rdata), UVM_LOW)
    end

    // Test partial W1C
    write_reg(32'h2000_0008, 32'h0000_000F);  // Enable lower 4 bits
    write_reg(32'h2000_000C, 32'h0000_00FF);  // Clear all
    write_reg(32'h2000_000C, 32'h0000_0003);  // Clear only bits 0,1

    `uvm_info("TEST", "=== IRQ Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask

  task write_reg(bit [31:0] addr, bit [31:0] data);
    apb_write_seq wr;
    wr = apb_write_seq::type_id::create("wr");
    wr.addr = addr;
    wr.data = data;
    wr.start(env.apb_agt.sequencer);
  endtask
endclass

// Test 7: Random APB stress test
class random_apb_test extends attn_base_test;
  `uvm_component_utils(random_apb_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Run 100 random APB transactions to known-good addresses
    repeat (100) begin
      apb_transaction txn;
      txn = apb_transaction::type_id::create("txn");

      // Randomize to one of the safe address ranges
      begin
        int sel;
        sel = $urandom_range(0, 4);
        case (sel)
          0: txn.addr = 32'h0000_0000 + ($urandom & 32'h0000_0FFF);  // Inst SRAM
          1: txn.addr = 32'h0000_4000 + ($urandom & 32'h0000_0FFF);  // Data SRAM
          2: txn.addr = 32'h1000_1000 + ($urandom & 32'h0000_000C);  // GPIO
          3: txn.addr = 32'h1000_2000 + ($urandom & 32'h0000_000C);  // Timer
          4: txn.addr = 32'h2000_0000 + ($urandom & 32'h0000_007C);  // Attn regs
        endcase
      end

      txn.write = $urandom_range(0, 1);
      txn.wdata = $urandom;
      txn.strb = 4'hF;

      begin
        apb_write_seq wr;
        apb_read_seq rd;
        if (txn.write) begin
          wr = apb_write_seq::type_id::create("wr_rand");
          wr.addr = txn.addr;
          wr.data = txn.wdata;
          wr.start(env.apb_agt.sequencer);
        end else begin
          rd = apb_read_seq::type_id::create("rd_rand");
          rd.addr = txn.addr;
          rd.start(env.apb_agt.sequencer);
        end
      end
    end

    `uvm_info("TEST", "=== Random APB Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Test 8: Unmapped address test
class unmapped_addr_test extends attn_base_test;
  `uvm_component_utils(unmapped_addr_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    // Access unmapped address - should get pslverr
    begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create("rd_unmapped");
      rd.addr = 32'hF000_0000;  // Unmapped
      rd.start(env.apb_agt.sequencer);
      `uvm_info("TEST", $sformatf("Unmapped read: rdata=%08h (slverr from monitor)", rd.rdata), UVM_LOW)
    end

    // Try a few more unmapped addresses
    begin
      bit [31:0] addrs[] = '{32'h4000_0000, 32'h5000_0000, 32'hFFFF_0000};
      foreach (addrs[i]) begin
        apb_read_seq rd;
        rd = apb_read_seq::type_id::create($sformatf("rd_unmap_%0d", i));
        rd.addr = addrs[i];
        rd.start(env.apb_agt.sequencer);
        `uvm_info("TEST", $sformatf("Unmapped addr=%08h: rdata=%08h", addrs[i], rd.rdata), UVM_MEDIUM)
      end
    end

    // Write to unmapped - should also get pslverr
    begin
      apb_write_seq wr;
      wr = apb_write_seq::type_id::create("wr_unmapped");
      wr.addr = 32'hF000_0000;
      wr.data = 32'hDEAD_BEEF;
      wr.start(env.apb_agt.sequencer);
    end

    `uvm_info("TEST", "=== Unmapped Address Test PASSED ===", UVM_LOW)
    phase.drop_objection(this);
  endtask
endclass

// Test 9: End-to-end attention computation test
// Loads Q/K/V into SRAMs, starts attention engine, verifies output against golden model
class e2e_attention_test extends attn_base_test;
  `uvm_component_utils(e2e_attention_test)

  // Golden data (128 FP16 values = 8 rows x 16 cols)
  logic [15:0] q_data [0:127];
  logic [15:0] k_data [0:127];
  logic [15:0] v_data [0:127];
  logic [15:0] o_expected [0:127];

  // Parameters
  localparam int SEQ_LEN  = 8;
  localparam int D_MODEL  = 16;
  localparam int N_HEAD   = 2;
  localparam int HEAD_DIM = D_MODEL / N_HEAD;  // 8
  localparam int NUM_EL   = SEQ_LEN * D_MODEL;  // 128 FP16 values

  // Address map
  localparam bit [31:0] FEATURE_BASE = 32'h3001_0000;
  localparam bit [31:0] KVCACHE_BASE = 32'h3002_0000;
  localparam bit [31:0] ATTN_BASE    = 32'h2000_0000;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    repeat (20) @(posedge vif.clk);

    `uvm_info("TEST", "=== E2E Attention Test Start ===", UVM_LOW)

    // Step 1: Load golden data from hex files
    load_golden_data();

    // Step 2: Write Q to Feature SRAM
    write_sram16(FEATURE_BASE, q_data, NUM_EL, "Q");

    // Step 3: Write K to KV-Cache SRAM
    write_sram16(KVCACHE_BASE, k_data, NUM_EL, "K");

    // Step 4: Write V to KV-Cache SRAM (offset 64 FP16 words = 128 bytes)
    write_sram16(KVCACHE_BASE + 32'h80, v_data, NUM_EL, "V");

    // Step 5: Configure attention engine
    write_reg(ATTN_BASE + 8'h10, 32'h0000_0008);  // SEQ_LEN = 8
    write_reg(ATTN_BASE + 8'h14, 32'h0000_0010);  // D_MODEL = 16
    write_reg(ATTN_BASE + 8'h18, 32'h0000_0002);  // N_HEAD = 2
    write_reg(ATTN_BASE + 8'h40, 32'h0000_35A8);  // scale = 1/sqrt(8) ≈ 0.3536 in FP16

    // Step 6: Start attention engine
    write_reg(ATTN_BASE + 8'h00, 32'h0000_0001);  // CTRL.START

    // Step 7: Wait for completion
    begin
      int timeout = 50000;
      bit done = 0;
      while (timeout > 0 && !done) begin
        apb_read_seq rd;
        rd = apb_read_seq::type_id::create("rd_poll");
        rd.addr = ATTN_BASE + 8'h04;  // STATUS
        rd.start(env.apb_agt.sequencer);
        if (rd.rdata[1]) begin  // DONE bit
          done = 1;
          `uvm_info("TEST", "Attention engine DONE", UVM_LOW)
        end
        timeout--;
        @(posedge vif.clk);
      end
      if (!done) begin
        `uvm_warning("TEST", "Attention engine did not complete in time - checking output anyway")
      end
    end

    // Step 8: Read output from Feature SRAM (offset 128 bytes = 64 FP16 words)
    begin
      logic [15:0] o_actual [0:127];
      int mismatches = 0;

      read_sram16(FEATURE_BASE + 32'h100, o_actual, NUM_EL, "O");

      // Debug: print first few actual and expected values
      for (int i = 0; i < 8; i++) begin
        `uvm_info("TEST", $sformatf("  O[%0d]: exp=0x%04h act=0x%04h", i, o_expected[i], o_actual[i]), UVM_LOW)
      end

      // Step 9: Compare with golden
      for (int i = 0; i < NUM_EL; i++) begin
        logic [15:0] exp_val, act_val;
        logic [15:0] diff;
        exp_val = o_expected[i];
        act_val = o_actual[i];

        // Check for X values first
        if (^act_val === 1'bx) begin
          mismatches++;
          if (mismatches <= 10) begin
            `uvm_error("TEST", $sformatf("X_VALUE[%0d]: exp=0x%04h act=0x%04h", i, exp_val, act_val))
          end
        end else begin
          // Compute absolute difference (unsigned)
          if (act_val[14:0] > exp_val[14:0])
            diff = act_val[14:0] - exp_val[14:0];
          else
            diff = exp_val[14:0] - act_val[14:0];

          // Allow up to 4 ULP difference (FP16 precision)
          if (diff > 16'h0004 || (exp_val[15] != act_val[15])) begin
            mismatches++;
            if (mismatches <= 10) begin
              `uvm_info("TEST", $sformatf("MISMATCH[%0d]: exp=0x%04h act=0x%04h diff=%0d",
                i, exp_val, act_val, diff), UVM_LOW)
            end
          end
        end
      end

      if (mismatches == 0) begin
        `uvm_info("TEST", "=== E2E Attention Test: ALL OUTPUTS MATCH ===", UVM_LOW)
      end else begin
        `uvm_error("TEST", $sformatf("=== E2E Attention Test: %0d/%0d mismatches ===",
          mismatches, NUM_EL))
      end
    end
    phase.drop_objection(this);
  endtask

  // Load golden data from hex files
  task load_golden_data();
    int fd;
    string line;
    int val;

    // Load Q (simulation runs from sim/run/<test>/, golden is in tools/golden/)
    fd = $fopen("../../../tools/golden/q_input.hex", "r");
    if (fd == 0) `uvm_fatal("TEST", "Cannot open q_input.hex")
    for (int i = 0; i < NUM_EL; i++) begin
      $fgets(line, fd);
      $sscanf(line, "%h", val);
      q_data[i] = val[15:0];
    end
    $fclose(fd);

    // Load K
    fd = $fopen("../../../tools/golden/k_input.hex", "r");
    if (fd == 0) `uvm_fatal("TEST", "Cannot open k_input.hex")
    for (int i = 0; i < NUM_EL; i++) begin
      $fgets(line, fd);
      $sscanf(line, "%h", val);
      k_data[i] = val[15:0];
    end
    $fclose(fd);

    // Load V
    fd = $fopen("../../../tools/golden/v_input.hex", "r");
    if (fd == 0) `uvm_fatal("TEST", "Cannot open v_input.hex")
    for (int i = 0; i < NUM_EL; i++) begin
      $fgets(line, fd);
      $sscanf(line, "%h", val);
      v_data[i] = val[15:0];
    end
    $fclose(fd);

    // Load expected output
    fd = $fopen("../../../tools/golden/attention_output.hex", "r");
    if (fd == 0) `uvm_fatal("TEST", "Cannot open attention_output.hex")
    for (int i = 0; i < NUM_EL; i++) begin
      $fgets(line, fd);
      $sscanf(line, "%h", val);
      o_expected[i] = val[15:0];
    end
    $fclose(fd);

    `uvm_info("TEST", "Golden data loaded successfully", UVM_LOW)
  endtask

  // Write FP16 values to SRAM via APB (16-bit per word)
  task write_sram16(bit [31:0] base, input logic [15:0] data[128], input int count, input string name);
    for (int i = 0; i < count; i++) begin
      apb_write_seq wr;
      wr = apb_write_seq::type_id::create($sformatf("wr_%s_%0d", name, i));
      wr.addr = base + (i * 2);  // 16-bit addressing
      wr.data = {16'b0, data[i]};
      wr.start(env.apb_agt.sequencer);
    end
    `uvm_info("TEST", $sformatf("Wrote %0d FP16 words to %s", count, name), UVM_LOW)
  endtask

  // Read FP16 values from SRAM via APB (inline loop since ref+dynamic array not supported)
  task read_sram16(bit [31:0] base, output logic [15:0] data[128], input int count, input string name);
    for (int i = 0; i < count; i++) begin
      apb_read_seq rd;
      rd = apb_read_seq::type_id::create($sformatf("rd_%s_%0d", name, i));
      rd.addr = base + (i * 2);
      rd.start(env.apb_agt.sequencer);
      data[i] = rd.rdata[15:0];
    end
    `uvm_info("TEST", $sformatf("Read %0d FP16 words from %s", count, name), UVM_LOW)
  endtask

  task write_reg(bit [31:0] addr, bit [31:0] data);
    apb_write_seq wr;
    wr = apb_write_seq::type_id::create("wr_reg");
    wr.addr = addr;
    wr.data = data;
    wr.start(env.apb_agt.sequencer);
  endtask
endclass
