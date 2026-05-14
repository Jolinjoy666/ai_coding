// FP16 Multiplier
// 2-stage pipelined FP16 multiplication following IEEE 754 half-precision.

module fp16_multiplier
  import soc_params_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [FP16_WIDTH-1:0] a_i,
  input  logic [FP16_WIDTH-1:0] b_i,
  output logic [FP16_WIDTH-1:0] product_o,
  output logic                  overflow_o,
  output logic                  underflow_o
);

  // Stage 1: Unpack and multiply
  logic        a_sign_s1, b_sign_s1;
  logic [4:0]  a_exp_s1, b_exp_s1;
  logic [9:0]  a_man_s1, b_man_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_sign_s1 <= '0;
      b_sign_s1 <= '0;
      a_exp_s1  <= '0;
      b_exp_s1  <= '0;
      a_man_s1  <= '0;
      b_man_s1  <= '0;
    end else begin
      a_sign_s1 <= a_i[15];
      b_sign_s1 <= b_i[15];
      a_exp_s1  <= a_i[14:10];
      b_exp_s1  <= b_i[14:10];
      a_man_s1  <= a_i[9:0];
      b_man_s1  <= b_i[9:0];
    end
  end

  // Implicit leading 1
  logic [10:0] a_frac_s1, b_frac_s1;
  assign a_frac_s1 = (a_exp_s1 != 0) ? {1'b1, a_man_s1} : {1'b0, a_man_s1};
  assign b_frac_s1 = (b_exp_s1 != 0) ? {1'b1, b_man_s1} : {1'b0, b_man_s1};

  // Multiply fractions: 11b × 11b = 22b
  logic [21:0] mul_result_s1;
  assign mul_result_s1 = a_frac_s1 * b_frac_s1;

  // Add exponents (subtract bias)
  logic [5:0]  exp_sum_s1;
  assign exp_sum_s1 = {1'b0, a_exp_s1} + {1'b0, b_exp_s1} - 6'd15;

  // Sign
  logic        result_sign_s1;
  assign result_sign_s1 = a_sign_s1 ^ b_sign_s1;

  // Stage 2: Normalize and output
  logic        result_sign_s2;
  logic [5:0]  exp_sum_s2;
  logic [21:0] mul_result_s2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result_sign_s2 <= '0;
      exp_sum_s2     <= '0;
      mul_result_s2  <= '0;
    end else begin
      result_sign_s2 <= result_sign_s1;
      exp_sum_s2     <= exp_sum_s1;
      mul_result_s2  <= mul_result_s1;
    end
  end

  // Normalization
  logic [4:0]  norm_exp;
  logic [9:0]  norm_man;
  logic        is_zero;

  always_comb begin
    is_zero = (mul_result_s2 == 0);

    if (mul_result_s2[21]) begin
      // MSB set, shift right
      norm_exp = exp_sum_s2[4:0] + 1;
      norm_man = mul_result_s2[20:11];
    end else begin
      // Already normalized
      norm_exp = exp_sum_s2[4:0];
      norm_man = mul_result_s2[19:10];
    end
  end

  // Overflow/underflow
  logic overflow_s2, underflow_s2;
  assign overflow_s2  = (exp_sum_s2[5] && !exp_sum_s2[4]) || (norm_exp == 5'h1F);
  assign underflow_s2 = exp_sum_s2[5] || (norm_exp == 0);

  // Output register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      product_o   <= '0;
      overflow_o  <= 1'b0;
      underflow_o <= 1'b0;
    end else begin
      if (is_zero) begin
        product_o <= 16'b0;
      end else if (overflow_s2) begin
        product_o <= {result_sign_s2, 5'h1F, 10'b0};  // Inf
      end else if (underflow_s2) begin
        product_o <= 16'b0;  // Flush to zero
      end else begin
        product_o <= {result_sign_s2, norm_exp, norm_man};
      end
      overflow_o  <= overflow_s2;
      underflow_o <= underflow_s2;
    end
  end

endmodule
