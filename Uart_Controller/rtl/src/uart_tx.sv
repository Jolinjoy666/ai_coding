module uart_tx
  #(parameter int DATA_WIDTH = 8)
   (input  logic       clk,
    input  logic       rst_n,
    input  logic       baud_tick,
    input  logic       tx_start,
    input  logic [7:0] tx_data,
    output logic       tx_out,
    output logic       tx_busy,
    output logic       tx_done);

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_START,
    ST_DATA,
    ST_STOP,
    ST_DONE
  } state_t;

  state_t state;
  logic [3:0] bit_cnt;
  logic [7:0] shift_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= ST_IDLE;
      bit_cnt   <= '0;
      shift_reg <= '0;
      tx_out    <= 1'b1;
      tx_busy   <= 1'b0;
      tx_done   <= 1'b0;
    end else begin
      tx_done <= 1'b0;

      case (state)
        ST_IDLE: begin
          tx_out <= 1'b1;
          if (tx_start) begin
            state     <= ST_START;
            shift_reg <= tx_data;
            bit_cnt   <= '0;
            tx_busy   <= 1'b1;
          end
        end

        ST_START: begin
          if (baud_tick) begin
            tx_out <= 1'b0;
            state  <= ST_DATA;
          end
        end

        ST_DATA: begin
          if (baud_tick) begin
            tx_out <= shift_reg[0];
            shift_reg <= {1'b0, shift_reg[7:1]};
            if (bit_cnt == DATA_WIDTH - 1) begin
              state <= ST_STOP;
            end else begin
              bit_cnt <= bit_cnt + 1'b1;
            end
          end
        end

        ST_STOP: begin
          if (baud_tick) begin
            tx_out <= 1'b1;
            state  <= ST_DONE;
          end
        end

        ST_DONE: begin
          if (baud_tick) begin
            tx_busy <= 1'b0;
            tx_done <= 1'b1;
            state   <= ST_IDLE;
          end
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
