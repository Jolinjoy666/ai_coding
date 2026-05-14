// FP32 Adder
// Single-cycle FP32 addition following IEEE 754 single-precision.

module fp32_adder
  import soc_params_pkg::*;
(
  input  logic [FP32_WIDTH-1:0] a_i,
  input  logic [FP32_WIDTH-1:0] b_i,
  output logic [FP32_WIDTH-1:0] sum_o
);

  // Unpack
  logic        a_sign, b_sign;
  logic [7:0]  a_exp, b_exp;
  logic [22:0] a_man, b_man;

  assign a_sign = a_i[31];
  assign b_sign = b_i[31];
  assign a_exp  = a_i[30:23];
  assign b_exp  = b_i[30:23];
  assign a_man  = a_i[22:0];
  assign b_man  = b_i[22:0];

  // Implicit leading 1
  logic [23:0] a_frac, b_frac;
  assign a_frac = (a_exp != 0) ? {1'b1, a_man} : {1'b0, a_man};
  assign b_frac = (b_exp != 0) ? {1'b1, b_man} : {1'b0, b_man};

  // Exponent alignment
  logic [7:0]  exp_diff;
  logic [7:0]  larger_exp;
  logic [23:0] aligned_a, aligned_b;

  always_comb begin
    if (a_exp >= b_exp) begin
      exp_diff   = a_exp - b_exp;
      larger_exp = a_exp;
      aligned_a  = a_frac;
      aligned_b  = (exp_diff > 23) ? 24'b0 : (b_frac >> exp_diff);
    end else begin
      exp_diff   = b_exp - a_exp;
      larger_exp = b_exp;
      aligned_a  = (exp_diff > 23) ? 24'b0 : (a_frac >> exp_diff);
      aligned_b  = b_frac;
    end
  end

  // Addition (with sign)
  logic [24:0] sum_frac;
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
  logic [7:0]  norm_exp;
  logic [22:0] norm_man;
  logic        is_zero;

  always_comb begin
    is_zero   = (sum_frac == 0);
    norm_exp  = larger_exp;
    norm_man  = sum_frac[22:0];

    if (sum_frac[24]) begin
      norm_exp = larger_exp + 1;
      norm_man = sum_frac[23:1];
    end else if (sum_frac[23]) begin
      norm_man = sum_frac[22:0];
    end else if (sum_frac[22]) begin
      norm_exp = larger_exp - 1;
      norm_man = sum_frac[21:0];
    end else begin
      norm_exp = 0;
      norm_man = 0;
    end
  end

  // Output
  always_comb begin
    if (is_zero) begin
      sum_o = 32'b0;
    end else begin
      sum_o = {sum_sign, norm_exp, norm_man};
    end
  end

endmodule
