// UART Top Module
// 115200 baud, 8N1, TX/RX FIFO depth 16.

module uart_top
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // APB interface
  input  logic [31:0] paddr_i,
  input  logic        psel_i,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,

  // UART pins
  input  logic        rx_i,
  output logic        tx_o,

  // Interrupt
  output logic        irq_o
);

  // UART register offsets
  localparam bit [3:0] UART_DATA   = 4'h0;
  localparam bit [3:0] UART_STATUS = 4'h4;
  localparam bit [3:0] UART_CTRL   = 4'h8;
  localparam bit [3:0] UART_BAUD   = 4'hC;

  // Baud rate generation
  // 100MHz / 115200 ≈ 868
  localparam int BAUD_DIV = 868;

  // TX FIFO
  logic [7:0] tx_fifo [0:15];
  logic [3:0] tx_wr_ptr, tx_rd_ptr;
  logic [4:0] tx_cnt;
  logic tx_fifo_full, tx_fifo_empty;

  // RX FIFO
  logic [7:0] rx_fifo [0:15];
  logic [3:0] rx_wr_ptr, rx_rd_ptr;
  logic [4:0] rx_cnt;
  logic rx_fifo_full, rx_fifo_empty;

  // TX state machine
  typedef enum logic [1:0] {
    TX_IDLE,
    TX_START,
    TX_DATA,
    TX_STOP
  } tx_state_e;

  tx_state_e tx_state_q, tx_state_d;
  logic [15:0] tx_baud_cnt_q, tx_baud_cnt_d;
  logic [2:0] tx_bit_cnt_q, tx_bit_cnt_d;
  logic [7:0] tx_shift_q, tx_shift_d;
  logic tx_q, tx_d;

  // RX state machine
  typedef enum logic [1:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
  } rx_state_e;

  rx_state_e rx_state_q, rx_state_d;
  logic [15:0] rx_baud_cnt_q, rx_baud_cnt_d;
  logic [2:0] rx_bit_cnt_q, rx_bit_cnt_d;
  logic [7:0] rx_shift_q, rx_shift_d;
  logic rx_sync, rx_sync2;

  // Synchronize RX input
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync  <= 1'b1;
      rx_sync2 <= 1'b1;
    end else begin
      rx_sync  <= rx_i;
      rx_sync2 <= rx_sync;
    end
  end

  // TX FIFO logic
  assign tx_fifo_full  = (tx_cnt == 16);
  assign tx_fifo_empty = (tx_cnt == 0);

  // RX FIFO logic
  assign rx_fifo_full  = (rx_cnt == 16);
  assign rx_fifo_empty = (rx_cnt == 0);

  // APB register access
  logic apb_wr, apb_rd;
  assign apb_wr = psel_i && penable_i && pwrite_i;
  assign apb_rd = psel_i && !pwrite_i;

  // Write logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_wr_ptr <= '0;
      rx_rd_ptr <= '0;
    end else begin
      if (apb_wr && paddr_i[3:0] == UART_DATA) begin
        if (!tx_fifo_full) begin
          tx_fifo[tx_wr_ptr] <= pwdata_i[7:0];
          tx_wr_ptr <= tx_wr_ptr + 1;
        end
      end

      if (apb_rd && paddr_i[3:0] == UART_DATA) begin
        if (!rx_fifo_empty) begin
          rx_rd_ptr <= rx_rd_ptr + 1;
        end
      end
    end
  end

  // Read logic
  always_comb begin
    prdata_o = '0;
    pready_o = 1'b1;
    pslverr_o = 1'b0;

    if (apb_rd) begin
      unique case (paddr_i[3:0])
        UART_DATA:   prdata_o = {24'b0, rx_fifo[rx_rd_ptr]};
        UART_STATUS: prdata_o = {26'b0, rx_fifo_full, rx_fifo_empty, tx_fifo_full, tx_fifo_empty, 1'b0, 1'b0};
        UART_CTRL:   prdata_o = '0;
        UART_BAUD:   prdata_o = {16'b0, BAUD_DIV[15:0]};
        default:     prdata_o = '0;
      endcase
    end
  end

  // TX state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state_q    <= TX_IDLE;
      tx_baud_cnt_q <= '0;
      tx_bit_cnt_q  <= '0;
      tx_shift_q    <= '0;
      tx_q          <= 1'b1;
    end else begin
      tx_state_q    <= tx_state_d;
      tx_baud_cnt_q <= tx_baud_cnt_d;
      tx_bit_cnt_q  <= tx_bit_cnt_d;
      tx_shift_q    <= tx_shift_d;
      tx_q          <= tx_d;
    end
  end

  always_comb begin
    tx_state_d    = tx_state_q;
    tx_baud_cnt_d = tx_baud_cnt_q;
    tx_bit_cnt_d  = tx_bit_cnt_q;
    tx_shift_d    = tx_shift_q;
    tx_d          = tx_q;

    unique case (tx_state_q)
      TX_IDLE: begin
        tx_d = 1'b1;
        if (!tx_fifo_empty) begin
          tx_shift_d    = tx_fifo[tx_rd_ptr];
          tx_baud_cnt_d = '0;
          tx_state_d    = TX_START;
        end
      end

      TX_START: begin
        tx_d = 1'b0;  // Start bit
        if (tx_baud_cnt_q == BAUD_DIV - 1) begin
          tx_baud_cnt_d = '0;
          tx_bit_cnt_d  = '0;
          tx_state_d    = TX_DATA;
        end else begin
          tx_baud_cnt_d = tx_baud_cnt_q + 1;
        end
      end

      TX_DATA: begin
        tx_d = tx_shift_q[0];
        if (tx_baud_cnt_q == BAUD_DIV - 1) begin
          tx_baud_cnt_d = '0;
          tx_shift_d    = {1'b0, tx_shift_q[7:1]};
          if (tx_bit_cnt_q == 7) begin
            tx_state_d = TX_STOP;
          end else begin
            tx_bit_cnt_d = tx_bit_cnt_q + 1;
          end
        end else begin
          tx_baud_cnt_d = tx_baud_cnt_q + 1;
        end
      end

      TX_STOP: begin
        tx_d = 1'b1;  // Stop bit
        if (tx_baud_cnt_q == BAUD_DIV - 1) begin
          tx_baud_cnt_d = '0;
          tx_state_d    = TX_IDLE;
        end else begin
          tx_baud_cnt_d = tx_baud_cnt_q + 1;
        end
      end
    endcase
  end

  // TX FIFO read pointer update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_rd_ptr <= '0;
    end else begin
      if (tx_state_q == TX_STOP && tx_baud_cnt_q == BAUD_DIV - 1) begin
        tx_rd_ptr <= tx_rd_ptr + 1;
      end
    end
  end

  // RX state machine (simplified)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state_q    <= RX_IDLE;
      rx_baud_cnt_q <= '0;
      rx_bit_cnt_q  <= '0;
      rx_shift_q    <= '0;
      rx_wr_ptr     <= '0;
    end else begin
      // Simplified RX - would need proper implementation
      if (!rx_sync2 && rx_state_q == RX_IDLE) begin
        rx_state_q <= RX_START;
        rx_baud_cnt_q <= '0;
      end
    end
  end

  // Interrupt
  assign irq_o = !rx_fifo_empty || tx_fifo_empty;

  // Output
  assign tx_o = tx_q;

endmodule
