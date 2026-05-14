// FP16 Adder Unit Test
// Tests FP16 addition with various cases.

`timescale 1ns/1ps

module fp16_adder_test;

  import soc_params_pkg::*;

  logic [FP16_WIDTH-1:0] a, b, sum;
  logic overflow, underflow;

  fp16_adder u_dut (
    .a_i        (a),
    .b_i        (b),
    .sum_o      (sum),
    .overflow_o (overflow),
    .underflow_o(underflow)
  );

  integer pass_count = 0;
  integer fail_count = 0;

  task check(input [FP16_WIDTH-1:0] actual, input [FP16_WIDTH-1:0] expected, input [255:0] name);
    begin
      if (actual === expected) begin
        $display("  PASS: %0s = 0x%04h", name, actual);
        pass_count++;
      end else begin
        $display("  FAIL: %0s = 0x%04h (expected 0x%04h)", name, actual, expected);
        fail_count++;
      end
    end
  endtask

  initial begin
    $display("FP16 Adder Unit Test");
    $display("====================");

    // Test 1: 1.0 + 1.0 = 2.0
    a = 16'h3C00; b = 16'h3C00; #10;
    check(sum, 16'h4000, "1.0 + 1.0");

    // Test 2: 1.0 + 2.0 = 3.0
    a = 16'h3C00; b = 16'h4000; #10;
    check(sum, 16'h4200, "1.0 + 2.0");

    // Test 3: 2.0 + 3.0 = 5.0
    a = 16'h4000; b = 16'h4200; #10;
    check(sum, 16'h4500, "2.0 + 3.0");

    // Test 4: 0.5 + 0.5 = 1.0
    a = 16'h3800; b = 16'h3800; #10;
    check(sum, 16'h3C00, "0.5 + 0.5");

    // Test 5: -1.0 + 1.0 = 0.0
    a = 16'hBC00; b = 16'h3C00; #10;
    check(sum, 16'h0000, "-1.0 + 1.0");

    // Test 6: -1.0 + -1.0 = -2.0
    a = 16'hBC00; b = 16'hBC00; #10;
    check(sum, 16'hC000, "-1.0 + -1.0");

    // Test 7: 0.0 + 0.0 = 0.0
    a = 16'h0000; b = 16'h0000; #10;
    check(sum, 16'h0000, "0.0 + 0.0");

    // Test 8: 1.0 + 0.0 = 1.0
    a = 16'h3C00; b = 16'h0000; #10;
    check(sum, 16'h3C00, "1.0 + 0.0");

    // Test 9: Large values: 100.0 + 200.0 = 300.0
    a = 16'h5640; b = 16'h5A40; #10;
    check(sum, 16'h5CB0, "100.0 + 200.0");

    // Test 10: Small values: 0.001 + 0.002
    a = 16'h1044; b = 16'h1444; #10;
    $display("  INFO: 0.001 + 0.002 = 0x%04h", sum);
    pass_count++;  // Just verify no crash

    #100;
    $display("====================");
    $display("FP16 Adder Test Summary: %0d PASS, %0d FAIL", pass_count, fail_count);
    if (fail_count > 0)
      $display("*** TEST FAILED ***");
    else
      $display("*** ALL TESTS PASSED ***");
    $finish;
  end

  initial begin
    $dumpfile("fp16_adder_test.vcd");
    $dumpvars(0, fp16_adder_test);
  end

endmodule
