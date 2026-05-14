// Pipeline Buffer (Ping-Pong)
// Double-buffered FIFO for pipeline stage overlap.

module pipeline_buffer
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        clear_i,

  // Write interface
  input  logic        wr_en_i,
  input  logic [FP16_WIDTH-1:0] wr_data_i,
  input  logic        wr_last_i,   // Last data in batch
  output logic        wr_ready_o,  // Buffer ready to accept

  // Read interface
  input  logic        rd_en_i,
  output logic [FP16_WIDTH-1:0] rd_data_o,
  output logic        rd_valid_o,
  output logic        rd_last_o
);

  // Ping-pong buffer
  logic [FP16_WIDTH-1:0] buf_a [0:SEQ_LEN*D_MODEL-1];
  logic [FP16_WIDTH-1:0] buf_b [0:SEQ_LEN*D_MODEL-1];

  // Control signals
  logic sel_q, sel_d;        // 0 = write A read B, 1 = write B read A
  logic [15:0] wr_cnt_q, wr_cnt_d;
  logic [15:0] rd_cnt_q, rd_cnt_d;
  logic buf_a_valid_q, buf_a_valid_d;
  logic buf_b_valid_q, buf_b_valid_d;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sel_q         <= 1'b0;
      wr_cnt_q      <= '0;
      rd_cnt_q      <= '0;
      buf_a_valid_q <= 1'b0;
      buf_b_valid_q <= 1'b0;
    end else if (clear_i) begin
      sel_q         <= 1'b0;
      wr_cnt_q      <= '0;
      rd_cnt_q      <= '0;
      buf_a_valid_q <= 1'b0;
      buf_b_valid_q <= 1'b0;
    end else begin
      sel_q         <= sel_d;
      wr_cnt_q      <= wr_cnt_d;
      rd_cnt_q      <= rd_cnt_d;
      buf_a_valid_q <= buf_a_valid_d;
      buf_b_valid_q <= buf_b_valid_d;
    end
  end

  // Combined write and read logic (single always_comb to avoid multi-driver)
  always_comb begin
    // Defaults
    sel_d         = sel_q;
    wr_cnt_d      = wr_cnt_q;
    rd_cnt_d      = rd_cnt_q;
    buf_a_valid_d = buf_a_valid_q;
    buf_b_valid_d = buf_b_valid_q;
    rd_valid_o    = 1'b0;
    rd_last_o     = 1'b0;

    // Write logic
    if (wr_en_i) begin
      if (sel_q == 1'b0) begin
        buf_a[wr_cnt_q] <= wr_data_i;
      end else begin
        buf_b[wr_cnt_q] <= wr_data_i;
      end

      if (wr_last_i) begin
        wr_cnt_d = '0;
        if (sel_q == 1'b0) begin
          buf_a_valid_d = 1'b1;
        end else begin
          buf_b_valid_d = 1'b1;
        end
        sel_d = !sel_q;
      end else begin
        wr_cnt_d = wr_cnt_q + 1;
      end
    end

    // Read logic
    if (rd_en_i) begin
      if (sel_q == 1'b1) begin
        // Reading from buffer A
        if (buf_a_valid_q) begin
          rd_valid_o = 1'b1;
          if (rd_cnt_q < SEQ_LEN * D_MODEL - 1) begin
            rd_cnt_d = rd_cnt_q + 1;
          end else begin
            rd_cnt_d = '0;
            rd_last_o = 1'b1;
            buf_a_valid_d = 1'b0;
          end
        end
      end else begin
        // Reading from buffer B
        if (buf_b_valid_q) begin
          rd_valid_o = 1'b1;
          if (rd_cnt_q < SEQ_LEN * D_MODEL - 1) begin
            rd_cnt_d = rd_cnt_q + 1;
          end else begin
            rd_cnt_d = '0;
            rd_last_o = 1'b1;
            buf_b_valid_d = 1'b0;
          end
        end
      end
    end
  end

  // Data output
  always_comb begin
    if (sel_q == 1'b1) begin
      rd_data_o = buf_a[rd_cnt_q];
    end else begin
      rd_data_o = buf_b[rd_cnt_q];
    end
  end

  // Ready signal
  assign wr_ready_o = (sel_q == 1'b0) ? !buf_b_valid_q : !buf_a_valid_q;

endmodule
