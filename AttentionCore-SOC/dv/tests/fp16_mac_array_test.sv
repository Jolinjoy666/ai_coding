// FP16 MAC Array (4x4) Unit Test
// Tests systolic array matrix multiplication.

`timescale 1ns/1ps

module fp16_mac_array_test;

  import soc_params_pkg::*;

  logic clk, rst_n, clear;
  logic [MAC_ROWS-1:0][FP16_WIDTH-1:0] a;
  logic [MAC_COLS-1:0][FP16_WIDTH-1:0] b;
  logic valid;
  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] result;
  logic result_valid;

  fp16_mac_array u_dut (
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
    rst_n = 0;
    clear = 0;
    a = '0;
    b = '0;
    valid = 0;
    #50;
    rst_n = 1;
    @(posedge clk);
    #1;

    $display("FP16 MAC Array (4x4) Unit Test");
    $display("===============================");

    // Test 1: Identity-like: a=[1,0,0,0], b=[1,0,0,0]
    // result[0][0] should be 1.0*1.0=1.0, rest 0
    $display("[%0t] Test 1: Single element multiply", $time);
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = {16'h0000, 16'h0000, 16'h0000, 16'h3C00};  // [1.0, 0, 0, 0]
    b = {16'h0000, 16'h0000, 16'h0000, 16'h3C00};  // [1.0, 0, 0, 0]
    valid = 1;
    @(posedge clk);
    #1;
    valid = 0;
    repeat(8) @(posedge clk);
    #1;
    check(result[0][0], 16'h3C00, "result[0][0]=1.0*1.0");

    // Test 2: Full row * column: a=[1,2,3,4], b=[1,1,1,1]
    // Each PE: result[r][c] = a[r] * 1.0
    $display("[%0t] Test 2: Row vector * scalar", $time);
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = {16'h4400, 16'h4200, 16'h4000, 16'h3C00};  // [4.0, 3.0, 2.0, 1.0]
    b = {16'h3C00, 16'h3C00, 16'h3C00, 16'h3C00};  // [1.0, 1.0, 1.0, 1.0]
    valid = 1;
    @(posedge clk);
    #1;
    valid = 0;
    repeat(8) @(posedge clk);
    #1;
    check(result[0][0], 16'h3C00, "result[0][0]=1.0*1.0");
    check(result[1][0], 16'h4000, "result[1][0]=2.0*1.0");
    check(result[2][0], 16'h4200, "result[2][0]=3.0*1.0");
    check(result[3][0], 16'h4400, "result[3][0]=4.0*1.0");

    // Test 3: Accumulation: 2 cycles
    // Cycle 1: a=[1,1,1,1], b=[1,1,1,1] -> each PE gets 1.0
    // Cycle 2: a=[1,1,1,1], b=[1,1,1,1] -> each PE accumulates to 2.0
    $display("[%0t] Test 3: Two-cycle accumulation", $time);
    clear = 1;
    @(posedge clk);
    #1;
    clear = 0;
    a = {16'h3C00, 16'h3C00, 16'h3C00, 16'h3C00};
    b = {16'h3C00, 16'h3C00, 16'h3C00, 16'h3C00};
    valid = 1;
    @(posedge clk);
    #1;
    // Second cycle
    a = {16'h3C00, 16'h3C00, 16'h3C00, 16'h3C00};
    b = {16'h3C00, 16'h3C00, 16'h3C00, 16'h3C00};
    @(posedge clk);
    #1;
    valid = 0;
    repeat(10) @(posedge clk);
    #1;
    check(result[0][0], 16'h4000, "result[0][0]=1+1=2.0");
    check(result[1][1], 16'h4000, "result[1][1]=1+1=2.0");
    check(result[2][2], 16'h4000, "result[2][2]=1+1=2.0");
    check(result[3][3], 16'h4000, "result[3][3]=1+1=2.0");

    #100;
    $display("===============================");
    $display("MAC Array Test Summary: %0d PASS, %0d FAIL", pass_count, fail_count);
    if (fail_count > 0)
      $display("*** TEST FAILED ***");
    else
      $display("*** ALL TESTS PASSED ***");
    $finish;
  end

  initial begin
    $dumpfile("fp16_mac_array_test.vcd");
    $dumpvars(0, fp16_mac_array_test);
  end

endmodule
