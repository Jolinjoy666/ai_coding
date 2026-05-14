// Residual Add
// Computes output = x + residual (FP16)
// d_model parallel FP16 adders.

module residual_add
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Control
  input  logic        start_i,
  input  logic        abort_i,
  output logic        done_o,
  output logic        busy_o,

  // Data input (streaming)
  input  logic [FP16_WIDTH-1:0] x_i,
  input  logic [FP16_WIDTH-1:0] residual_i,
  input  logic                  valid_i,
  input  logic                  last_i,

  // Data output
  output logic [FP16_WIDTH-1:0] sum_o,
  output logic                  valid_o,

  // Interrupt
  output logic                  irq_o
);

  // Simple pipeline: 1 cycle latency
  logic [FP16_WIDTH-1:0] sum;
  logic valid_q, last_q;

  fp16_adder u_add (
    .a_i        (x_i),
    .b_i        (residual_i),
    .sum_o      (sum),
    .overflow_o (),
    .underflow_o()
  );

  // Pipeline register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum_o   <= '0;
      valid_q <= 1'b0;
      last_q  <= 1'b0;
    end else begin
      sum_o   <= sum;
      valid_q <= valid_i;
      last_q  <= last_i;
    end
  end

  assign valid_o = valid_q;

  // Done/IRQ on last transfer
  logic done_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done_q <= 1'b0;
    end else begin
      done_q <= valid_q && last_q;
    end
  end

  assign done_o = done_q;
  assign irq_o  = done_q;
  assign busy_o = valid_i;

endmodule
