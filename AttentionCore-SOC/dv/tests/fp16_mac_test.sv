// FP16 MAC Unit Test
// Tests basic FP16 multiply-accumulate operation.

`timescale 1ns/1ps

module fp16_mac_test;

  import soc_params_pkg::*;

  // Signals
  logic clk, rst_n;
  logic clear;
  logic [FP16_WIDTH-1:0] a, b;
  logic valid;
  logic [FP16_WIDTH-1:0] result;
  logic result_valid;

  // DUT
  fp16_mac u_dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .clear_i  (clear),
    .a_i      (a),
    .b_i      (b),
    .valid_i  (valid),
    .result_o (result),
    .valid_o  (result_valid)
  );

  // Clock
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Test
  initial begin
    // Reset
    rst_n = 0;
    clear = 0;
    a = 0;
    b = 0;
    valid = 0;
    #20;
    rst_n = 1;
    #10;

    // Test 1: 1.0 * 1.0 = 1.0
    $display("[%0t] Test 1: 1.0 * 1.0", $time);
    clear = 1;
    @(posedge clk);
    clear = 0;
    a = 16'h3C00;  // 1.0 in FP16
    b = 16'h3C00;  // 1.0 in FP16
    valid = 1;
    @(posedge clk);
    valid = 0;

    // Wait for pipeline
    repeat(5) @(posedge clk);

    if (result_valid) begin
      $display("  Result: %h (expected ~3C00)", result);
    end else begin
      $display("  ERROR: Result not valid");
    end

    // Test 2: 2.0 * 3.0 = 6.0
    $display("[%0t] Test 2: 2.0 * 3.0", $time);
    clear = 1;
    @(posedge clk);
    clear = 0;
    a = 16'h4000;  // 2.0 in FP16
    b = 16'h4200;  // 3.0 in FP16
    valid = 1;
    @(posedge clk);
    valid = 0;

    // Wait for pipeline
    repeat(5) @(posedge clk);

    if (result_valid) begin
      $display("  Result: %h (expected ~4600)", result);
    end else begin
      $display("  ERROR: Result not valid");
    end

    // Test 3: Accumulation: 1.0 + 2.0 + 3.0 = 6.0
    $display("[%0t] Test 3: Accumulation 1.0 + 2.0 + 3.0", $time);
    clear = 1;
    @(posedge clk);
    clear = 0;

    // First: 1.0 * 1.0
    a = 16'h3C00;  // 1.0
    b = 16'h3C00;  // 1.0
    valid = 1;
    @(posedge clk);

    // Second: 2.0 * 1.0
    a = 16'h4000;  // 2.0
    b = 16'h3C00;  // 1.0
    @(posedge clk);

    // Third: 3.0 * 1.0
    a = 16'h4200;  // 3.0
    b = 16'h3C00;  // 1.0
    @(posedge clk);

    valid = 0;

    // Wait for pipeline
    repeat(5) @(posedge clk);

    if (result_valid) begin
      $display("  Result: %h (expected ~4600 = 6.0)", result);
    end else begin
      $display("  ERROR: Result not valid");
    end

    #100;
    $display("[%0t] FP16 MAC test complete", $time);
    $finish;
  end

  // Waveform
  initial begin
    $dumpfile("fp16_mac_test.vcd");
    $dumpvars(0, fp16_mac_test);
  end

endmodule
