// FlashAttention Core
// Computes: O = softmax(Q*K^T/sqrt(d_k)) * V
// Memory layout (FP16 words):
//   Q: Feature SRAM[row*16 + h*8 + k]
//   K: KV-Cache SRAM[row*16 + h*8 + k]
//   V: KV-Cache SRAM[64 + row*16 + h*8 + c]
//   O: Feature SRAM[128 + row*16 + h*8 + c]
// Online softmax with correction scaling for multi-tile accumulation.
// Each start_i processes ONE head (selected by head_idx_i).

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
  input  logic [15:0] head_idx_i,
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

  // ---- FSM States ----
  typedef enum logic [4:0] {
    ST_IDLE, ST_INIT,
    ST_LOAD_QK, ST_DRIVE_S, ST_WAIT_S, ST_COLLECT_S,
    ST_SCALE_S,
    ST_CALC_SOFTMAX, ST_SOFTMAX_WAIT,
    ST_LOAD_PV, ST_DRIVE_PV, ST_WAIT_PV, ST_UPDATE_O,
    ST_NORMALIZE, ST_DONE
  } state_e;

  state_e state_q, state_d;

  // ---- Counters ----
  logic [15:0] tile_row_q, tile_row_d;
  logic [15:0] inner_cnt_q, inner_cnt_d;
  logic [5:0]  cnt_q, cnt_d;
  logic [2:0]  mac_k_cnt_q, mac_k_cnt_d;
  logic        pv_col_q, pv_col_d;
  logic [3:0]  norm_cnt_q, norm_cnt_d;
  logic [1:0]  norm_row_q, norm_row_d;
  logic [4:0]  wr_scale_cnt_q, wr_scale_cnt_d;
  logic [4:0]  wr_o_cnt_q, wr_o_cnt_d;

  // Dual-pass / dual-group registers
  logic k_pass_q, k_pass_d;       // S computation K pass: 0=K[0..3], 1=K[4..7]
  logic pv_group_q, pv_group_d;   // PV V column group: 0=cols 0-3, 1=cols 4-7
  logic pv_kpass_q, pv_kpass_d;   // PV K pass: 0=P[0..3]*V[0..3], 1=P[4..7]*V[4..7]

  // Done persistence
  logic done_o_q;

  // ---- Q/K/V Buffers ----
  logic [MAC_ROWS-1:0][FP16_WIDTH-1:0] q_buf_q, q_buf_d;
  logic [MAC_COLS-1:0][FP16_WIDTH-1:0] k_buf_q, k_buf_d;
  logic [MAC_COLS-1:0][FP16_WIDTH-1:0] v_buf_q, v_buf_d;

  // ---- Softmax Accumulators ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] m_accum_q, m_accum_d;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] l_accum_q, l_accum_d;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] m_new_q, m_new_d;
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] l_new_q, l_new_d;

  // ---- Tile Buffers (4x8 for S, S_scaled, P) ----
  logic [MAC_ROWS-1:0][2*MAC_COLS-1:0][FP16_WIDTH-1:0] S_tile_q, S_tile_d;
  logic [MAC_ROWS-1:0][2*MAC_COLS-1:0][FP16_WIDTH-1:0] S_scaled_q, S_scaled_d;
  logic [TILE_B_R-1:0][2*TILE_B_C-1:0][FP16_WIDTH-1:0] P_tile_q, P_tile_d;

  // ---- O Accumulator (4 rows x 8 cols = full HEAD_DIM) ----
  logic o_accum_wr;
  logic [TILE_B_R-1:0][2*TILE_B_C-1:0][FP16_WIDTH-1:0] o_accum_q, o_accum_d;

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

  // Correction values for all 4 rows
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] corr_all_q, corr_all_d;

  // ---- Rowmax (combinational, from S_scaled_q, WIDTH=8) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] rowmax_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_rmax
      fp16_rowmax #(.WIDTH(2*TILE_B_C)) u_rm (
        .data_i(S_scaled_q[gi]), .max_o(rowmax_out[gi])
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

  // ---- Subtractor (a - b = a + negate(b)) ----
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

  // ---- Rowsum (combinational, from P_tile_q, WIDTH=8) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] rowsum_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_rsum
      fp16_rowsum #(.WIDTH(2*TILE_B_C)) u_rs (
        .data_i(P_tile_q[gi]), .sum_o(rowsum_out[gi])
      );
    end
  endgenerate

  // ---- Reciprocal (registered, 1-cycle latency) ----
  logic [FP16_WIDTH-1:0] recip_in, recip_out;
  logic recip_valid_in, recip_valid_out;
  fp16_reciprocal u_recip (
    .clk(clk), .rst_n(rst_n),
    .x_i(recip_in), .valid_i(recip_valid_in),
    .recip_o(recip_out), .valid_o(recip_valid_out)
  );

  // ---- Multiplier (registered, 3-stage pipeline) ----
  logic [FP16_WIDTH-1:0] mul_a, mul_b, mul_out;
  fp16_multiplier u_mul (
    .clk(clk), .rst_n(rst_n),
    .a_i(mul_a), .b_i(mul_b),
    .product_o(mul_out), .overflow_o(), .underflow_o()
  );

  // ---- l_new adder (combinational) ----
  logic [FP16_WIDTH-1:0] lnew_a, lnew_b, lnew_sum;
  fp16_adder u_lnew_add (
    .a_i(lnew_a), .b_i(lnew_b),
    .sum_o(lnew_sum), .overflow_o(), .underflow_o()
  );

  // ---- PV update adder: mul_out + mac_result (combinational) ----
  logic [FP16_WIDTH-1:0] pv_add_a, pv_add_b, pv_add_sum;
  fp16_adder u_pv_add (
    .a_i(pv_add_a), .b_i(pv_add_b),
    .sum_o(pv_add_sum), .overflow_o(), .underflow_o()
  );

  // ---- Sequential Registers ----
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q      <= ST_IDLE;
      tile_row_q   <= 0;
      inner_cnt_q  <= 0;
      cnt_q        <= 0;
      mac_k_cnt_q  <= 0;
      pv_col_q     <= 0;
      norm_cnt_q   <= 0;
      norm_row_q   <= 0;
      wr_scale_cnt_q <= 0;
      wr_o_cnt_q   <= 0;
      k_pass_q     <= 1'b0;
      pv_group_q   <= 1'b0;
      pv_kpass_q   <= 1'b0;
      done_o_q     <= 1'b0;
      q_buf_q      <= 0;
      k_buf_q      <= 0;
      v_buf_q      <= 0;
      m_accum_q    <= '{default: 16'hFC00};
      l_accum_q    <= 0;
      m_new_q      <= 0;
      l_new_q      <= 0;
      S_tile_q     <= 0;
      S_scaled_q   <= 0;
      P_tile_q     <= 0;
      o_accum_q    <= 0;
      corr_all_q   <= 0;
    end else begin
      state_q      <= state_d;
      tile_row_q   <= tile_row_d;
      inner_cnt_q  <= inner_cnt_d;
      cnt_q        <= cnt_d;
      mac_k_cnt_q  <= mac_k_cnt_d;
      pv_col_q     <= pv_col_d;
      norm_cnt_q   <= norm_cnt_d;
      norm_row_q   <= norm_row_d;
      wr_scale_cnt_q <= wr_scale_cnt_d;
      wr_o_cnt_q   <= wr_o_cnt_d;
      k_pass_q     <= k_pass_d;
      pv_group_q   <= pv_group_d;
      pv_kpass_q   <= pv_kpass_d;
      q_buf_q      <= q_buf_d;
      k_buf_q      <= k_buf_d;
      v_buf_q      <= v_buf_d;
      m_accum_q    <= m_accum_d;
      l_accum_q    <= l_accum_d;
      m_new_q      <= m_new_d;
      l_new_q      <= l_new_d;
      S_tile_q     <= S_tile_d;
      S_scaled_q   <= S_scaled_d;
      P_tile_q     <= P_tile_d;
      corr_all_q   <= corr_all_d;

      o_accum_q <= o_accum_d;

      // Latch l_new values during ST_SOFTMAX_WAIT
      // Pipeline: mul feed@3-6 → product_o NBA@5-8 → mul_out readable@6-9
      // fp16_multiplier: 3 always_ff stages, feed@N → product_o pre-NBA valid at N+3
      // lnew_a=mul_out (driven by cnt_q 6-9), lnew_b=rowsum (combinational)
      // At posedge, always_ff reads PRE-NBA cnt_q and mul_out:
      //   posedge (cnt_q=6): mul_out=corr[0]*l[0] → lnew = mul_out + rowsum[0] → l_new[0]
      //   posedge (cnt_q=7): mul_out=corr[1]*l[1] → lnew = mul_out + rowsum[1] → l_new[1]
      //   posedge (cnt_q=8): mul_out=corr[2]*l[2] → lnew = mul_out + rowsum[2] → l_new[2]
      //   posedge (cnt_q=9): mul_out=corr[3]*l[3] → lnew = mul_out + rowsum[3] → l_new[3]
      if (state_q == ST_SOFTMAX_WAIT) begin
        if (cnt_q == 4'd6)  l_new_q[0] <= lnew_sum;
        if (cnt_q == 4'd7)  l_new_q[1] <= lnew_sum;
        if (cnt_q == 4'd8)  l_new_q[2] <= lnew_sum;
        if (cnt_q == 4'd9)  l_new_q[3] <= lnew_sum;
      end

      // Done persistence
      if (state_q == ST_DONE) done_o_q <= 1'b1;
      if (start_i)            done_o_q <= 1'b0;
    end
  end

  // ---- Output Assignments ----
  assign done_o = (state_q == ST_DONE) || (state_q == ST_IDLE && done_o_q);
  assign busy_o = (state_q != ST_IDLE) && (state_q != ST_DONE);
  assign irq_o  = (state_q == ST_DONE);

  // ---- Combinational Next-State Logic ----
  always_comb begin
    state_d      = state_q;
    tile_row_d   = tile_row_q;
    inner_cnt_d  = inner_cnt_q;
    cnt_d        = cnt_q;
    mac_k_cnt_d  = mac_k_cnt_q;
    pv_col_d     = pv_col_q;
    norm_cnt_d   = norm_cnt_q;
    norm_row_d   = norm_row_q;
    wr_scale_cnt_d = wr_scale_cnt_q;
    wr_o_cnt_d   = wr_o_cnt_q;
    k_pass_d     = k_pass_q;
    pv_group_d   = pv_group_q;
    pv_kpass_d   = pv_kpass_q;
    q_buf_d      = q_buf_q;
    k_buf_d      = k_buf_q;
    v_buf_d      = v_buf_q;
    m_accum_d    = m_accum_q;
    l_accum_d    = l_accum_q;
    m_new_d      = m_new_q;
    l_new_d      = l_new_q;
    S_tile_d     = S_tile_q;
    S_scaled_d   = S_scaled_q;
    P_tile_d     = P_tile_q;
    corr_all_d   = corr_all_q;
    o_accum_wr   = 0;
    o_accum_d    = o_accum_q;

    q_rd_en_o    = 0; q_rd_addr_o  = 0;
    k_rd_en_o    = 0; k_rd_addr_o  = 0;
    v_rd_en_o    = 0; v_rd_addr_o  = 0;
    out_wr_en_o  = 0; out_wr_addr_o = 0; out_wr_data_o = 0;
    mac_a_o      = 0; mac_b_o      = 0;
    mac_valid_o  = 0; mac_clear_o  = 0;
    exp_in       = 0; exp_valid_in = 0;
    sub_a        = 0; sub_b        = 0;
    recip_in     = 0; recip_valid_in = 0;
    mul_a        = 0; mul_b        = 0;
    lnew_a       = 0; lnew_b       = 0;
    pv_add_a     = 0; pv_add_b     = 0;

    unique case (state_q)

      // ============================================================
      // ST_IDLE: Wait for start
      // ============================================================
      ST_IDLE: begin
        if (start_i) state_d = ST_INIT;
      end

      // ============================================================
      // ST_INIT: Reset counters for one head
      // ============================================================
      ST_INIT: begin
        tile_row_d  = 0;
        inner_cnt_d = 0;
        cnt_d       = 0;
        mac_k_cnt_d = 0;
        k_pass_d    = 0;
        pv_group_d  = 0;
        pv_kpass_d  = 0;
        m_accum_d   = '{default: 16'hFC00};
        l_accum_d   = 0;
        state_d     = ST_LOAD_QK;
      end

      // ============================================================
      // ST_LOAD_QK: Load Q and K from SRAM into buffers (4 cycles)
      //   Dual-pass: k_pass_q=0 loads K[0..3], k_pass_q=1 loads K[4..7]
      //   MAC cleared at start of each pass.
      // ============================================================
      ST_LOAD_QK: begin
        mac_clear_o = (cnt_q == 0) && (mac_k_cnt_q == 0);

        q_rd_en_o   = 1;
        q_rd_addr_o = FEATURE_ADDR_W'((tile_row_q * TILE_B_R + cnt_q) * D_MODEL)
                    + FEATURE_ADDR_W'(head_idx_i * HEAD_DIM)
                    + FEATURE_ADDR_W'(mac_k_cnt_q);

        k_rd_en_o   = 1;
        k_rd_addr_o = KVCACHE_ADDR_W'((inner_cnt_q * TILE_B_C + cnt_q + k_pass_q * TILE_B_C) * D_MODEL)
                    + KVCACHE_ADDR_W'(head_idx_i * HEAD_DIM)
                    + KVCACHE_ADDR_W'(mac_k_cnt_q);

        // Capture SRAM read data (combinational, available same cycle)
        // Zero K data when row index exceeds SEQ_LEN (out of bounds)
        q_buf_d[cnt_q] = q_rd_data_i;
        if ((inner_cnt_q * TILE_B_C + cnt_q + k_pass_q * TILE_B_C) >= seq_len_i)
          k_buf_d[cnt_q] = '0;
        else
          k_buf_d[cnt_q] = k_rd_data_i;

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd3) begin
          state_d = ST_DRIVE_S;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_DRIVE_S: Drive MAC with buffered Q and K (1 cycle)
      // ============================================================
      ST_DRIVE_S: begin
        for (int r = 0; r < MAC_ROWS; r++)
          mac_a_o[r] = q_buf_q[r];
        for (int c = 0; c < MAC_COLS; c++)
          mac_b_o[c] = k_buf_q[c];
        mac_valid_o = 1;

        mac_k_cnt_d = mac_k_cnt_q + 1;
        if (mac_k_cnt_q == 3'd7) begin
          state_d     = ST_WAIT_S;
          mac_k_cnt_d = 0;
          cnt_d       = 0;
        end else begin
          state_d = ST_LOAD_QK;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_WAIT_S: Wait for MAC pipeline to flush (4 cycles)
      //   Must wait full 4 cycles to flush all pipeline results.
      //   For pass 1 (8 items), valid_o's arrive during WAIT_S itself.
      //   Early exit on mac_valid_i would capture partial results.
      // ============================================================
      ST_WAIT_S: begin
        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd6) begin
          cnt_d       = 0;
          mac_k_cnt_d = 0;
          state_d     = ST_COLLECT_S;
        end
      end

      // ============================================================
      // ST_COLLECT_S: Capture S_tile from MAC result
      //   k_pass_q=0: S_tile[r][0..3] = mac_result[r][0..3]
      //   k_pass_q=1: S_tile[r][4..7] = mac_result[r][0..3]
      // ============================================================
      ST_COLLECT_S: begin
        if (k_pass_q == 0) begin
          for (int r = 0; r < MAC_ROWS; r++)
            for (int c = 0; c < MAC_COLS; c++)
              S_tile_d[r][c] = mac_result_i[r][c];
          k_pass_d    = 1;
          mac_k_cnt_d = 0;
          cnt_d       = 0;
          state_d     = ST_LOAD_QK;
        end else begin
          for (int r = 0; r < MAC_ROWS; r++)
            for (int c = 0; c < MAC_COLS; c++)
              S_tile_d[r][c + MAC_COLS] = mac_result_i[r][c];
          k_pass_d = 0;
          state_d  = ST_SCALE_S;
          cnt_d    = 0;
          wr_scale_cnt_d = 0;
        end
      end

      // ============================================================
      // ST_SCALE_S: S = S * scale_factor (35 cycles)
      //   32 elements: row = cnt_q[4:3], col = cnt_q[2:0]
      //   Pipeline: feed mul at cycles 0-31, capture at cycles 3-34
      // ============================================================
      ST_SCALE_S: begin
        // Feed multiplier with S_tile values (cycles 0-31)
        if (cnt_q <= 6'd31) begin
          mul_a = S_tile_q[cnt_q[4:3]][cnt_q[2:0]];
          mul_b = scale_factor_i;
        end

        // Capture multiplier output (3-stage pipeline latency)
        if (cnt_q >= 6'd3 && wr_scale_cnt_q <= 5'd31) begin
          S_scaled_d[wr_scale_cnt_q[4:3]][wr_scale_cnt_q[2:0]] = mul_out;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q >= 6'd3)
          wr_scale_cnt_d = wr_scale_cnt_q + 1;
        if (cnt_q == 6'd34) begin
          state_d = ST_CALC_SOFTMAX;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_CALC_SOFTMAX: Compute m_new and exp(S - m_new) (8 cycles)
      //   m_new = max(m_accum, rowmax(S_scaled))  — rowmax over 8 cols
      //   Feed exp(S[col]-m_new) at cnt=0..7; capture result at cnt=1..7
      //   (1-cycle LUT latency: feed@N → out@N+1)
      //   P[0..6] captured here; P[7] captured at SOFTMAX_WAIT cnt=0
      // ============================================================
      ST_CALC_SOFTMAX: begin
        // m_new = max(m_accum, rowmax(S_scaled)) — combinational, same every cycle
        for (int r = 0; r < TILE_B_R; r++)
          m_new_d[r] = m_new_cmp[r];

        // Capture P from previous cycle's exp feed (1-cycle LUT latency)
        if (cnt_q >= 4'd1) begin
          for (int r = 0; r < TILE_B_R; r++)
            P_tile_d[r][cnt_q[2:0] - 3'd1] = exp_out[r];
        end

        // Feed current column through subtractor → exp LUT
        for (int r = 0; r < TILE_B_R; r++) begin
          sub_a[r] = S_scaled_q[r][cnt_q[2:0]];
          sub_b[r] = m_new_d[r];
          exp_in[r] = sub_out[r];
          exp_valid_in[r] = 1;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd7) begin
          state_d = ST_SOFTMAX_WAIT;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_SOFTMAX_WAIT: Capture P[7], correction, l_new (11 cycles)
      //   cnt  0: Capture P[7] = exp_out (from CALC_SOFTMAX cnt=7 feed)
      //   cnt  1: Feed correction: exp(m_accum - m_new)
      //   cnt  2: Capture corr_all = exp_out; corr_all_q latched at posedge T+3
      //   cnt  3: corr_all_q stable; mul feed corr[0]*l_accum[0]
      //   cnt  4: mul feed corr[1]*l_accum[1]
      //   cnt  5: mul feed corr[2]*l_accum[2]
      //   cnt  6: mul feed corr[3]*l_accum[3]; mul_out=corr[0]*l[0] (3-cyc pipe);
      //           lnew[0] = mul_out + rowsum[0]; latched at posedge (cnt_q=6)
      //   cnt  7: mul_out=corr[1]*l[1]; lnew[1]; latched at posedge (cnt_q=7)
      //   cnt  8: mul_out=corr[2]*l[2]; lnew[2]; latched at posedge (cnt_q=8)
      //   cnt  9: mul_out=corr[3]*l[3]; lnew[3]; latched at posedge (cnt_q=9)
      //   cnt 10: → ST_LOAD_PV
      // ============================================================
      ST_SOFTMAX_WAIT: begin
        // cnt=0: Capture P col 7 (from CALC_SOFTMAX cnt=7 exp feed, 1-cycle latency)
        if (cnt_q == 4'd0) begin
          for (int r = 0; r < TILE_B_R; r++)
            P_tile_d[r][7] = exp_out[r];
        end

        // cnt=1: Feed correction factor to exp LUTs
        if (cnt_q == 4'd1) begin
          for (int r = 0; r < TILE_B_R; r++) begin
            sub_a[r] = m_accum_q[r];
            sub_b[r] = m_new_q[r];
            exp_in[r] = sub_out[r];
            exp_valid_in[r] = 1;
          end
        end

        // cnt=2: Capture correction values (1-cycle LUT latency from cnt=1 feed)
        if (cnt_q == 4'd2) begin
          corr_all_d = exp_out;
        end

        // cnt=3-6: mul = corr_all * l_accum (3-stage pipeline)
        //   feed@3→out@6, feed@4→out@7, feed@5→out@8, feed@6→out@9
        if (cnt_q == 4'd3) begin mul_a = corr_all_q[0]; mul_b = l_accum_q[0]; end
        if (cnt_q == 4'd4) begin mul_a = corr_all_q[1]; mul_b = l_accum_q[1]; end
        if (cnt_q == 4'd5) begin mul_a = corr_all_q[2]; mul_b = l_accum_q[2]; end
        if (cnt_q == 4'd6) begin mul_a = corr_all_q[3]; mul_b = l_accum_q[3]; end

        // cnt=6-9: lnew = mul_out + rowsum (combinational add)
        if (cnt_q == 4'd6) begin lnew_a = mul_out; lnew_b = rowsum_out[0]; end
        if (cnt_q == 4'd7) begin lnew_a = mul_out; lnew_b = rowsum_out[1]; end
        if (cnt_q == 4'd8) begin lnew_a = mul_out; lnew_b = rowsum_out[2]; end
        if (cnt_q == 4'd9) begin lnew_a = mul_out; lnew_b = rowsum_out[3]; end

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd10) begin
          state_d     = ST_LOAD_PV;
          cnt_d       = 0;
          mac_k_cnt_d = 0;
          pv_group_d  = 0;
          pv_kpass_d  = 0;
        end
      end

      // ============================================================
      // ST_LOAD_PV: Load V from KV-Cache into buffer (4 cycles)
      //   pv_kpass_q=0: V rows inner*4+0..3, pv_kpass_q=1: V rows inner*4+4..7
      //   pv_group_q=0: V cols head*8+0..3, pv_group_q=1: V cols head*8+4..7
      //   MAC cleared at start of pv_kpass 0 only (accumulate across k-passes).
      // ============================================================
      ST_LOAD_PV: begin
        mac_clear_o = (cnt_q == 0) && (mac_k_cnt_q == 0) && (pv_kpass_q == 0);

        v_rd_en_o   = 1;
        v_rd_addr_o = KVCACHE_ADDR_W'(128)
                    + KVCACHE_ADDR_W'((inner_cnt_q * TILE_B_C + mac_k_cnt_q + pv_kpass_q * TILE_B_C) * D_MODEL)
                    + KVCACHE_ADDR_W'(head_idx_i * HEAD_DIM)
                    + KVCACHE_ADDR_W'(pv_group_q * TILE_B_C)
                    + KVCACHE_ADDR_W'(cnt_q);

        // Capture V data (combinational, available same cycle)
        // Zero V data when row index exceeds SEQ_LEN (out of bounds)
        if ((inner_cnt_q * TILE_B_C + mac_k_cnt_q + pv_kpass_q * TILE_B_C) >= seq_len_i)
          v_buf_d[cnt_q] = '0;
        else
          v_buf_d[cnt_q] = v_rd_data_i;

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd3) begin
          state_d = ST_DRIVE_PV;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_DRIVE_PV: Drive MAC for P*V (1 cycle)
      //   P index uses pv_kpass_q (not pv_group_q) for k-group selection.
      //   After k=3: if pv_kpass==0, start pv_kpass=1 (same col group).
      //   After k=3 with pv_kpass==1: go to WAIT_PV.
      // ============================================================
      ST_DRIVE_PV: begin
        for (int r = 0; r < MAC_ROWS; r++)
          mac_a_o[r] = P_tile_q[r][mac_k_cnt_q + pv_kpass_q * TILE_B_C];
        for (int c = 0; c < MAC_COLS; c++)
          mac_b_o[c] = v_buf_q[c];
        mac_valid_o = 1;

        mac_k_cnt_d = mac_k_cnt_q + 1;
        if (mac_k_cnt_q == 3'd3) begin
          mac_k_cnt_d = 0;
          cnt_d       = 0;
          if (pv_kpass_q == 0) begin
            // Start second k-pass (P[4..7]*V[4..7]) for same column group
            pv_kpass_d = 1;
            state_d    = ST_LOAD_PV;
          end else begin
            // Both k-passes done, flush pipeline
            state_d     = ST_WAIT_PV;
          end
        end else begin
          state_d = ST_LOAD_PV;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_WAIT_PV: Wait for MAC pipeline to flush all 8 products.
      //   pv_kpass=0: 4 products (last valid_i at cycle 19)
      //   pv_kpass=1: 4 products (last valid_i at cycle 39)
      //   MAC accumulation completes at cycle 44 (8 steps from last valid_i).
      //   Correct mac_result_i available at cycle 45.
      //   WAIT_PV starts at cycle 23 → need cnt_q=22 → UPDATE_O at cycle 45.
      // ============================================================
      ST_WAIT_PV: begin
        cnt_d = cnt_q + 1;
        if (cnt_q == 5'd21) begin
          state_d     = ST_UPDATE_O;
          cnt_d       = 0;
          wr_o_cnt_d  = 0;
        end
      end

      // ============================================================
      // ST_UPDATE_O: Update O accumulator with PV result (19 cycles)
      //   O = corr_all * O_old + PV
      //   Dual-group: pv_group_q=0 for cols 0-3, pv_group_q=1 for cols 4-7
      //   m/l accumulators updated only after pv_group 1.
      // ============================================================
      ST_UPDATE_O: begin
        // Update m/l accumulators only after second column group
        if (pv_group_q == 1) begin
          m_accum_d = m_new_q;
          l_accum_d = l_new_q;
        end

        // Pipeline: feed mul at 0-15, write at 3-18
        if (cnt_q <= 6'd15) begin
          mul_a = corr_all_q[cnt_q[1:0]];
          mul_b = o_accum_q[cnt_q[1:0]][cnt_q[3:2] + pv_group_q * TILE_B_C];
        end

        if (cnt_q >= 6'd3 && wr_o_cnt_q <= 5'd15) begin
          pv_add_a = mul_out;
          pv_add_b = mac_result_i[wr_o_cnt_q[1:0]][wr_o_cnt_q[3:2]];
          o_accum_d[wr_o_cnt_q[1:0]][wr_o_cnt_q[3:2] + pv_group_q * TILE_B_C] = pv_add_sum;
          o_accum_wr = 1;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q >= 6'd3)
          wr_o_cnt_d = wr_o_cnt_q + 1;
        if (cnt_q == 6'd18) begin
          if (pv_group_q == 0) begin
            // Move to second column group
            pv_group_d  = 1;
            pv_kpass_d  = 0;
            mac_k_cnt_d = 0;
            cnt_d       = 0;
            state_d     = ST_LOAD_PV;
          end else if (inner_cnt_q < (seq_len_i / TILE_B_C) - 1) begin
            // Next inner tile
            inner_cnt_d = inner_cnt_q + 1;
            pv_group_d  = 0;
            pv_kpass_d  = 0;
            mac_k_cnt_d = 0;
            cnt_d       = 0;
            k_pass_d    = 0;
            state_d     = ST_LOAD_QK;
          end else begin
            // All inner tiles done, normalize
            state_d    = ST_NORMALIZE;
            cnt_d      = 0;
            norm_cnt_d = 0;
            norm_row_d = 0;
          end
        end
      end

      // ============================================================
      // ST_NORMALIZE: O = O_raw / l_accum, write to SRAM
      //   fp16_reciprocal: 1-cycle latency
      //   fp16_multiplier: 3-stage pipeline (3-cycle latency)
      //   Per row (13 cycles):
      //     0: recip_in = l_accum[row]; recip_out at cycle 1
      //     1: bubble
      //     2-5: mul(O[row][0..3], recip_out)
      //     5-8: write mul_out to SRAM for cols 0..3
      //     6-9: mul(O[row][4..7], recip_out)
      //     9-12: write mul_out to SRAM for cols 4..7
      //   4 rows x 13 cycles = 52 cycles
      // ============================================================
      ST_NORMALIZE: begin
        // Reciprocal: drive at cnt 0, output ready at cnt 1 (1-cycle LUT latency)
        if (norm_cnt_q == 5'd0) begin
          recip_in = l_accum_q[norm_row_q];
          recip_valid_in = 1;
        end

        // Multiplier cols 0-3: cnt 2-5
        if (norm_cnt_q >= 5'd2 && norm_cnt_q <= 5'd5) begin
          mul_a = o_accum_q[norm_row_q][norm_cnt_q - 5'd2];
          mul_b = recip_out;
        end
        // Multiplier cols 4-7: cnt 6-9
        if (norm_cnt_q >= 5'd6 && norm_cnt_q <= 5'd9) begin
          mul_a = o_accum_q[norm_row_q][norm_cnt_q - 5'd6 + 4];
          mul_b = recip_out;
        end

        // Writes cols 0-3: cnt 5-8
        // mul feed@cnt=2, 3-stage NBA pipeline → output readable at cnt=5
        if (norm_cnt_q >= 5'd5 && norm_cnt_q <= 5'd8) begin
          out_wr_en_o   = 1;
          out_wr_addr_o = FEATURE_ADDR_W'(128)
                        + FEATURE_ADDR_W'((tile_row_q * TILE_B_R + norm_row_q) * D_MODEL)
                        + FEATURE_ADDR_W'(head_idx_i * HEAD_DIM)
                        + FEATURE_ADDR_W'(norm_cnt_q - 5'd5);
          out_wr_data_o = mul_out;
        end
        // Writes cols 4-7: cnt 9-12
        // mul feed@cnt=6, 3-stage NBA pipeline → output readable at cnt=9
        if (norm_cnt_q >= 5'd9 && norm_cnt_q <= 5'd12) begin
          out_wr_en_o   = 1;
          out_wr_addr_o = FEATURE_ADDR_W'(128)
                        + FEATURE_ADDR_W'((tile_row_q * TILE_B_R + norm_row_q) * D_MODEL)
                        + FEATURE_ADDR_W'(head_idx_i * HEAD_DIM)
                        + FEATURE_ADDR_W'(norm_cnt_q - 5'd9 + 4);
          out_wr_data_o = mul_out;
        end

        // Sub-counter: 0-12, then advance row (13 cycles per row)
        if (norm_cnt_q == 5'd12) begin
          norm_cnt_d = 0;
          norm_row_d = norm_row_q + 1;
        end else begin
          norm_cnt_d = norm_cnt_q + 1;
        end

        // Exit: all 4 rows done
        if (norm_row_q == 2'd3 && norm_cnt_q == 5'd12) begin
          if (tile_row_q < (seq_len_i / TILE_B_R) - 1) begin
            // More tile_rows to process
            tile_row_d  = tile_row_q + 1;
            inner_cnt_d = 0;
            pv_col_d    = 0;
            mac_k_cnt_d = 0;
            cnt_d       = 0;
            k_pass_d    = 0;
            pv_group_d  = 0;
            pv_kpass_d  = 0;
            // Reset accumulators for new tile_row
            for (int ri = 0; ri < TILE_B_R; ri++) begin
              m_accum_d[ri] = 16'hFC00;  // -inf
              l_accum_d[ri] = 16'h0000;  // 0
              for (int ci = 0; ci < 2*TILE_B_C; ci++)
                o_accum_d[ri][ci] = 16'h0000;
            end
            state_d = ST_LOAD_QK;
          end else begin
            state_d = ST_DONE;
          end
        end
      end

      // ============================================================
      // ST_DONE: Signal completion
      // ============================================================
      ST_DONE: begin
        if (!start_i) state_d = ST_IDLE;
      end

      default: state_d = ST_IDLE;
    endcase

    if (abort_i) state_d = ST_IDLE;
  end

endmodule
