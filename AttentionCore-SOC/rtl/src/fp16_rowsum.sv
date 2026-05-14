// FP16 Row Sum
// Tree of adders to sum values in a row.
// Parameterizable width.

module fp16_rowsum
  import soc_params_pkg::*;
#(
  parameter int WIDTH = TILE_B_R
)(
  input  logic [WIDTH-1:0][FP16_WIDTH-1:0] data_i,
  output logic [FP16_WIDTH-1:0]            sum_o
);

  // Tree reduction
  generate
    if (WIDTH == 1) begin : gen_single
      assign sum_o = data_i[0];
    end else if (WIDTH == 2) begin : gen_two
      fp16_adder u_add (
        .a_i        (data_i[0]),
        .b_i        (data_i[1]),
        .sum_o      (sum_o),
        .overflow_o (),
        .underflow_o()
      );
    end else begin : gen_tree
      localparam int HALF = WIDTH / 2;
      localparam int REM  = WIDTH - HALF;

      logic [FP16_WIDTH-1:0] sum_left, sum_right;

      fp16_rowsum #(.WIDTH(HALF)) u_left (
        .data_i (data_i[HALF-1:0]),
        .sum_o  (sum_left)
      );

      fp16_rowsum #(.WIDTH(REM)) u_right (
        .data_i (data_i[WIDTH-1:HALF]),
        .sum_o  (sum_right)
      );

      fp16_adder u_add (
        .a_i        (sum_left),
        .b_i        (sum_right),
        .sum_o      (sum_o),
        .overflow_o (),
        .underflow_o()
      );
    end
  endgenerate

endmodule
