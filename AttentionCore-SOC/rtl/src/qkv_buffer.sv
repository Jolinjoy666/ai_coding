// QKV Buffer
// Stores Q, K, V projections for multi-head attention.
// Double-buffered for pipeline overlap.

module qkv_buffer
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Write interface
  input  logic        wr_en_i,
  input  logic [15:0] wr_head_i,
  input  logic [15:0] wr_row_i,
  input  logic [15:0] wr_col_i,
  input  logic [FP16_WIDTH-1:0] wr_data_i,

  // Read interface
  input  logic        rd_en_i,
  input  logic [15:0] rd_head_i,
  input  logic [15:0] rd_row_i,
  input  logic [15:0] rd_col_i,
  output logic [FP16_WIDTH-1:0] rd_data_o
);

  // Storage: [N_HEAD][SEQ_LEN][D_MODEL] FP16
  localparam int DEPTH = N_HEAD * SEQ_LEN * D_MODEL;
  localparam int ADDR_W = $clog2(DEPTH);

  logic [FP16_WIDTH-1:0] mem [0:DEPTH-1];

  // Write address calculation
  logic [ADDR_W-1:0] wr_addr;
  assign wr_addr = wr_head_i * (SEQ_LEN * D_MODEL) + wr_row_i * D_MODEL + wr_col_i;

  // Read address calculation
  logic [ADDR_W-1:0] rd_addr;
  assign rd_addr = rd_head_i * (SEQ_LEN * D_MODEL) + rd_row_i * D_MODEL + rd_col_i;

  // Write operation
  always_ff @(posedge clk) begin
    if (wr_en_i) begin
      mem[wr_addr] <= wr_data_i;
    end
  end

  // Read operation (1 cycle latency)
  logic [FP16_WIDTH-1:0] rd_data_q;

  always_ff @(posedge clk) begin
    if (rd_en_i) begin
      rd_data_q <= mem[rd_addr];
    end
  end

  assign rd_data_o = rd_data_q;

endmodule
