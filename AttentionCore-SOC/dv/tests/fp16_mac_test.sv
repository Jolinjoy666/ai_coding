// FP16 MAC Unit Test
// Tests basic FP16 multiply-accumulate operation.

`timescale 1ns/1ps

module fp16_mac_test;

  import soc_params_pkg::*;

  logic clk, rst_n;
  logic clear;
  logic [FP16_WIDTH-1:0] a, b;
  logic valid;
  logic [FP16_WIDTH-1:0] result;
  logic result_valid;

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

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  integer pass_count = 0;
  integer fail_count = 0;

  // Wait for valid_o with timeout, check LAST result matches expected
  task automatic wait_for_valid(
    input [FP16_WIDTH-1:0] expected,
    input integer timeout_cycles,
    input [255:0] test_name
  );
    integer cycles;
    logic found;
    logic [FP16_WIDTH-1:0] last_result;
    begin
      found = 0;
      last_result = '0;
      for (cycles = 0; cycles < timeout_cycles; cycles++) begin
        @(posedge clk);
        #1;
        if (result_valid) begin
          found = 1;
          last_result = result;
        end
      end
      if (!found) begin
        $display("  FAIL: valid_o never asserted within %0d cycles", timeout_cycles);
        fail_count++;
      end else if (last_result === expected) begin
        $display("  PASS: result=%h (expected %h)", last_result, expected);
        pass_count++;
      end else begin
        $display("  FAIL: result=%h (expected %h)", last_result, expected);
        fail_count++;
      end
    end
  endtask

  initial begin
    rst_n = 0;
    clear = 0;
    a = 0;
    b = 0;
    valid = 0;
    #50;
    rst_n = 1;
    @(posedge clk);
    #1;

    // Test 1: 1.0 * 1.0 = 1.0
    $display("[%0t] Test 1: 1.0 * 1.0", $time);
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = 16'h3C00;
    b = 16'h3C00;
    valid = 1;
    @(posedge clk);
    #1;
    valid = 0;
    wait_for_valid(16'h3C00, 12, "1.0*1.0");

    // Test 2: 2.0 * 3.0 = 6.0
    $display("[%0t] Test 2: 2.0 * 3.0", $time);
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = 16'h4000;
    b = 16'h4200;
    valid = 1;
    @(posedge clk);
    #1;
    valid = 0;
    wait_for_valid(16'h4600, 12, "2.0*3.0");

    // Test 3: Accumulation: 1.0 + 2.0 + 3.0 = 6.0
    $display("[%0t] Test 3: Accumulation 1.0 + 2.0 + 3.0", $time);
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;

    // First MAC: 1.0 * 1.0
    a = 16'h3C00;
    b = 16'h3C00;
    valid = 1;
    @(posedge clk);
    #1;

    // Second MAC: 2.0 * 1.0
    a = 16'h4000;
    b = 16'h3C00;
    @(posedge clk);
    #1;

    // Third MAC: 3.0 * 1.0
    a = 16'h4200;
    b = 16'h3C00;
    @(posedge clk);
    #1;
    valid = 0;

    // Wait for last valid_o (3 pipelined MACs, last fires ~4 cycles after 3rd input)
    wait_for_valid(16'h4600, 15, "1+2+3 accumulation");

    #100;
    $display("========================================");
    $display("FP16 MAC Test Summary: %0d PASS, %0d FAIL", pass_count, fail_count);
    $display("========================================");
    if (fail_count > 0)
      $display("*** TEST FAILED ***");
    else
      $display("*** ALL TESTS PASSED ***");
    $finish;
  end

  initial begin
    $dumpfile("fp16_mac_test.vcd");
    $dumpvars(0, fp16_mac_test);
  end

endmodule
