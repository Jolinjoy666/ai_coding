// Multi-Head Scheduler
// Coordinates time-multiplexed computation of multiple attention heads.

module multi_head_scheduler
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
  input  logic [15:0] n_head_i,
  input  logic [15:0] head_dim_i,

  // Head index output
  output logic [15:0] head_idx_o,

  // FlashAttention control
  output logic        fa_start_o,
  input  logic        fa_done_i,

  // Interrupt
  output logic        irq_o
);

  // FSM states
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_HEAD_START,
    ST_HEAD_WAIT,
    ST_DONE
  } state_e;

  state_e state_q, state_d;

  // Head counter
  logic [15:0] head_cnt_q, head_cnt_d;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= ST_IDLE;
    end else begin
      state_q <= state_d;
    end
  end

  // Counter register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      head_cnt_q <= '0;
    end else begin
      head_cnt_q <= head_cnt_d;
    end
  end

  // Output assignments
  assign head_idx_o = head_cnt_q;

  // Next-state logic
  always_comb begin
    state_d     = state_q;
    head_cnt_d  = head_cnt_q;

    done_o      = 1'b0;
    busy_o      = 1'b0;
    irq_o       = 1'b0;
    fa_start_o  = 1'b0;

    unique case (state_q)
      ST_IDLE: begin
        if (start_i) begin
          head_cnt_d = '0;
          state_d    = ST_HEAD_START;
        end
      end

      ST_HEAD_START: begin
        busy_o     = 1'b1;
        fa_start_o = 1'b1;
        state_d    = ST_HEAD_WAIT;
      end

      ST_HEAD_WAIT: begin
        busy_o = 1'b1;
        if (fa_done_i) begin
          if (head_cnt_q < n_head_i - 1) begin
            head_cnt_d = head_cnt_q + 1;
            state_d    = ST_HEAD_START;
          end else begin
            state_d = ST_DONE;
          end
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

    if (abort_i) begin
      state_d = ST_IDLE;
    end
  end

endmodule
