module uart_rx
  #(parameter int DATA_WIDTH  = 8,
    parameter int OVERSAMPLE  = 16)
   (input  logic       clk,
    input  logic       rst_n,
    input  logic       oversample_tick,
    input  logic       rx_in,
    output logic [7:0] rx_data,
    output logic       rx_valid,
    output logic       rx_ready,
    output logic       framing_error);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_START,
    ST_DATA,
    ST_STOP,
    ST_DONE
  } state_t;

  state_t state;
  logic [3:0] bit_cnt;
  logic [$clog2(OVERSAMPLE)-1:0] samp_cnt;
  logic [7:0] shift_reg;
  logic rx_sync1, rx_sync2;

  // Double-flop synchronizer
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync1 <= 1'b1;
      rx_sync2 <= 1'b1;
    end else begin
      rx_sync1 <= rx_in;
      rx_sync2 <= rx_sync1;
    end
  end

  assign rx_ready = (state == ST_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= ST_IDLE;
      bit_cnt       <= '0;
      samp_cnt      <= '0;
      shift_reg     <= '0;
      rx_valid      <= 1'b0;
      framing_error <= 1'b0;
    end else begin
      rx_valid <= 1'b0;
      framing_error <= 1'b0;

      if (oversample_tick) begin
        case (state)
          ST_IDLE: begin
            if (!rx_sync2) begin
              state    <= ST_START;
              samp_cnt <= '0;
            end
          end

          ST_START: begin
            if (samp_cnt == OVERSAMPLE/2 - 1) begin
              if (!rx_sync2) begin
                state    <= ST_DATA;
                bit_cnt  <= '0;
                samp_cnt <= '0;
              end else begin
                state <= ST_IDLE;
              end
            end else begin
              samp_cnt <= samp_cnt + 1'b1;
            end
          end

          ST_DATA: begin
            if (samp_cnt == OVERSAMPLE - 1) begin
              samp_cnt  <= '0;
              shift_reg <= {rx_sync2, shift_reg[7:1]};
              if (bit_cnt == DATA_WIDTH - 1) begin
                state <= ST_STOP;
              end else begin
                bit_cnt <= bit_cnt + 1'b1;
              end
            end else begin
              samp_cnt <= samp_cnt + 1'b1;
            end
          end

          ST_STOP: begin
            if (samp_cnt == OVERSAMPLE - 1) begin
              if (rx_sync2) begin
                state    <= ST_DONE;
                rx_valid <= 1'b1;
              end else begin
                state         <= ST_DONE;
                framing_error <= 1'b1;
              end
            end else begin
              samp_cnt <= samp_cnt + 1'b1;
            end
          end

          ST_DONE: begin
            state <= ST_IDLE;
          end

          default: state <= ST_IDLE;
        endcase
      end
    end
  end

  assign rx_data = shift_reg;

endmodule
