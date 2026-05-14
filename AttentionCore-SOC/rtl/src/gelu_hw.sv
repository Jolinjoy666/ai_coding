// GELU Hardware Implementation
// Piecewise linear approximation with 32 segments.
// GELU(x) ≈ 0.5x(1 + tanh(√(2/π)(x + 0.044715x³)))

module gelu_hw
  import soc_params_pkg::*;
(
  input  logic                  clk,
  input  logic                  rst_n,
  input  logic [FP16_WIDTH-1:0] x_i,
  input  logic                  valid_i,
  output logic [FP16_WIDTH-1:0] y_o,
  output logic                  valid_o
);

  // LUT: 32 segments for x in [-4, 4]
  // Each segment: y = a*x + b
  // a and b are FP16 constants
  localparam int SEGMENTS = GELU_SEGMENTS;

  // Segment coefficients (pre-computed)
  // For simplicity, using a simplified lookup
  logic [FP16_WIDTH-1:0] a_lut [0:SEGMENTS-1];
  logic [FP16_WIDTH-1:0] b_lut [0:SEGMENTS-1];

  // Initialize LUT (placeholder values)
  initial begin
    for (int i = 0; i < SEGMENTS; i++) begin
      a_lut[i] = 16'h3C00;  // 1.0
      b_lut[i] = 16'h0000;  // 0.0
    end
  end

  // Determine segment index
  logic [4:0] seg_idx;
  logic [FP16_WIDTH-1:0] x_abs;
  logic x_neg;

  always_comb begin
    x_neg = x_i[15];
    x_abs = x_neg ? {1'b0, x_i[14:0]} : x_i;

    // Clamp to [-4, 4]
    if (x_abs > 16'h4400) begin  // 4.0 in FP16
      seg_idx = 5'd31;
    end else begin
      // Simple index extraction (approximate)
      seg_idx = x_abs[8:4];
    end
  end

  // LUT read
  logic [FP16_WIDTH-1:0] a_q, b_q;
  logic [FP16_WIDTH-1:0] x_q;
  logic                  valid_q;
  logic                  neg_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_q     <= '0;
      b_q     <= '0;
      x_q     <= '0;
      valid_q <= 1'b0;
      neg_q   <= 1'b0;
    end else begin
      a_q     <= a_lut[seg_idx];
      b_q     <= b_lut[seg_idx];
      x_q     <= x_i;
      valid_q <= valid_i;
      neg_q   <= x_neg;
    end
  end

  // Multiply: a * x
  logic [FP16_WIDTH-1:0] ax;
  fp16_multiplier u_mul (
    .clk        (clk),
    .rst_n      (rst_n),
    .a_i        (a_q),
    .b_i        (x_q),
    .product_o  (ax),
    .overflow_o (),
    .underflow_o()
  );

  // Add: a*x + b
  logic [FP16_WIDTH-1:0] result;
  fp16_adder u_add (
    .a_i        (ax),
    .b_i        (b_q),
    .sum_o      (result),
    .overflow_o (),
    .underflow_o()
  );

  // Output
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      y_o     <= '0;
      valid_o <= 1'b0;
    end else begin
      // Boundary conditions
      if (x_q > 16'h4400) begin  // x > 4
        y_o <= x_q;
      end else if (neg_q && x_q > 16'hC400) begin  // x < -4
        y_o <= 16'h0000;
      end else begin
        y_o <= result;
      end
      valid_o <= valid_q;
    end
  end

endmodule
