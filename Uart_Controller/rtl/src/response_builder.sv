module response_builder
  #(parameter int MAX_PAYLOAD_BYTES = 16,
    parameter int DATA_WIDTH       = 8)
   (input  logic       clk,
    input  logic       rst_n,
    input  logic       cfg_enable,
    input  logic       response_enable,
    // Response input
    input  logic       rsp_valid,
    output logic       rsp_ready,
    input  logic [7:0] rsp_seq_echo,
    input  logic [7:0] rsp_cmd_echo,
    input  logic [7:0] rsp_status,
    input  logic [4:0] rsp_len,
    input  logic [MAX_PAYLOAD_BYTES*8-1:0] rsp_payload,
    // TX FIFO interface
    output logic       tx_wr_en,
    output logic [7:0] tx_wr_data,
    input  logic       tx_full,
    // Status
    output logic       tx_count_inc);

  // Response packet constants
  localparam logic [7:0] START_BYTE = 8'hC3;
  localparam logic [7:0] END_BYTE   = 8'h3C;

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_START,
    ST_SEQ,
    ST_CMD,
    ST_STATUS,
    ST_LEN,
    ST_PAYLOAD,
    ST_CRC,
    ST_END,
    ST_DONE
  } state_t;

  state_t state;
  logic [7:0] seq_echo_reg, cmd_echo_reg, status_reg;
  logic [4:0] len_reg, byte_cnt;
  logic [MAX_PAYLOAD_BYTES*8-1:0] payload_reg;

  // CRC calculator
  logic       crc_init, crc_valid;
  logic [7:0] crc_data_in, crc_out;

  crc8_stream u_crc (
    .clk      (clk),
    .rst_n    (rst_n),
    .init     (crc_init),
    .valid    (crc_valid),
    .data_in  (crc_data_in),
    .crc_out  (crc_out)
  );

  assign rsp_ready = (state == ST_IDLE) && cfg_enable && response_enable;
  assign tx_count_inc = (state == ST_DONE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= ST_IDLE;
      seq_echo_reg <= '0;
      cmd_echo_reg <= '0;
      status_reg   <= '0;
      len_reg      <= '0;
      byte_cnt     <= '0;
      payload_reg  <= '0;
      tx_wr_en     <= 1'b0;
      tx_wr_data   <= '0;
      crc_init     <= 1'b0;
      crc_valid    <= 1'b0;
      crc_data_in  <= '0;
    end else begin
      tx_wr_en  <= 1'b0;
      crc_init  <= 1'b0;
      crc_valid <= 1'b0;

      case (state)
        ST_IDLE: begin
          if (rsp_valid && cfg_enable && response_enable) begin
            seq_echo_reg <= rsp_seq_echo;
            cmd_echo_reg <= rsp_cmd_echo;
            status_reg   <= rsp_status;
            len_reg      <= rsp_len;
            payload_reg  <= rsp_payload;
            crc_init     <= 1'b1;
            state        <= ST_START;
          end
        end

        ST_START: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= START_BYTE;
            state      <= ST_SEQ;
          end
        end

        ST_SEQ: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= seq_echo_reg;
            crc_valid  <= 1'b1;
            crc_data_in <= seq_echo_reg;
            state      <= ST_CMD;
          end
        end

        ST_CMD: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= cmd_echo_reg;
            crc_valid  <= 1'b1;
            crc_data_in <= cmd_echo_reg;
            state      <= ST_STATUS;
          end
        end

        ST_STATUS: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= status_reg;
            crc_valid  <= 1'b1;
            crc_data_in <= status_reg;
            state      <= ST_LEN;
          end
        end

        ST_LEN: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= {3'b0, len_reg};
            crc_valid  <= 1'b1;
            crc_data_in <= {3'b0, len_reg};
            byte_cnt   <= '0;
            if (len_reg == 0) begin
              state <= ST_CRC;
            end else begin
              state <= ST_PAYLOAD;
            end
          end
        end

        ST_PAYLOAD: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= payload_reg[byte_cnt*8 +: 8];
            crc_valid  <= 1'b1;
            crc_data_in <= payload_reg[byte_cnt*8 +: 8];
            if (byte_cnt == len_reg - 1) begin
              state <= ST_CRC;
            end else begin
              byte_cnt <= byte_cnt + 1'b1;
            end
          end
        end

        ST_CRC: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= crc_out;
            state      <= ST_END;
          end
        end

        ST_END: begin
          if (!tx_full) begin
            tx_wr_en   <= 1'b1;
            tx_wr_data <= END_BYTE;
            state      <= ST_DONE;
          end
        end

        ST_DONE: begin
          state <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
