// FP16 MAC (Multiply-Accumulate) Unit
// Pipeline: multiply (3 cycles) + accumulate (1 cycle)
// Result available 1 cycle after valid_o.

module fp16_mac
  import soc_params_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic                  clear_i,     // Clear accumulator
  input  logic [FP16_WIDTH-1:0] a_i,         // Input A (FP16)
  input  logic [FP16_WIDTH-1:0] b_i,         // Input B (FP16)
  input  logic                  valid_i,     // Input valid
  output logic [FP16_WIDTH-1:0] result_o,    // Result (FP16)
  output logic                  valid_o      // Result valid
);

  // FP16 multiply
  logic [FP16_WIDTH-1:0] mul_result;
  logic                  mul_valid_s1, mul_valid_s2, mul_valid_s3;

  fp16_multiplier u_mul (
    .clk        (clk),
    .rst_n      (rst_n),
    .a_i        (a_i),
    .b_i        (b_i),
    .product_o  (mul_result),
    .overflow_o (),
    .underflow_o()
  );

  // Pipeline valid signals (match multiplier latency)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_valid_s1 <= 1'b0;
      mul_valid_s2 <= 1'b0;
      mul_valid_s3 <= 1'b0;
    end else begin
      mul_valid_s1 <= valid_i;
      mul_valid_s2 <= mul_valid_s1;
      mul_valid_s3 <= mul_valid_s2;
    end
  end

  // Accumulate
  logic [FP16_WIDTH-1:0] acc_q, acc_d;

  fp16_adder u_acc_add (
    .a_i        (acc_q),
    .b_i        (mul_result),
    .sum_o      (acc_d),
    .overflow_o (),
    .underflow_o()
  );

  // Accumulator register - update when multiply result is ready
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_q <= '0;
    end else if (clear_i) begin
      acc_q <= '0;
    end else if (mul_valid_s3) begin
      acc_q <= acc_d;
    end
  end

  // Delay valid_o by 1 cycle to align with updated acc_q
  logic valid_o_d;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      valid_o_d <= 1'b0;
    else
      valid_o_d <= mul_valid_s3;
  end

  // Output - result_o shows updated acc_q when valid_o_d is high
  assign result_o = acc_q;
  assign valid_o  = valid_o_d;

endmodule
