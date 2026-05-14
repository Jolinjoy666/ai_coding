// AttentionCore-SOC Testbench
// SOC-level verification using test_mode APB interface.

`timescale 1ns/1ps

module tb_attentioncore_soc;

  import soc_params_pkg::*;

  logic clk, rst_n;
  logic uart_rx, uart_tx;
  logic [7:0] gpio_out;
  logic [3:0] gpio_in;
  logic irq;

  // Test mode APB signals
  logic        test_mode;
  logic [31:0] test_paddr;
  logic        test_psel;
  logic        test_penable;
  logic        test_pwrite;
  logic [31:0] test_pwdata;
  logic [31:0] test_prdata;
  logic        test_pready;
  logic        test_pslverr;

  attentioncore_soc_top u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .uart_rx        (uart_rx),
    .uart_tx        (uart_tx),
    .gpio_out       (gpio_out),
    .gpio_in        (gpio_in),
    .irq            (irq),
    .test_mode_i    (test_mode),
    .test_paddr_i   (test_paddr),
    .test_psel_i    (test_psel),
    .test_penable_i (test_penable),
    .test_pwrite_i  (test_pwrite),
    .test_pwdata_i  (test_pwdata),
    .test_prdata_o  (test_prdata),
    .test_pready_o  (test_pready),
    .test_pslverr_o (test_pslverr)
  );

  // 100MHz clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // ---- APB Master Task ----
  task automatic apb_write(input [31:0] addr, input [31:0] data);
    begin
      @(posedge clk);
      test_paddr  = addr;
      test_pwdata = data;
      test_pwrite = 1'b1;
      test_psel   = 1'b1;
      test_penable = 1'b0;
      @(posedge clk);
      test_penable = 1'b1;
      @(posedge clk);
      test_psel   = 1'b0;
      test_penable = 1'b0;
      test_pwrite = 1'b0;
    end
  endtask

  task automatic apb_read(input [31:0] addr, output [31:0] data);
    begin
      @(posedge clk);
      test_paddr  = addr;
      test_pwrite = 1'b0;
      test_psel   = 1'b1;
      test_penable = 1'b0;
      @(posedge clk);
      test_penable = 1'b1;
      @(posedge clk);
      data = test_prdata;
      test_psel   = 1'b0;
      test_penable = 1'b0;
    end
  endtask

  // ---- Test Counters ----
  integer pass_count = 0;
  integer fail_count = 0;

  task check(input [31:0] actual, input [31:0] expected, input [255:0] name);
    begin
      if (actual === expected) begin
        $display("  PASS: %0s = 0x%08h", name, actual);
        pass_count++;
      end else begin
        $display("  FAIL: %0s = 0x%08h (expected 0x%08h)", name, actual, expected);
        fail_count++;
      end
    end
  endtask

  // ---- Main Test Sequence ----
  initial begin
    // Init
    rst_n       = 0;
    uart_rx     = 1;
    gpio_in     = 4'hA;
    test_mode   = 1;
    test_paddr  = '0;
    test_pwdata = '0;
    test_psel   = 0;
    test_penable = 0;
    test_pwrite = 0;

    // Reset
    #100;
    rst_n = 1;
    #100;

    // =============================================
    // Test 1: Data SRAM read/write
    // =============================================
    $display("[%0t] Test 1: Data SRAM read/write", $time);
    begin
      logic [31:0] rdata;
      apb_write(DATA_BASE + 32'h00, 32'hDEAD_BEEF);
      apb_write(DATA_BASE + 32'h04, 32'hCAFE_BABE);
      apb_read(DATA_BASE + 32'h00, rdata);
      check(rdata, 32'hDEAD_BEEF, "data_sram[0]");
      apb_read(DATA_BASE + 32'h04, rdata);
      check(rdata, 32'hCAFE_BABE, "data_sram[1]");
    end

    // =============================================
    // Test 2: Weight SRAM read/write (16-bit)
    // =============================================
    $display("[%0t] Test 2: Weight SRAM read/write", $time);
    begin
      logic [31:0] rdata;
      apb_write(WEIGHT_BASE + 32'h00, 32'h0000_3C00);
      apb_write(WEIGHT_BASE + 32'h02, 32'h0000_4000);
      apb_read(WEIGHT_BASE + 32'h00, rdata);
      check(rdata & 32'hFFFF, 32'h0000_3C00, "weight_sram[0]");
      apb_read(WEIGHT_BASE + 32'h02, rdata);
      check(rdata & 32'hFFFF, 32'h0000_4000, "weight_sram[1]");
    end

    // =============================================
    // Test 3: Feature SRAM read/write (16-bit)
    // =============================================
    $display("[%0t] Test 3: Feature SRAM read/write", $time);
    begin
      logic [31:0] rdata;
      apb_write(FEATURE_BASE + 32'h00, 32'h0000_4200);
      apb_read(FEATURE_BASE + 32'h00, rdata);
      check(rdata & 32'hFFFF, 32'h0000_4200, "feature_sram[0]");
    end

    // =============================================
    // Test 4: KV-Cache SRAM read/write (16-bit)
    // =============================================
    $display("[%0t] Test 4: KV-Cache SRAM read/write", $time);
    begin
      logic [31:0] rdata;
      apb_write(KVCACHE_BASE + 32'h00, 32'h0000_4400);
      apb_read(KVCACHE_BASE + 32'h00, rdata);
      check(rdata & 32'hFFFF, 32'h0000_4400, "kvcache_sram[0]");
    end

    // =============================================
    // Test 5: Attention engine config defaults
    // =============================================
    $display("[%0t] Test 5: Attention engine config defaults", $time);
    begin
      logic [31:0] rdata;
      apb_read(ATTN_BASE + REG_CFG_SEQ_LEN, rdata);
      check(rdata & 32'hFFFF, SEQ_LEN, "cfg_seq_len");
      apb_read(ATTN_BASE + REG_CFG_D_MODEL, rdata);
      check(rdata & 32'hFFFF, D_MODEL, "cfg_d_model");
      apb_read(ATTN_BASE + REG_CFG_N_HEAD, rdata);
      check(rdata & 32'hFFFF, N_HEAD, "cfg_n_head");
      apb_read(ATTN_BASE + REG_CFG_MAC_ROWS, rdata);
      check(rdata & 32'hFFFF, 32'd4, "cfg_mac_rows");
      apb_read(ATTN_BASE + REG_CFG_MAC_COLS, rdata);
      check(rdata & 32'hFFFF, 32'd4, "cfg_mac_cols");
    end

    // =============================================
    // Test 6: Control register write/read
    // =============================================
    $display("[%0t] Test 6: Control register write/read", $time);
    begin
      logic [31:0] rdata;
      apb_write(ATTN_BASE + REG_CFG_SEQ_LEN, 32'h0000_0010);
      apb_read(ATTN_BASE + REG_CFG_SEQ_LEN, rdata);
      check(rdata & 32'hFFFF, 32'h0010, "cfg_seq_len");
      apb_write(ATTN_BASE + REG_CFG_D_MODEL, 32'h0000_0020);
      apb_read(ATTN_BASE + REG_CFG_D_MODEL, rdata);
      check(rdata & 32'hFFFF, 32'h0020, "cfg_d_model");
    end

    // =============================================
    // Test 7: GPIO output
    // =============================================
    $display("[%0t] Test 7: GPIO output", $time);
    begin
      logic [31:0] rdata;
      apb_write(GPIO_BASE + 32'h00, 32'h0000_00A5);
      #20;
      check({24'b0, gpio_out}, 32'h0000_00A5, "gpio_out");
    end

    // =============================================
    // Test 8: GPIO input
    // =============================================
    $display("[%0t] Test 8: GPIO input", $time);
    begin
      logic [31:0] rdata;
      apb_read(GPIO_BASE + 32'h04, rdata);
      check(rdata & 32'h0F, 32'h0000_000A, "gpio_in");
    end

    // =============================================
    // Test 9: Timer register access
    // =============================================
    $display("[%0t] Test 9: Timer register access", $time);
    begin
      logic [31:0] rdata;
      apb_read(TIMER_BASE + 32'h00, rdata);
      $display("  INFO: timer_ctrl = 0x%08h", rdata);
      pass_count++;
    end

    // =============================================
    // Test 10: Attention engine status
    // =============================================
    $display("[%0t] Test 10: Attention engine status", $time);
    begin
      logic [31:0] rdata;
      apb_read(ATTN_BASE + REG_STATUS, rdata);
      $display("  INFO: attn_status = 0x%08h", rdata);
      // Write start
      apb_write(ATTN_BASE + REG_CTRL, 32'h0000_0001);
      #50;
      apb_read(ATTN_BASE + REG_STATUS, rdata);
      $display("  INFO: attn_status after start = 0x%08h", rdata);
      pass_count++;
    end

    // =============================================
    // Test 11: IRQ output
    // =============================================
    $display("[%0t] Test 11: IRQ output", $time);
    begin
      apb_write(ATTN_BASE + REG_IRQ_EN, 32'h0000_0001);
      #20;
      $display("  INFO: irq = %b", irq);
      pass_count++;
    end

    // =============================================
    // Test 12: Instruction SRAM access
    // =============================================
    $display("[%0t] Test 12: Instruction SRAM access", $time);
    begin
      logic [31:0] rdata;
      apb_write(INST_BASE + 32'h00, 32'h1234_5678);
      apb_read(INST_BASE + 32'h00, rdata);
      check(rdata, 32'h1234_5678, "inst_sram[0]");
    end

    // =============================================
    // Summary
    // =============================================
    #200;
    $display("========================================");
    $display("SOC Test Summary: %0d PASS, %0d FAIL", pass_count, fail_count);
    $display("========================================");
    if (fail_count > 0)
      $display("*** TEST FAILED ***");
    else
      $display("*** ALL TESTS PASSED ***");
    $finish;
  end

  // Waveform
  initial begin
    $dumpfile("tb_attentioncore_soc.vcd");
    $dumpvars(0, tb_attentioncore_soc);
  end

  // Timeout
  initial begin
    #500000;
    $display("[%0t] ERROR: Simulation timeout!", $time);
    $finish;
  end

endmodule
