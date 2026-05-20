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
  logic [4:0]  cnt_q, cnt_d;
  logic [2:0]  mac_k_cnt_q, mac_k_cnt_d;
  logic        pv_col_q, pv_col_d;
  logic [3:0]  norm_cnt_q, norm_cnt_d;
  logic [1:0]  norm_row_q, norm_row_d;
  logic [4:0]  wr_scale_cnt_q, wr_scale_cnt_d;
  logic [4:0]  wr_o_cnt_q, wr_o_cnt_d;

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

  // ---- Tile Buffers ----
  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] S_tile_q, S_tile_d;
  logic [MAC_ROWS-1:0][MAC_COLS-1:0][FP16_WIDTH-1:0] S_scaled_q, S_scaled_d;
  logic [TILE_B_R-1:0][TILE_B_C-1:0][FP16_WIDTH-1:0] P_tile_q, P_tile_d;

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

  // Correction values for all 4 rows (captured from P_tile exp LUTs at cycle 5)
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] corr_all_q, corr_all_d;

  // ---- Rowmax (combinational, from S_scaled_q) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] rowmax_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_rmax
      fp16_rowmax #(.WIDTH(TILE_B_C)) u_rm (
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

  // ---- Rowsum (combinational, from P_tile_q) ----
  logic [TILE_B_R-1:0][FP16_WIDTH-1:0] rowsum_out;
  generate
    for (gi = 0; gi < TILE_B_R; gi++) begin : gen_rsum
      fp16_rowsum #(.WIDTH(TILE_B_C)) u_rs (
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

  // ---- Multiplier (registered, 3-cycle pipeline) ----
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

      if (o_accum_wr)
        o_accum_q <= o_accum_d;

      // Latch l_new values during ST_SOFTMAX_WAIT
      // lnew driven at cycles 9-12 (lnew_a/lnew_b valid), latch at same edges
      if (state_q == ST_SOFTMAX_WAIT) begin
        if (cnt_q == 4'd9)  l_new_q[0] <= lnew_sum;
        if (cnt_q == 4'd10) l_new_q[1] <= lnew_sum;
        if (cnt_q == 4'd11) l_new_q[2] <= lnew_sum;
        if (cnt_q == 4'd12) l_new_q[3] <= lnew_sum;
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
        pv_col_d    = 0;
        m_accum_d   = '{default: 16'hFC00};
        l_accum_d   = 0;
        state_d     = ST_LOAD_QK;
      end

      // ============================================================
      // ST_LOAD_QK: Load Q and K from SRAM into buffers (4 cycles)
      //   SRAM combinational read: data available same cycle as address
      // ============================================================
      ST_LOAD_QK: begin
        mac_clear_o = (cnt_q == 0) && (mac_k_cnt_q == 0);

        q_rd_en_o   = 1;
        q_rd_addr_o = FEATURE_ADDR_W'((tile_row_q * TILE_B_R + cnt_q) * D_MODEL)
                    + FEATURE_ADDR_W'(head_idx_i * HEAD_DIM)
                    + FEATURE_ADDR_W'(mac_k_cnt_q);

        k_rd_en_o   = 1;
        k_rd_addr_o = KVCACHE_ADDR_W'((inner_cnt_q * TILE_B_C + cnt_q) * D_MODEL)
                    + KVCACHE_ADDR_W'(head_idx_i * HEAD_DIM)
                    + KVCACHE_ADDR_W'(mac_k_cnt_q);

        // Capture SRAM read data (combinational, available same cycle)
        q_buf_d[cnt_q] = q_rd_data_i;
        k_buf_d[cnt_q] = k_rd_data_i;

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd3) begin
          state_d = ST_DRIVE_S;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_DRIVE_S: Drive MAC with buffered Q and K (1 cycle)
      //   mac_a[r] = Q[tile_row*4+r][h][k]
      //   mac_b[c] = K[inner*4+c][h][k]
      //   MAC accumulates: S[r][c] += Q[r][k] * K[c][k]
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
      // ST_WAIT_S: Wait for MAC pipeline to flush (3 cycles)
      // ============================================================
      ST_WAIT_S: begin
        cnt_d = cnt_q + 1;
        // After 8 DRIVE_S: acc done at cycle 10, shared valid at cycle 11, cnt_q=3
        if (mac_valid_i || cnt_q == 4'd3) begin
          state_d = ST_COLLECT_S;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_COLLECT_S: Capture S_tile from MAC result
      // ============================================================
      ST_COLLECT_S: begin
        S_tile_d    = mac_result_i;
        state_d     = ST_SCALE_S;
        cnt_d       = 0;
        wr_scale_cnt_d = 0;
      end

      // ============================================================
      // ST_SCALE_S: S = S * scale_factor (19 cycles)
      //   Pipeline: feed mul at cycles 0-15, capture at cycles 3-18
      //   Separate read/write counters for 3-stage multiplier pipeline
      // ============================================================
      ST_SCALE_S: begin
        // Feed multiplier with S_tile values (cycles 0-15)
        if (cnt_q <= 5'd15) begin
          mul_a = S_tile_q[cnt_q[1:0]][cnt_q[3:2]];
          mul_b = scale_factor_i;
        end

        // Capture multiplier output (3-cycle pipeline latency)
        // Output at cycle N is the result of the feed at cycle N-3
        if (cnt_q >= 5'd3 && wr_scale_cnt_q <= 5'd15) begin
          S_scaled_d[wr_scale_cnt_q[1:0]][wr_scale_cnt_q[3:2]] = mul_out;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q >= 5'd3)
          wr_scale_cnt_d = wr_scale_cnt_q + 1;
        if (cnt_q == 5'd18) begin
          state_d = ST_CALC_SOFTMAX;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_CALC_SOFTMAX: Compute m_new and exp(S - m_new) (4 cycles)
      //   m_new = max(m_accum, rowmax(S))
      //   P[row][col] = exp(S[row][col] - m_new[row])
      // ============================================================
      ST_CALC_SOFTMAX: begin
        for (int r = 0; r < TILE_B_R; r++)
          m_new_d[r] = m_new_cmp[r];

        for (int r = 0; r < TILE_B_R; r++) begin
          sub_a[r] = S_scaled_q[r][cnt_q[1:0]];
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
      // ST_SOFTMAX_WAIT: Collect P, compute correction & l_new (15 cycles)
      //   0-3:   Collect exp output into P_tile
      //   4:     Feed correction factor to P_tile exp LUTs
      //   5:     Capture correction into corr_all_q
      //   6-9:   mul=corr_all*l_accum[0..3]
      //   9-12:  lnew=mul+rowsum[0..3], latched at edges 10-13
      //   14:    Transition
      // ============================================================
      ST_SOFTMAX_WAIT: begin
        // Collect exp output into P_tile (1-cycle LUT latency)
        // ST_CALC_SOFTMAX feeds col 0-3 at cycles 0-3
        // exp output appears 1 cycle later:
        //   SW cycle 0 (cnt_q=0): exp_out = col 3 result (registered from SC cycle 3)
        //   SW cycle 1: col 0 result
        //   SW cycle 2: col 1 result
        //   SW cycle 3: col 2 result
        //   SW cycle 4: col 3 result (also available here, from SC cycle 3 → 1-cycle latency)
        if (cnt_q == 4'd0) begin
          // Capture column 3 (registered output from SC cycle 3)
          for (int r = 0; r < TILE_B_R; r++)
            P_tile_d[r][3] = exp_out[r];
        end
        if (cnt_q >= 4'd1 && cnt_q <= 4'd3) begin
          // Capture columns 0-2
          for (int r = 0; r < TILE_B_R; r++)
            P_tile_d[r][cnt_q[1:0] - 2'd1] = exp_out[r];
        end

        // Cycle 4: feed correction factor inputs to exp LUTs (P_tile fully captured)
        if (cnt_q == 4'd4) begin
          for (int r = 0; r < TILE_B_R; r++) begin
            sub_a[r] = m_accum_q[r];
            sub_b[r] = m_new_q[r];
            exp_in[r] = sub_out[r];
            exp_valid_in[r] = 1;
          end
        end

        // Cycle 5: capture correction values from P_tile exp LUTs
        if (cnt_q == 4'd5) begin
          corr_all_d = exp_out;
        end

        // l_new pipeline: 3-stage multiplier (3-cycle latency)
        // corr_all_q latched at edge 6, mul feeds at cycles 6-9
        // results at cycles 9-12, add at cycles 9-12, l_new latched at edges 10-13
        if (cnt_q == 4'd6) begin
          mul_a = corr_all_q[0]; mul_b = l_accum_q[0];
        end
        if (cnt_q == 4'd7) begin
          mul_a = corr_all_q[1]; mul_b = l_accum_q[1];
        end
        if (cnt_q == 4'd8) begin
          mul_a = corr_all_q[2]; mul_b = l_accum_q[2];
        end
        if (cnt_q == 4'd9) begin
          mul_a = corr_all_q[3]; mul_b = l_accum_q[3];
        end
        // Add: mul_out (3 cycles delayed) + rowsum
        if (cnt_q == 4'd9) begin
          lnew_a = mul_out; lnew_b = rowsum_out[0];
        end
        if (cnt_q == 4'd10) begin
          lnew_a = mul_out; lnew_b = rowsum_out[1];
        end
        if (cnt_q == 4'd11) begin
          lnew_a = mul_out; lnew_b = rowsum_out[2];
        end
        if (cnt_q == 4'd12) begin
          lnew_a = mul_out; lnew_b = rowsum_out[3];
        end

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd14) begin
          state_d     = ST_LOAD_PV;
          cnt_d       = 0;
          mac_k_cnt_d = 0;
        end
      end

      // ============================================================
      // ST_LOAD_PV: Load V from KV-Cache into buffer (4 cycles)
      //   SRAM combinational read: data available same cycle as address
      // ============================================================
      ST_LOAD_PV: begin
        mac_clear_o = (cnt_q == 0);

        v_rd_en_o   = 1;
        // Load 4 columns of V row [inner*4+mac_k_cnt] in one pass
        // V stored at KV-Cache SRAM word offset 64 (= KVCACHE_BASE + 0x80 byte addr / 2)
        v_rd_addr_o = KVCACHE_ADDR_W'(64)
                    + KVCACHE_ADDR_W'((inner_cnt_q * TILE_B_C + mac_k_cnt_q) * D_MODEL)
                    + KVCACHE_ADDR_W'(head_idx_i * HEAD_DIM)
                    + KVCACHE_ADDR_W'(pv_col_q * TILE_B_C)
                    + KVCACHE_ADDR_W'(cnt_q);

        // Capture V data (combinational, available same cycle)
        v_buf_d[cnt_q] = v_rd_data_i;

        cnt_d = cnt_q + 1;
        if (cnt_q == 4'd3) begin
          state_d = ST_DRIVE_PV;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_DRIVE_PV: Drive MAC for P*V (1 cycle)
      //   mac_a[r] = P_tile[r][mac_k_cnt]
      //   mac_b[c] = V[inner*4+mac_k_cnt][h][pv_col*4+c]
      // ============================================================
      ST_DRIVE_PV: begin
        for (int r = 0; r < MAC_ROWS; r++)
          mac_a_o[r] = P_tile_q[r][mac_k_cnt_q];
        for (int c = 0; c < MAC_COLS; c++)
          mac_b_o[c] = v_buf_q[c];
        mac_valid_o = 1;

        mac_k_cnt_d = mac_k_cnt_q + 1;
        if (mac_k_cnt_q == 3'd3) begin
          state_d     = ST_WAIT_PV;
          mac_k_cnt_d = 0;
          cnt_d       = 0;
        end else begin
          state_d = ST_LOAD_PV;
          cnt_d   = 0;
        end
      end

      // ============================================================
      // ST_WAIT_PV: Wait for MAC pipeline to flush (3 cycles)
      // ============================================================
      ST_WAIT_PV: begin
        cnt_d = cnt_q + 1;
        // After 4 DRIVE_PV: acc done at cycle 7, shared valid at cycle 7, cnt_q=3
        if (mac_valid_i || cnt_q == 4'd3) begin
          state_d = ST_UPDATE_O;
          cnt_d   = 0;
          wr_o_cnt_d = 0;
        end
      end

      // ============================================================
      // ST_UPDATE_O: Update O accumulator with PV result
      //   O = corr_all * O_old + PV  (19 cycles per pv_col)
      //   For first tile: corr_all = 0, O_old = 0, so O = PV
      //   Two passes: pv_col 0 (cols 0-3), pv_col 1 (cols 4-7)
      //   Also updates m/l accumulators
      // ============================================================
      ST_UPDATE_O: begin
        // Update m/l accumulators (latched at clock edge)
        m_accum_d = m_new_q;
        l_accum_d = l_new_q;

        // Pipeline: feed mul at 0-15, write at 3-18
        // 3-stage multiplier: output at cycle N is result of feed at cycle N-3
        if (cnt_q <= 5'd15) begin
          mul_a = corr_all_q[cnt_q[1:0]];
          mul_b = o_accum_q[cnt_q[1:0]][cnt_q[3:2] + pv_col_q * TILE_B_C];
        end

        if (cnt_q >= 5'd3 && wr_o_cnt_q <= 5'd15) begin
          o_accum_d[wr_o_cnt_q[1:0]][wr_o_cnt_q[3:2] + pv_col_q * TILE_B_C] = mul_out + mac_result_i[wr_o_cnt_q[1:0]][wr_o_cnt_q[3:2]];
          o_accum_wr = 1;
        end

        cnt_d = cnt_q + 1;
        if (cnt_q >= 5'd3)
          wr_o_cnt_d = wr_o_cnt_q + 1;
        if (cnt_q == 5'd18) begin
          if (pv_col_q == 0) begin
            // Move to second column pass
            pv_col_d    = 1;
            mac_k_cnt_d = 0;
            cnt_d       = 0;
            state_d     = ST_LOAD_PV;
          end else if (inner_cnt_q < (seq_len_i / TILE_B_C) - 1) begin
            // Next inner tile
            inner_cnt_d = inner_cnt_q + 1;
            pv_col_d    = 0;
            mac_k_cnt_d = 0;
            cnt_d       = 0;
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
        // Reciprocal: drive at cnt 0 only
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

        // Writes cols 0-3: cnt 5-8 (3 cycles after mul started)
        if (norm_cnt_q >= 5'd5 && norm_cnt_q <= 5'd8) begin
          out_wr_en_o   = 1;
          out_wr_addr_o = FEATURE_ADDR_W'(128)
                        + FEATURE_ADDR_W'((tile_row_q * TILE_B_R + norm_row_q) * D_MODEL)
                        + FEATURE_ADDR_W'(head_idx_i * HEAD_DIM)
                        + FEATURE_ADDR_W'(norm_cnt_q - 5'd5);
          out_wr_data_o = mul_out;
        end
        // Writes cols 4-7: cnt 9-12
        if (norm_cnt_q >= 5'd9 && norm_cnt_q <= 5'd12) begin
          out_wr_en_o   = 1;
          out_wr_addr_o = FEATURE_ADDR_W'(128)
                        + FEATURE_ADDR_W'((tile_row_q * TILE_B_R + norm_row_q) * D_MODEL)
                        + FEATURE_ADDR_W'(head_idx_i * HEAD_DIM)
                        + FEATURE_ADDR_W'(norm_cnt_q - 5'd9 + 4);
          out_wr_data_o = mul_out;
        end

        // Sub-counter: 0-12, then advance row
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
