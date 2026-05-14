// FP16 Adder
// Single-cycle FP16 addition following IEEE 754 half-precision.

module fp16_adder
  import soc_params_pkg::*;
(
  input  logic [FP16_WIDTH-1:0] a_i,
  input  logic [FP16_WIDTH-1:0] b_i,
  output logic [FP16_WIDTH-1:0] sum_o,
  output logic                  overflow_o,
  output logic                  underflow_o
);

  // Unpack
  logic        a_sign, b_sign;
  logic [4:0]  a_exp, b_exp;
  logic [9:0]  a_man, b_man;

  assign a_sign = a_i[15];
  assign b_sign = b_i[15];
  assign a_exp  = a_i[14:10];
  assign b_exp  = b_i[14:10];
  assign a_man  = a_i[9:0];
  assign b_man  = b_i[9:0];

  // Implicit leading 1
  logic [10:0] a_frac, b_frac;
  assign a_frac = (a_exp != 0) ? {1'b1, a_man} : {1'b0, a_man};
  assign b_frac = (b_exp != 0) ? {1'b1, b_man} : {1'b0, b_man};

  // Exponent alignment
  logic [4:0]  exp_diff;
  logic [4:0]  larger_exp;
  logic [10:0] aligned_a, aligned_b;

  always_comb begin
    if (a_exp >= b_exp) begin
      exp_diff   = a_exp - b_exp;
      larger_exp = a_exp;
      aligned_a  = a_frac;
      aligned_b  = (exp_diff > 10) ? 11'b0 : (b_frac >> exp_diff);
    end else begin
      exp_diff   = b_exp - a_exp;
      larger_exp = b_exp;
      aligned_a  = (exp_diff > 10) ? 11'b0 : (a_frac >> exp_diff);
      aligned_b  = b_frac;
    end
  end

  // Addition (with sign)
  logic [11:0] sum_frac;
  logic        sum_sign;

  always_comb begin
    if (a_sign == b_sign) begin
      sum_frac = {1'b0, aligned_a} + {1'b0, aligned_b};
      sum_sign = a_sign;
    end else begin
      if (aligned_a >= aligned_b) begin
        sum_frac = {1'b0, aligned_a} - {1'b0, aligned_b};
        sum_sign = a_sign;
      end else begin
        sum_frac = {1'b0, aligned_b} - {1'b0, aligned_a};
        sum_sign = b_sign;
      end
    end
  end

  // Normalization
  logic [4:0]  norm_exp;
  logic [9:0]  norm_man;
  logic        is_zero;

  always_comb begin
    is_zero   = (sum_frac == 0);
    norm_exp  = larger_exp;
    norm_man  = sum_frac[9:0];

    if (sum_frac[11]) begin
      // Overflow in fraction, shift right
      norm_exp = larger_exp + 1;
      norm_man = sum_frac[10:1];
    end else if (sum_frac[10]) begin
      // Already normalized
      norm_man = sum_frac[9:0];
    end else if (sum_frac[9]) begin
      norm_exp = larger_exp - 1;
      norm_man = sum_frac[8:0];
    end else if (sum_frac[8]) begin
      norm_exp = larger_exp - 2;
      norm_man = sum_frac[7:0];
    end else begin
      // Very small or zero
      norm_exp = 0;
      norm_man = 0;
    end
  end

  // Overflow/underflow detection
  assign overflow_o  = (norm_exp == 5'h1F) && !is_zero;
  assign underflow_o = (norm_exp == 0) && !is_zero;

  // Output
  always_comb begin
    if (is_zero) begin
      sum_o = 16'b0;
    end else begin
      sum_o = {sum_sign, norm_exp, norm_man};
    end
  end

endmodule
