module packet_parser
  #(parameter int MAX_PAYLOAD_BYTES = 16,
    parameter int TIMEOUT_BITS      = 16,
    parameter int INTER_BYTE_TIMEOUT = 50_000)
   (input  logic       clk,
    input  logic       rst_n,
    input  logic       cfg_enable,
    input  logic       timeout_enable,
    // Byte stream from RX FIFO
    input  logic [7:0] rx_byte,
    input  logic       rx_valid,
    output logic       rx_ready,
    // Decoded command output
    output logic       cmd_valid,
    input  logic       cmd_ready,
    output logic [7:0] cmd_seq,
    output logic [7:0] cmd_opcode,
    output logic [4:0] cmd_len,
    output logic [MAX_PAYLOAD_BYTES*8-1:0] cmd_payload,
    output logic [7:0] cmd_status,
    output logic       cmd_from_parser_error,
    // Error signals
    output logic       error_strobe,
    output logic [7:0] error_status);

  typedef enum logic [3:0] {
    ST_IDLE,
    ST_SEQ,
    ST_CMD,
    ST_LEN,
    ST_PAYLOAD,
    ST_CRC,
    ST_END,
    ST_ERROR,
    ST_DONE
  } state_t;

  state_t state, return_state;
  logic [7:0] seq_reg, cmd_reg;
  logic [4:0] len_reg, byte_cnt;
  logic [MAX_PAYLOAD_BYTES*8-1:0] payload_reg;
  logic [7:0] crc_calc, crc_received;
  logic [7:0] error_status_reg;
  logic error_flag;

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

  // Timeout counter
  logic [TIMEOUT_BITS-1:0] timeout_cnt;
  logic timeout_expired;

  assign timeout_expired = timeout_enable && (timeout_cnt == INTER_BYTE_TIMEOUT - 1);

  // Packet start constant
  localparam logic [7:0] START_BYTE = 8'hA5;
  localparam logic [7:0] END_BYTE   = 8'h5A;

  assign rx_ready = (state != ST_ERROR) && (state != ST_DONE) && cfg_enable;
  assign cmd_valid = (state == ST_DONE);
  assign cmd_seq = seq_reg;
  assign cmd_opcode = cmd_reg;
  assign cmd_len = len_reg;
  assign cmd_payload = payload_reg;
  assign cmd_status = error_status_reg;
  assign cmd_from_parser_error = error_flag;
  assign error_strobe = (state == ST_ERROR);
  assign error_status = error_status_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= ST_IDLE;
      return_state    <= ST_IDLE;
      seq_reg         <= '0;
      cmd_reg         <= '0;
      len_reg         <= '0;
      byte_cnt        <= '0;
      payload_reg     <= '0;
      crc_calc        <= '0;
      crc_received    <= '0;
      error_status_reg <= '0;
      error_flag      <= 1'b0;
      timeout_cnt     <= '0;
      crc_init        <= 1'b0;
      crc_valid       <= 1'b0;
      crc_data_in     <= '0;
    end else begin
      crc_init  <= 1'b0;
      crc_valid <= 1'b0;

      // Timeout counter
      if (state == ST_IDLE || (rx_valid && rx_ready)) begin
        timeout_cnt <= '0;
      end else if (state != ST_ERROR && state != ST_DONE) begin
        if (timeout_cnt < INTER_BYTE_TIMEOUT - 1)
          timeout_cnt <= timeout_cnt + 1'b1;
      end

      // cfg_enable clears parser state
      if (!cfg_enable) begin
        state <= ST_IDLE;
      end else begin
        case (state)
          ST_IDLE: begin
            error_flag <= 1'b0;
            if (rx_valid && rx_ready) begin
              if (rx_byte == START_BYTE) begin
                state    <= ST_SEQ;
                crc_init <= 1'b1;
              end
              // Ignore noise bytes before START
            end
          end

          ST_SEQ: begin
            if (timeout_expired) begin
              error_status_reg <= 8'h06; // TIMEOUT_ERROR
              state <= ST_ERROR;
            end else if (rx_valid && rx_ready) begin
              seq_reg     <= rx_byte;
              crc_valid   <= 1'b1;
              crc_data_in <= rx_byte;
              state       <= ST_CMD;
            end
          end

          ST_CMD: begin
            if (timeout_expired) begin
              error_status_reg <= 8'h06;
              state <= ST_ERROR;
            end else if (rx_valid && rx_ready) begin
              cmd_reg     <= rx_byte;
              crc_valid   <= 1'b1;
              crc_data_in <= rx_byte;
              state       <= ST_LEN;
            end
          end

          ST_LEN: begin
            if (timeout_expired) begin
              error_status_reg <= 8'h06;
              state <= ST_ERROR;
            end else if (rx_valid && rx_ready) begin
              crc_valid   <= 1'b1;
              crc_data_in <= rx_byte;
              if (rx_byte > MAX_PAYLOAD_BYTES[7:0]) begin
                error_status_reg <= 8'h02; // LENGTH_ERROR
                state <= ST_ERROR;
              end else begin
                len_reg   <= rx_byte[4:0];
                byte_cnt  <= '0;
                if (rx_byte == 0) begin
                  state <= ST_CRC;
                end else begin
                  state <= ST_PAYLOAD;
                end
              end
            end
          end

          ST_PAYLOAD: begin
            if (timeout_expired) begin
              error_status_reg <= 8'h06;
              state <= ST_ERROR;
            end else if (rx_valid && rx_ready) begin
              payload_reg[byte_cnt*8 +: 8] <= rx_byte;
              crc_valid   <= 1'b1;
              crc_data_in <= rx_byte;
              if (byte_cnt == len_reg - 1) begin
                state <= ST_CRC;
              end else begin
                byte_cnt <= byte_cnt + 1'b1;
              end
            end
          end

          ST_CRC: begin
            if (timeout_expired) begin
              error_status_reg <= 8'h06;
              state <= ST_ERROR;
            end else if (rx_valid && rx_ready) begin
              crc_received <= rx_byte;
              crc_calc     <= crc_out;
              state        <= ST_END;
            end
          end

          ST_END: begin
            if (timeout_expired) begin
              error_status_reg <= 8'h06;
              state <= ST_ERROR;
            end else if (rx_valid && rx_ready) begin
              if (rx_byte != END_BYTE) begin
                error_status_reg <= 8'h02; // LENGTH_ERROR
                error_flag <= 1'b1;
                state <= ST_DONE;
              end else if (crc_received != crc_calc) begin
                error_status_reg <= 8'h01; // CRC_ERROR
                error_flag <= 1'b1;
                state <= ST_DONE;
              end else begin
                error_status_reg <= 8'h00; // OK
                error_flag <= 1'b0;
                state <= ST_DONE;
              end
            end
          end

          ST_ERROR: begin
            error_flag <= 1'b1;
            state <= ST_DONE;
          end

          ST_DONE: begin
            if (cmd_ready) begin
              state <= ST_IDLE;
            end
          end

          default: state <= ST_IDLE;
        endcase
      end
    end
  end

endmodule
