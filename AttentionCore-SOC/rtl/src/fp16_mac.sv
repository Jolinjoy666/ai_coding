// FP16 MAC (Multiply-Accumulate) Unit
// 3-stage pipeline: multiply (2 stages) + accumulate (1 stage)
// Accumulator uses FP32 for precision, outputs FP16.

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

  // Stage 1-2: FP16 multiply
  logic [FP16_WIDTH-1:0] mul_result;
  logic                  mul_valid_s1, mul_valid_s2;

  fp16_multiplier u_mul (
    .clk        (clk),
    .rst_n      (rst_n),
    .a_i        (a_i),
    .b_i        (b_i),
    .product_o  (mul_result),
    .overflow_o (),
    .underflow_o()
  );

  // Pipeline valid signals
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_valid_s1 <= 1'b0;
      mul_valid_s2 <= 1'b0;
    end else begin
      mul_valid_s1 <= valid_i;
      mul_valid_s2 <= mul_valid_s1;
    end
  end

  // Stage 3: Accumulate in FP32
  logic [FP32_WIDTH-1:0] acc_q, acc_d;
  logic [FP32_WIDTH-1:0] mul_result_fp32;

  // Convert FP16 multiply result to FP32 for accumulation
  fp16_to_fp32 u_conv (
    .fp16_i (mul_result),
    .fp32_o (mul_result_fp32)
  );

  // FP32 adder for accumulation
  fp32_adder u_acc_add (
    .a_i   (acc_q),
    .b_i   (mul_result_fp32),
    .sum_o (acc_d)
  );

  // Accumulator register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_q <= '0;
    end else if (clear_i) begin
      acc_q <= '0;
    end else if (mul_valid_s2) begin
      acc_q <= acc_d;
    end
  end

  // Convert FP32 accumulator back to FP16 for output
  fp32_to_fp16 u_out_conv (
    .fp32_i (acc_q),
    .fp16_o (result_o)
  );

  // Output valid
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_o <= 1'b0;
    end else begin
      valid_o <= mul_valid_s2;
    end
  end

endmodule
