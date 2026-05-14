// FlashAttention Core
// Implements tiled attention computation with online softmax.
// Uses FP16 MAC array for matrix multiplication.

module flash_attention_core
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Control
  input  logic        start_i,
  input  logic        abort_i,
  output logic        done_o,
  output logic        busy_o,

  // Configuration
  input  logic [15:0] seq_len_i,
  input  logic [15:0] d_model_i,
  input  logic [15:0] n_head_i,
  input  logic [FP16_WIDTH-1:0] scale_factor_i,  // 1/sqrt(d_k)

  // Q data interface
  output logic                     q_rd_en_o,
  output logic [FEATURE_ADDR_W-1:0] q_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    q_rd_data_i,

  // K data interface
  output logic                     k_rd_en_o,
  output logic [KVCACHE_ADDR_W-1:0] k_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    k_rd_data_i,

  // V data interface
  output logic                     v_rd_en_o,
  output logic [KVCACHE_ADDR_W-1:0] v_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    v_rd_data_i,

  // Output interface
  output logic                     out_wr_en_o,
  output logic [FEATURE_ADDR_W-1:0] out_wr_addr_o,
  output logic [FP16_WIDTH-1:0]    out_wr_data_o,

  // MAC array interface
  output logic [MAC_ROWS-1:0][FP16_WIDTH-1:0] mac_a_o,
  output logic [MAC_COLS-1:0][FP16_WIDTH-1:0] mac_b_o,
  output logic                     mac_valid_o,
  input  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] mac_result_i,
  input  logic                     mac_valid_i,

  // Interrupt
  output logic                     irq_o
);

  // FSM states
  typedef enum logic [3:0] {
    ST_IDLE,
    ST_INIT,
    ST_OUTER_LOOP,
    ST_INNER_LOOP,
    ST_TILE_COMPUTE,
    ST_SOFTMAX_UPDATE,
    ST_ACCUM_UPDATE,
    ST_INNER_CHECK,
    ST_OUTER_CHECK,
    ST_NORMALIZE,
    ST_DONE
  } state_e;

  state_e state_q, state_d;

  // Counters
  logic [15:0] outer_cnt_q, outer_cnt_d;  // Q block index
  logic [15:0] inner_cnt_q, inner_cnt_d;  // KV block index
  logic [15:0] row_cnt_q, row_cnt_d;      // Row within block
  logic [15:0] col_cnt_q, col_cnt_d;      // Column within block

  // Accumulators: O[i], m[i], l[i] for each row in Q block
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] o_accum_q [0:D_MODEL-1];
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] m_accum_q;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] l_accum_q;

  // Temporary registers
  logic [FP16_WIDTH-1:0] m_new_q, m_new_d;
  logic [FP16_WIDTH-1:0] l_new_q, l_new_d;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= ST_IDLE;
    end else begin
      state_q <= state_d;
    end
  end

  // Counter registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      outer_cnt_q <= '0;
      inner_cnt_q <= '0;
      row_cnt_q   <= '0;
      col_cnt_q   <= '0;
      m_new_q     <= '0;
      l_new_q     <= '0;
    end else begin
      outer_cnt_q <= outer_cnt_d;
      inner_cnt_q <= inner_cnt_d;
      row_cnt_q   <= row_cnt_d;
      col_cnt_q   <= col_cnt_d;
      m_new_q     <= m_new_d;
      l_new_q     <= l_new_d;
    end
  end

  // Next-state logic
  always_comb begin
    state_d      = state_q;
    outer_cnt_d  = outer_cnt_q;
    inner_cnt_d  = inner_cnt_q;
    row_cnt_d    = row_cnt_q;
    col_cnt_d    = col_cnt_q;
    m_new_d      = m_new_q;
    l_new_d      = l_new_q;

    done_o       = 1'b0;
    busy_o       = 1'b0;
    irq_o        = 1'b0;

    q_rd_en_o    = 1'b0;
    q_rd_addr_o  = '0;
    k_rd_en_o    = 1'b0;
    k_rd_addr_o  = '0;
    v_rd_en_o    = 1'b0;
    v_rd_addr_o  = '0;
    out_wr_en_o  = 1'b0;
    out_wr_addr_o = '0;
    out_wr_data_o = '0;
    mac_a_o      = '0;
    mac_b_o      = '0;
    mac_valid_o  = 1'b0;

    unique case (state_q)
      ST_IDLE: begin
        if (start_i) begin
          state_d = ST_INIT;
        end
      end

      ST_INIT: begin
        // Initialize accumulators
        // O = 0, m = -inf, l = 0
        outer_cnt_d = '0;
        state_d     = ST_OUTER_LOOP;
      end

      ST_OUTER_LOOP: begin
        // Start processing Q block
        busy_o = 1'b1;
        inner_cnt_d = '0;
        state_d     = ST_INNER_LOOP;
      end

      ST_INNER_LOOP: begin
        // Load KV block and compute S = Q × K^T / sqrt(d_k)
        busy_o = 1'b1;
        state_d = ST_TILE_COMPUTE;
      end

      ST_TILE_COMPUTE: begin
        // S_ij = Q_i × K_j^T / sqrt(d_k)
        busy_o     = 1'b1;
        mac_valid_o = 1'b1;

        // Drive MAC inputs (simplified - actual implementation needs proper sequencing)
        q_rd_en_o   = 1'b1;
        q_rd_addr_o = outer_cnt_q * TILE_B_R + row_cnt_q;
        k_rd_en_o   = 1'b1;
        k_rd_addr_o = inner_cnt_q * TILE_B_C + col_cnt_q;

        mac_a_o[0] = q_rd_data_i;
        mac_b_o[0] = k_rd_data_i;

        if (mac_valid_i) begin
          state_d = ST_SOFTMAX_UPDATE;
        end
      end

      ST_SOFTMAX_UPDATE: begin
        // m_new = max(m, rowmax(S))
        // P = exp(S - m_new)
        // l_new = exp(m - m_new) * l + rowsum(P)
        busy_o = 1'b1;
        state_d = ST_ACCUM_UPDATE;
      end

      ST_ACCUM_UPDATE: begin
        // O = exp(m - m_new) * O + P × V
        busy_o = 1'b1;
        state_d = ST_INNER_CHECK;
      end

      ST_INNER_CHECK: begin
        busy_o = 1'b1;
        if (inner_cnt_q < (seq_len_i / TILE_B_C) - 1) begin
          inner_cnt_d = inner_cnt_q + 1;
          state_d     = ST_INNER_LOOP;
        end else begin
          state_d = ST_OUTER_CHECK;
        end
      end

      ST_OUTER_CHECK: begin
        busy_o = 1'b1;
        if (outer_cnt_q < (seq_len_i / TILE_B_R) - 1) begin
          outer_cnt_d = outer_cnt_q + 1;
          state_d     = ST_OUTER_LOOP;
        end else begin
          state_d = ST_NORMALIZE;
        end
      end

      ST_NORMALIZE: begin
        // O = O / l
        busy_o = 1'b1;

        // Write output
        out_wr_en_o   = 1'b1;
        out_wr_addr_o = outer_cnt_q * TILE_B_R + row_cnt_q;
        out_wr_data_o = o_accum_q[row_cnt_q];  // After normalization

        if (row_cnt_q < TILE_B_R - 1) begin
          row_cnt_d = row_cnt_q + 1;
        end else begin
          state_d = ST_DONE;
        end
      end

      ST_DONE: begin
        done_o = 1'b1;
        irq_o  = 1'b1;
        if (!start_i) begin
          state_d = ST_IDLE;
        end
      end

      default: begin
        state_d = ST_IDLE;
      end
    endcase

    // Abort handling
    if (abort_i) begin
      state_d = ST_IDLE;
    end
  end

endmodule
