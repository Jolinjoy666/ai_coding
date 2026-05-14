// FlashAttention Core
// Computes: O = softmax(Q*K^T/sqrt(d_k)) * V
// Memory: Q in Feature SRAM[0..63], K in KV[0..63], V in KV[64..127]
//         O written to Feature SRAM[128..191]

module flash_attention_core
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start_i,
  input  logic        abort_i,
  output logic        done_o,
  output logic        busy_o,

  input  logic [15:0] seq_len_i,
  input  logic [15:0] d_model_i,
  input  logic [15:0] n_head_i,
  input  logic [FP16_WIDTH-1:0] scale_factor_i,

  output logic                     q_rd_en_o,
  output logic [FEATURE_ADDR_W-1:0] q_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    q_rd_data_i,

  output logic                     k_rd_en_o,
  output logic [KVCACHE_ADDR_W-1:0] k_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    k_rd_data_i,

  output logic                     v_rd_en_o,
  output logic [KVCACHE_ADDR_W-1:0] v_rd_addr_o,
  input  logic [FP16_WIDTH-1:0]    v_rd_data_i,

  output logic                     out_wr_en_o,
  output logic [FEATURE_ADDR_W-1:0] out_wr_addr_o,
  output logic [FP16_WIDTH-1:0]    out_wr_data_o,

  output logic [MAC_ROWS-1:0][FP16_WIDTH-1:0] mac_a_o,
  output logic [MAC_COLS-1:0][FP16_WIDTH-1:0] mac_b_o,
  output logic                     mac_valid_o,
  output logic                     mac_clear_o,
  input  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] mac_result_i,
  input  logic                     mac_valid_i,

  output logic                     irq_o
);

  typedef enum logic [3:0] {
    ST_IDLE, ST_INIT,
    ST_LOAD_QK, ST_WAIT_S, ST_COLLECT_S,
    ST_CALC_SOFTMAX, ST_SOFTMAX_WAIT,
    ST_LOAD_PV, ST_WAIT_PV, ST_UPDATE_O,
    ST_NORMALIZE, ST_DONE
  } state_e;

  state_e state_q, state_d;

  // Counters
  logic [15:0] head_cnt_q, head_cnt_d;
  logic [15:0] tile_row_q, tile_row_d;
  logic [15:0] inner_cnt_q, inner_cnt_d;
  logic [3:0]  cnt_q, cnt_d;
  logic [4:0]  norm_cnt_q, norm_cnt_d;

  // Config
  logic [15:0] head_dim_q, head_dim_d;
  logic [FEATURE_ADDR_W-1:0] o_base_q, o_base_d;

  // Softmax accumulators
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] m_accum_q, m_accum_d;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] l_accum_q, l_accum_d;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] m_new_q, m_new_d;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] l_new_q, l_new_d;

  // Tile buffers
  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] S_tile_q;
  logic [TILE_B_R-1:0][TILE_B_C-1:0][FP16_WIDTH-1:0] P_tile_q, P_tile_d;

  // O accumulator (registered)
  logic o_accum_wr;
  logic [1:0] o_accum_col;
  logic [TILE_B_R-1:0][TILE_B_C-1:0][FP16_WIDTH-1:0] o_accum_q;

  // Normalize pipeline
  logic [FP16_WIDTH-1:0] recip_q;
  logic [FP16_WIDTH-1:0] mul_out_q;
  logic mul_valid_q;

  // ---- Exp LUTs ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] exp_in, exp_out;
  logic [TILE_B_R-1:0] exp_valid_in, exp_valid_out;

  genvar gi;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_exp
      fp16_exp_lut u_exp (
        .clk(clk), .rst_n(rst_n),
        .x_i(exp_in[gi]), .valid_i(exp_valid_in[gi]),
        .exp_o(exp_out[gi]), .valid_o(exp_valid_out[gi])
      );
    end
  endgenerate

  // ---- Rowmax (combinational, from S_tile_q) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] rowmax_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_rmax
      fp16_rowmax #(.WIDTH(TILE_B_C)) u_rm (
        .data_i(S_tile_q[gi]), .max_o(rowmax_out[gi])
      );
    end
  endgenerate

  // ---- m_new = max(m_accum, rowmax) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] m_new_cmp;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_mcmp
      fp16_comparator u_c (
        .a_i(m_accum_q[gi]), .b_i(rowmax_out[gi]), .max_o(m_new_cmp[gi])
      );
    end
  endgenerate

  // ---- Subtractor: S - m_new for exp input ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] sub_a, sub_b, sub_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_sub
      fp16_adder u_sub (
        .a_i(sub_a[gi]),
        .b_i({~sub_b[gi][15], sub_b[gi][14:0]}),
        .sum_o(sub_out[gi]), .overflow_o(), .underflow_o()
      );
    end
  endgenerate

  // ---- Rowsum (combinational, from P_tile_q) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] rowsum_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_rsum
      fp16_rowsum #(.WIDTH(TILE_B_C)) u_rs (
        .data_i(P_tile_q[gi]), .sum_o(rowsum_out[gi])
      );
    end
  endgenerate

  // ---- Reciprocal ----
  logic [FP16_WIDTH-1:0] recip_in, recip_out;
  logic recip_valid_in, recip_valid_out;
  fp16_reciprocal u_recip (
    .clk(clk), .rst_n(rst_n),
    .x_i(recip_in), .valid_i(recip_valid_in),
    .recip_o(recip_out), .valid_o(recip_valid_out)
  );

  // ---- Multiplier ----
  logic [FP16_WIDTH-1:0] mul_a, mul_b, mul_out;
  logic mul_valid;
  fp16_multiplier u_mul (
    .clk(clk), .rst_n(rst_n),
    .a_i(mul_a), .b_i(mul_b),
    .product_o(mul_out), .overflow_o(), .underflow_o()
  );

  // ---- Registers ----
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q      <= ST_IDLE;
      head_cnt_q   <= 0;
      tile_row_q   <= 0;
      inner_cnt_q  <= 0;
      cnt_q        <= 0;
      norm_cnt_q   <= 0;
      head_dim_q   <= 0;
      o_base_q     <= 0;
      m_accum_q    <= '{default: 16'hFC00};
      l_accum_q    <= 0;
      m_new_q      <= 0;
      l_new_q      <= 0;
      P_tile_q     <= 0;
      S_tile_q     <= 0;
      o_accum_q    <= 0;
      recip_q      <= 0;
      mul_out_q    <= 0;
      mul_valid_q  <= 0;
    end else begin
      state_q      <= state_d;
      head_cnt_q   <= head_cnt_d;
      tile_row_q   <= tile_row_d;
      inner_cnt_q  <= inner_cnt_d;
      cnt_q        <= cnt_d;
      norm_cnt_q   <= norm_cnt_d;
      head_dim_q   <= head_dim_d;
      o_base_q     <= o_base_d;
      m_accum_q    <= m_accum_d;
      l_accum_q    <= l_accum_d;
      m_new_q      <= m_new_d;
      l_new_q      <= l_new_d;
      P_tile_q     <= P_tile_d;
      recip_q      <= recip_out;
      mul_out_q    <= mul_out;
      mul_valid_q  <= mul_valid;

      // Capture S tile from MAC when valid
      if (state_q == ST_WAIT_S && mac_valid_i) begin
        S_tile_q <= mac_result_i;
      end

      // O accumulator update
      if (o_accum_wr) begin
        for (int r = 0; r < TILE_B_R; r++)
          o_accum_q[r][o_accum_col] <= mac_result_i[r][o_accum_col];
      end
    end
  end

  // ---- Output ----
  assign done_o = (state_q == ST_DONE);
  assign busy_o = (state_q != ST_IDLE) && (state_q != ST_DONE);
  assign irq_o  = (state_q == ST_DONE);

  // ---- Combinational ----
  always_comb begin
    state_d      = state_q;
    head_cnt_d   = head_cnt_q;
    tile_row_d   = tile_row_q;
    inner_cnt_d  = inner_cnt_q;
    cnt_d        = cnt_q;
    norm_cnt_d   = norm_cnt_q;
    head_dim_d   = head_dim_q;
    o_base_d     = o_base_q;
    m_accum_d    = m_accum_q;
    l_accum_d    = l_accum_q;
    m_new_d      = m_new_q;
    l_new_d      = l_new_q;
    P_tile_d     = P_tile_q;
    o_accum_wr   = 0;
    o_accum_col  = 0;

    q_rd_en_o    = 0; q_rd_addr_o  = 0;
    k_rd_en_o    = 0; k_rd_addr_o  = 0;
    v_rd_en_o    = 0; v_rd_addr_o  = 0;
    out_wr_en_o  = 0; out_wr_addr_o = 0; out_wr_data_o = 0;
    mac_a_o      = 0; mac_b_o      = 0;
    mac_valid_o  = 0; mac_clear_o  = 0;
    exp_in       = 0; exp_valid_in = 0;
    sub_a        = 0; sub_b        = 0;
    recip_in     = 0; recip_valid_in = 0;
    mul_a        = 0; mul_b        = 0; mul_valid = 0;

    unique case (state_q)
      // ============================================================
      ST_IDLE: begin
        if (start_i) state_d = ST_INIT;
      end

      // ============================================================
      ST_INIT: begin
        head_cnt_d  = 0;
        tile_row_d  = 0;
        inner_cnt_d = 0;
        cnt_d       = 0;
        head_dim_d  = d_model_i / n_head_i;
        o_base_d    = FEATURE_ADDR_W'(128);
        m_accum_d   = '{default: 16'hFC00};
        l_accum_d   = 0;
        state_d     = ST_LOAD_QK;
      end

      // ============================================================
      ST_LOAD_QK: begin
        mac_clear_o = (cnt_q == 0);

        q_rd_en_o   = 1;
        q_rd_addr_o = FEATURE_ADDR_W'(head_cnt_q * head_dim_q)
                    + FEATURE_ADDR_W'(tile_row_q * TILE_B_R)
                    + FEATURE_ADDR_W'(cnt_q[2:0]);

        k_rd_en_o   = 1;
        k_rd_addr_o = KVCACHE_ADDR_W'(head_cnt_q * head_dim_q)
                    + KVCACHE_ADDR_W'(inner_cnt_q * TILE_B_C)
                    + KVCACHE_ADDR_W'(cnt_q[2:0]);

        mac_valid_o = 1;
        for (int r = 0; r < MAC_ROWS; r++) begin
          mac_a_o[r] = q_rd_data_i;
          mac_b_o[r] = k_rd_data_i;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd7) begin
          state_d = ST_WAIT_S;
          cnt_d   = 0;
        end
      end

      // ============================================================
      ST_WAIT_S: begin
        cnt_d = cnt_q + 1;
        if (mac_valid_i || cnt_q == 4'd4) begin
          state_d = ST_COLLECT_S;
          cnt_d   = 0;
        end
      end

      // ============================================================
      ST_COLLECT_S: begin
        // S_tile_q captured in registered block when mac_valid_i
        state_d = ST_CALC_SOFTMAX;
        cnt_d   = 0;
      end

      // ============================================================
      ST_CALC_SOFTMAX: begin
        // m_new = max(m_accum, rowmax(S))
        for (int r = 0; r < TILE_B_R; r++) begin
          m_new_d[r] = m_new_cmp[r];
        end

        // exp(S[row][col] - m_new) for all rows, one column per cycle
        for (int r = 0; r < TILE_B_R; r++) begin
          sub_a[r] = S_tile_q[r][cnt_q[1:0]];
          sub_b[r] = m_new_d[r];
          exp_in[r] = sub_out[r];
          exp_valid_in[r] = 1;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd3) begin
          state_d = ST_SOFTMAX_WAIT;
          cnt_d   = 0;
        end
      end

      // ============================================================
      ST_SOFTMAX_WAIT: begin
        // Collect exp output into P_tile
        for (int r = 0; r < TILE_B_R; r++) begin
          P_tile_d[r][cnt_q[1:0]] = exp_out[r];
        end

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd1) begin
          // rowsum is combinational from P_tile_q
          for (int r = 0; r < TILE_B_R; r++) begin
            if (m_accum_q[r] == 16'hFC00)
              l_new_d[r] = rowsum_out[r];
            else
              l_new_d[r] = l_accum_q[r];  // Simplified
          end
          state_d = ST_LOAD_PV;
          cnt_d   = 0;
        end
      end

      // ============================================================
      ST_LOAD_PV: begin
        mac_clear_o = (cnt_q == 0);

        v_rd_en_o   = 1;
        v_rd_addr_o = KVCACHE_ADDR_W'(head_cnt_q * head_dim_q)
                    + KVCACHE_ADDR_W'(64)
                    + KVCACHE_ADDR_W'(cnt_q[2:0])
                    + KVCACHE_ADDR_W'(inner_cnt_q * TILE_B_C);

        mac_valid_o = 1;
        for (int r = 0; r < MAC_ROWS; r++)
          mac_a_o[r] = P_tile_q[r][cnt_q[1:0]];
        for (int c = 0; c < MAC_COLS; c++)
          mac_b_o[c] = v_rd_data_i;

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd7) begin
          state_d = ST_WAIT_PV;
          cnt_d   = 0;
        end
      end

      // ============================================================
      ST_WAIT_PV: begin
        cnt_d = cnt_q + 1;
        if (mac_valid_i || cnt_q == 4'd4) begin
          state_d = ST_UPDATE_O;
        end
      end

      // ============================================================
      ST_UPDATE_O: begin
        // Update m/l accumulators
        for (int r = 0; r < TILE_B_R; r++) begin
          m_accum_d[r] = m_new_q[r];
          l_accum_d[r] = l_new_q[r];
        end

        // O accumulation (registered update)
        o_accum_wr  = 1;
        o_accum_col = inner_cnt_q[1:0];

        // Next inner or normalize
        if (inner_cnt_q < (seq_len_i / TILE_B_C) - 1) begin
          inner_cnt_d = inner_cnt_q + 1;
          state_d     = ST_LOAD_QK;
          cnt_d       = 0;
        end else begin
          state_d    = ST_NORMALIZE;
          norm_cnt_d = 0;
        end
      end

      // ============================================================
      // Normalize: O = O / l, write to output SRAM
      // Pipeline: [recip] -> [mul] -> [write]
      ST_NORMALIZE: begin
        case (norm_cnt_q[1:0])
          2'd0: begin
            recip_in = l_accum_q[norm_cnt_q[4:2]];
            recip_valid_in = 1;
          end
          2'd1: begin
            mul_a = o_accum_q[norm_cnt_q[4:2]][0];
            mul_b = recip_out;
            mul_valid = 1;
          end
          2'd2: begin
            mul_a = o_accum_q[norm_cnt_q[4:2]][1];
            mul_b = recip_q;
            mul_valid = 1;
            // Write col 0
            out_wr_en_o   = 1;
            out_wr_addr_o = o_base_q
                          + FEATURE_ADDR_W'(head_cnt_q * head_dim_q)
                          + FEATURE_ADDR_W'(tile_row_q * TILE_B_R + norm_cnt_q[4:2]);
            out_wr_data_o = mul_out_q;
          end
          2'd3: begin
            mul_a = o_accum_q[norm_cnt_q[4:2]][2];
            mul_b = recip_q;
            mul_valid = 1;
            // Write col 1
            out_wr_en_o   = 1;
            out_wr_addr_o = o_base_q
                          + FEATURE_ADDR_W'(head_cnt_q * head_dim_q)
                          + FEATURE_ADDR_W'(tile_row_q * TILE_B_R + norm_cnt_q[4:2])
                          + FEATURE_ADDR_W'(1);
            out_wr_data_o = mul_out_q;
          end
        endcase

        norm_cnt_d = norm_cnt_q + 1;

        // Extra writes for cols 2,3 using pipeline
        if (norm_cnt_q >= 5'd16 && norm_cnt_q <= 5'd17) begin
          out_wr_en_o   = 1;
          out_wr_addr_o = o_base_q
                        + FEATURE_ADDR_W'(head_cnt_q * head_dim_q)
                        + FEATURE_ADDR_W'(tile_row_q * TILE_B_R + 3)
                        + FEATURE_ADDR_W'(norm_cnt_q - 5'd14);
          out_wr_data_o = mul_out_q;
        end

        if (norm_cnt_q == 5'd19) begin
          // Done with this Q tile
          if (tile_row_q < (seq_len_i / TILE_B_R) - 1) begin
            tile_row_d  = tile_row_q + 1;
            inner_cnt_d = 0;
            m_accum_d   = '{default: 16'hFC00};
            l_accum_d   = 0;
            state_d     = ST_LOAD_QK;
            cnt_d       = 0;
          end else if (head_cnt_q < n_head_i - 1) begin
            head_cnt_d  = head_cnt_q + 1;
            tile_row_d  = 0;
            inner_cnt_d = 0;
            m_accum_d   = '{default: 16'hFC00};
            l_accum_d   = 0;
            state_d     = ST_LOAD_QK;
            cnt_d       = 0;
          end else begin
            state_d = ST_DONE;
          end
        end
      end

      // ============================================================
      ST_DONE: begin
        if (!start_i) state_d = ST_IDLE;
      end

      default: state_d = ST_IDLE;
    endcase

    if (abort_i) state_d = ST_IDLE;
  end

endmodule
