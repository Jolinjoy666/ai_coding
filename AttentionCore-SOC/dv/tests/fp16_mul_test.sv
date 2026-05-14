// FP16 Multiplier Test
`timescale 1ns/1ps

module fp16_mul_test;

  logic clk, rst_n;
  logic [15:0] a, b, product;
  logic overflow, underflow;

  fp16_multiplier u_dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .a_i        (a),
    .b_i        (b),
    .product_o  (product),
    .overflow_o (overflow),
    .underflow_o(underflow)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  always @(posedge clk) begin
    $display("[%0t] a=%h b=%h -> product=%h", $time, a, b, product);
  end

  initial begin
    rst_n = 0; a = 0; b = 0;
    #30;
    rst_n = 1;
    #20;

    // 1.0 * 1.0
    $display("\n=== 1.0 * 1.0 ===");
    a = 16'h3C00; b = 16'h3C00;
    repeat(5) @(posedge clk);

    // 2.0 * 3.0
    $display("\n=== 2.0 * 3.0 ===");
    a = 16'h4000; b = 16'h4200;
    repeat(5) @(posedge clk);

    $finish;
  end
endmodule
