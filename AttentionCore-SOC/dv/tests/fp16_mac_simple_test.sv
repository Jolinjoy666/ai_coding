// Simple FP16 MAC Test - Direct verification
`timescale 1ns/1ps

module fp16_mac_simple_test;

  // Signals
  logic clk, rst_n;
  logic clear;
  logic [15:0] a, b;
  logic valid;
  logic [15:0] result;
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

  // Monitor key signals
  always @(posedge clk) begin
    if (valid || result_valid || rst_n == 0)
      $display("[%0t] rst=%b clear=%b valid=%b a=%h b=%h | valid_o=%b result=%h",
               $time, rst_n, clear, valid, a, b, result_valid, result);
  end

  // Test
  initial begin
    $dumpfile("fp16_mac_simple.vcd");
    $dumpvars(0, fp16_mac_simple_test);

    // Reset
    rst_n = 0;
    clear = 0;
    a = 0;
    b = 0;
    valid = 0;
    #50;
    rst_n = 1;
    #20;

    // Test 1: 1.0 * 1.0
    $display("\n=== Test 1: 1.0 * 1.0 ===");
    @(posedge clk);
    #1;
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = 16'h3C00;  // 1.0
    b = 16'h3C00;  // 1.0
    valid = 1;
    @(posedge clk);
    #1;
    valid = 0;

    // Wait for pipeline and check result
    repeat(10) @(posedge clk);
    $display("  Final result=%h (expected ~3C00 = 1.0)", result);

    // Test 2: 2.0 * 3.0
    $display("\n=== Test 2: 2.0 * 3.0 ===");
    @(posedge clk);
    #1;
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = 16'h4000;  // 2.0
    b = 16'h4200;  // 3.0
    valid = 1;
    @(posedge clk);
    #1;
    valid = 0;

    // Wait for pipeline and check result
    repeat(10) @(posedge clk);
    $display("  Final result=%h (expected ~4600 = 6.0)", result);

    // Test 3: Accumulation 1.0 + 2.0 + 3.0
    $display("\n=== Test 3: Accumulation 1.0*1.0 + 2.0*1.0 + 3.0*1.0 ===");
    @(posedge clk);
    #1;
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;

    a = 16'h3C00;  // 1.0
    b = 16'h3C00;  // 1.0
    valid = 1;
    @(posedge clk);
    #1;

    a = 16'h4000;  // 2.0
    b = 16'h3C00;  // 1.0
    @(posedge clk);
    #1;

    a = 16'h4200;  // 3.0
    b = 16'h3C00;  // 1.0
    @(posedge clk);
    #1;
    valid = 0;

    // Wait for pipeline and check result
    repeat(10) @(posedge clk);
    $display("  Final result=%h (expected ~4600 = 6.0)", result);

    #50;
    $display("\n[%0t] FP16 MAC test complete", $time);
    $finish;
  end

endmodule
