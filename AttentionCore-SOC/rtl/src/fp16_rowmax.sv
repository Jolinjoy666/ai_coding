// FP16 Row Max
// Tree of comparators to find maximum value in a row.
// Parameterizable width.

module fp16_rowmax
  import soc_params_pkg::*;
#(
  parameter int WIDTH = TILE_B_R
)(
  input  logic [WIDTH-1:0][FP16_WIDTH-1:0] data_i,
  output logic [FP16_WIDTH-1:0]            max_o
);

  // Tree reduction
  generate
    if (WIDTH == 1) begin : gen_single
      assign max_o = data_i[0];
    end else if (WIDTH == 2) begin : gen_two
      fp16_comparator u_cmp (
        .a_i   (data_i[0]),
        .b_i   (data_i[1]),
        .max_o (max_o)
      );
    end else begin : gen_tree
      // Recursive tree
      localparam int HALF = WIDTH / 2;
      localparam int REM  = WIDTH - HALF;

      logic [FP16_WIDTH-1:0] max_left, max_right;

      fp16_rowmax #(.WIDTH(HALF)) u_left (
        .data_i (data_i[HALF-1:0]),
        .max_o  (max_left)
      );

      fp16_rowmax #(.WIDTH(REM)) u_right (
        .data_i (data_i[WIDTH-1:HALF]),
        .max_o  (max_right)
      );

      fp16_comparator u_cmp (
        .a_i   (max_left),
        .b_i   (max_right),
        .max_o (max_o)
      );
    end
  endgenerate

endmodule
