// FP16 MAC Array (4×4)
// Output-stationary systolic array for FP16 matrix multiplication.
// Each PE computes: result += a × b
// 3-stage pipeline per PE.

module fp16_mac_array
  import soc_params_pkg::*;
(
  input  logic                      clk,
  input  logic                      rst_n,
  input  logic                      clear_i,      // Clear all accumulators
  input  logic [MAC_ROWS-1:0][FP16_WIDTH-1:0] a_i,  // A matrix row
  input  logic [MAC_COLS-1:0][FP16_WIDTH-1:0] b_i,  // B matrix column
  input  logic                      valid_i,      // Input valid
  output logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] result_o,  // Results
  output logic                      valid_o       // Result valid
);

  // PE array
  genvar r, c;
  generate
    for (r = 0; r < MAC_ROWS; r++) begin : gen_row
      for (c = 0; c < MAC_COLS; c++) begin : gen_col
        fp16_mac u_pe (
          .clk      (clk),
          .rst_n    (rst_n),
          .clear_i  (clear_i),
          .a_i      (a_i[r]),
          .b_i      (b_i[c]),
          .valid_i  (valid_i),
          .result_o (result_o[r][c]),
          .valid_o  ()  // Use shared valid_o
        );
      end
    end
  endgenerate

  // Shared valid pipeline (matches PE latency: 3 mul + 1 acc = 4 cycles)
  logic valid_s1, valid_s2, valid_s3, valid_s4;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_s1 <= 1'b0;
      valid_s2 <= 1'b0;
      valid_s3 <= 1'b0;
      valid_s4 <= 1'b0;
    end else begin
      valid_s1 <= valid_i;
      valid_s2 <= valid_s1;
      valid_s3 <= valid_s2;
      valid_s4 <= valid_s3;
    end
  end

  assign valid_o = valid_s4;

endmodule
