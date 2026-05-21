// FP16 MAC (Multiply-Accumulate) Unit
// Pipeline: multiply (3 cycles) + accumulate (1 cycle) = 4 cycles total
// product_o is NBA'd at posedge N+2; mul_result (PRE-NBA) valid at N+3.
// Accumulation uses mul_valid_s4 (one extra stage) to align with correct mul_result.

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

  // Register inputs so they stay stable through the 3-stage multiplier pipeline.
  // valid_i is 1 cycle (DRIVE_S), but fp16_multiplier needs inputs stable for 3 posedges.
  logic [FP16_WIDTH-1:0] a_reg, b_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a_reg <= '0;
      b_reg <= '0;
    end else if (valid_i) begin
      a_reg <= a_i;
      b_reg <= b_i;
    end
  end

  // FP16 multiply (3 registered stages)
  logic [FP16_WIDTH-1:0] mul_result;

  fp16_multiplier u_mul (
    .clk        (clk),
    .rst_n      (rst_n),
    .a_i        (a_reg),
    .b_i        (b_reg),
    .product_o  (mul_result),
    .overflow_o (),
    .underflow_o()
  );

  // Pipeline valid signals: 4 stages to match multiplier NBA latency
  // valid_i@N → s1@N+1 → s2@N+2 → s3@N+3 → s4@N+4
  // mul_result (product_o) NBA'd at N+2, readable (PRE-NBA) at N+3
  // Accumulation at s4 (N+4) uses mul_result from N+3 (which is the NBA'd value from N+2)
  logic mul_valid_s1, mul_valid_s2, mul_valid_s3, mul_valid_s4;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_valid_s1 <= 1'b0;
      mul_valid_s2 <= 1'b0;
      mul_valid_s3 <= 1'b0;
      mul_valid_s4 <= 1'b0;
    end else begin
      mul_valid_s1 <= valid_i;
      mul_valid_s2 <= mul_valid_s1;
      mul_valid_s3 <= mul_valid_s2;
      mul_valid_s4 <= mul_valid_s3;
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
    end else if (mul_valid_s4) begin
      acc_q <= acc_d;
    end
  end

  // Delay valid_o to align with updated acc_q
  logic valid_o_d;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      valid_o_d <= 1'b0;
    else
      valid_o_d <= mul_valid_s4;
  end

  // Output
  assign result_o = acc_q;
  assign valid_o  = valid_o_d;


endmodule
