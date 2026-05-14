// FP16 Comparator
// Compares two FP16 values and returns the larger one.

module fp16_comparator
  import soc_params_pkg::*;
(
  input  logic [FP16_WIDTH-1:0] a_i,
  input  logic [FP16_WIDTH-1:0] b_i,
  output logic [FP16_WIDTH-1:0] max_o
);

  logic        a_sign, b_sign;
  logic [4:0]  a_exp, b_exp;
  logic [9:0]  a_man, b_man;

  assign a_sign = a_i[15];
  assign b_sign = b_i[15];
  assign a_exp  = a_i[14:10];
  assign b_exp  = b_i[14:10];
  assign a_man  = a_i[9:0];
  assign b_man  = b_i[9:0];

  logic a_is_nan, b_is_nan;
  assign a_is_nan = (a_exp == 5'h1F) && (a_man != 0);
  assign b_is_nan = (b_exp == 5'h1F) && (b_man != 0);

  logic a_greater;

  always_comb begin
    if (a_is_nan) begin
      a_greater = 1'b0;  // NaN is not greater
    end else if (b_is_nan) begin
      a_greater = 1'b1;
    end else if (a_sign != b_sign) begin
      a_greater = !a_sign;  // Positive > Negative
    end else if (a_sign == 1'b0) begin
      // Both positive
      if (a_exp != b_exp)
        a_greater = (a_exp > b_exp);
      else
        a_greater = (a_man >= b_man);
    end else begin
      // Both negative
      if (a_exp != b_exp)
        a_greater = (a_exp < b_exp);
      else
        a_greater = (a_man <= b_man);
    end
  end

  assign max_o = a_greater ? a_i : b_i;

endmodule
