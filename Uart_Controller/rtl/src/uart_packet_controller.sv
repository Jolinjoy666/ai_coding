module uart_packet_controller
  #(parameter int CLK_FREQ_HZ       = 50_000_000,
    parameter int BAUD_RATE         = 115_200,
    parameter int OVERSAMPLE        = 16,
    parameter int DATA_WIDTH        = 8,
    parameter int FIFO_DEPTH        = 32,
    parameter int MAX_PAYLOAD_BYTES = 16,
    parameter int MEM_ADDR_WIDTH    = 4,
    parameter int APB_ADDR_WIDTH    = 8,
    parameter int APB_DATA_WIDTH    = 32,
    parameter int TIMEOUT_BITS      = 16,
    parameter int INTER_BYTE_TIMEOUT = 50_000)
   (input  logic       clk,
    input  logic       rst_n,
    // UART interface
    input  logic       uart_rx_i,
    output logic       uart_tx_o,
    // Control inputs
    input  logic       cfg_enable,
    input  logic       irq_clear,
    input  logic       soft_reset_clear,
    // APB-Lite interface
    input  logic [APB_ADDR_WIDTH-1:0]  paddr,
    input  logic       psel,
    input  logic       penable,
    input  logic       pwrite,
    input  logic [APB_DATA_WIDTH-1:0]  pwdata,
    input  logic [APB_DATA_WIDTH/8-1:0] pstrb,
    output logic [APB_DATA_WIDTH-1:0]  prdata,
    output logic       pready,
    output logic       pslverr,
    // Status outputs
    output logic       irq_o,
    output logic       busy_o,
    output logic [15:0] rx_packet_count,
    output logic [15:0] tx_packet_count,
    output logic [15:0] error_count,
    output logic [3:0]  last_error,
    output logic        soft_reset_seen);

  // Internal signals
  logic baud_tick, oversample_tick;
  logic [7:0] rx_byte_from_uart;
  logic [7:0] rx_byte_from_fifo;
  logic [7:0] tx_byte_to_fifo;
  logic [7:0] tx_byte_from_fifo;
  logic rx_valid_from_uart, rx_ready_from_uart;
  logic rx_fifo_empty;
  logic rx_fifo_rd_en;
  logic tx_wr_en, tx_full, tx_empty;
  logic framing_error;
  logic tx_start, tx_busy, tx_done;
  logic parser_rx_ready;

  // Parser to command engine
  logic       cmd_valid, cmd_ready;
  logic [7:0] cmd_seq, cmd_opcode;
  logic [4:0] cmd_len;
  logic [MAX_PAYLOAD_BYTES*8-1:0] cmd_payload;
  logic [7:0] cmd_status;
  logic       cmd_from_parser_error;

  // Command engine to response builder
  logic       rsp_valid, rsp_ready;
  logic [7:0] rsp_seq_echo, rsp_cmd_echo, rsp_status;
  logic [4:0] rsp_len;
  logic [MAX_PAYLOAD_BYTES*8-1:0] rsp_payload;

  // Arbitration signals
  logic       uart_req_valid, uart_req_ready;
  logic       uart_req_write;
  logic [7:0] uart_req_addr;
  logic [APB_DATA_WIDTH-1:0] uart_req_wdata;
  logic [3:0]  uart_req_wstrb;
  logic       uart_resp_valid;
  logic [7:0] uart_resp_status;
  logic [APB_DATA_WIDTH-1:0] uart_resp_rdata;

  logic       apb_req_valid, apb_req_ready;
  logic       apb_req_write;
  logic [7:0] apb_req_addr;
  logic [APB_DATA_WIDTH-1:0] apb_req_wdata;
  logic [3:0]  apb_req_wstrb;
  logic       apb_req_is_mem_debug;
  logic       apb_resp_valid;
  logic [7:0] apb_resp_status;
  logic [APB_DATA_WIDTH-1:0] apb_resp_rdata;

  logic       req_valid, req_source, req_write;
  logic [7:0] req_addr;
  logic [APB_DATA_WIDTH-1:0] req_wdata;
  logic [3:0]  req_wstrb;

  // Separate response signals for reg_file and memory_window
  logic       reg_req_ready, reg_resp_valid;
  logic [7:0] reg_resp_status;
  logic [APB_DATA_WIDTH-1:0] reg_resp_rdata;

  logic       mem_req_ready, mem_resp_valid;
  logic [7:0] mem_resp_status;
  logic [APB_DATA_WIDTH-1:0] mem_resp_rdata;

  // Muxed response signals
  logic       resp_valid;
  logic [7:0] resp_status;
  logic [APB_DATA_WIDTH-1:0] resp_rdata;
  logic       req_ready;

  // Register signals
  logic [7:0] ctrl_reg, irq_mask_reg, fifo_watermark_reg, loopback_ctrl_reg;
  logic [7:0] irq_status;
  logic [7:0] last_status;
  logic       cmd_busy, arbiter_busy;
  logic       rx_count_inc, error_count_inc, tx_count_inc;

  // IRQ signals
  logic cmd_done_irq, error_seen_irq_from_parser, error_seen_irq;
  logic rx_overflow_irq, tx_overflow_irq;
  logic fifo_watermark_irq, apb_error_irq;
  logic irq_clear_read;

  // Soft reset
  logic soft_reset;

  // Loopback
  logic loopback_en;
  assign loopback_en = loopback_ctrl_reg[0];

  // Busy signal
  assign busy_o = cmd_busy || arbiter_busy || tx_busy;

  // Response mux based on req_source
  // req_source = 0 for reg_file, req_source = 1 for memory_window
  assign req_ready = req_source ? mem_req_ready : reg_req_ready;
  assign resp_valid = req_source ? mem_resp_valid : reg_resp_valid;
  assign resp_status = req_source ? mem_resp_status : reg_resp_status;
  assign resp_rdata = req_source ? mem_resp_rdata : reg_resp_rdata;

  // Error seen IRQ mux
  assign error_seen_irq = error_seen_irq_from_parser || error_count_inc;

  // RX FIFO read enable - read when parser is ready and FIFO is not empty
  assign rx_fifo_rd_en = parser_rx_ready && !rx_fifo_empty;

  // Counters
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_packet_count <= '0;
      tx_packet_count <= '0;
      error_count     <= '0;
      last_error      <= '0;
      soft_reset_seen <= 1'b0;
    end else begin
      if (soft_reset) begin
        // Soft reset preserves counters
        soft_reset_seen <= 1'b1;
      end

      if (rx_count_inc) rx_packet_count <= rx_packet_count + 1'b1;
      if (tx_count_inc) tx_packet_count <= tx_packet_count + 1'b1;
      if (error_count_inc) begin
        error_count <= error_count + 1'b1;
        if (last_status != 8'h00) begin
          last_error <= last_status[3:0];
        end
      end
    end
  end

  // IRQ status signals
  assign cmd_done_irq = rx_count_inc;
  assign apb_error_irq = pslverr;

  // FIFO watermark check
  logic rx_fifo_watermark, tx_fifo_watermark;
  logic [$clog2(FIFO_DEPTH):0] rx_fifo_level, tx_fifo_level;

  assign rx_fifo_watermark = (rx_fifo_level >= fifo_watermark_reg);
  assign tx_fifo_watermark = (tx_fifo_level >= fifo_watermark_reg);
  assign fifo_watermark_irq = rx_fifo_watermark || tx_fifo_watermark;

  // Baud tick generator
  baud_tick_gen #(
    .CLK_FREQ_HZ (CLK_FREQ_HZ),
    .BAUD_RATE   (BAUD_RATE),
    .OVERSAMPLE  (OVERSAMPLE)
  ) u_baud_tick_gen (
    .clk            (clk),
    .rst_n          (rst_n),
    .baud_tick      (baud_tick),
    .oversample_tick (oversample_tick)
  );

  // UART RX
  uart_rx #(
    .DATA_WIDTH (DATA_WIDTH),
    .OVERSAMPLE (OVERSAMPLE)
  ) u_uart_rx (
    .clk            (clk),
    .rst_n          (rst_n),
    .oversample_tick (oversample_tick),
    .rx_in          (uart_rx_i),
    .rx_data        (rx_byte_from_uart),
    .rx_valid       (rx_valid_from_uart),
    .rx_ready       (rx_ready_from_uart),
    .framing_error  (framing_error)
  );

  // RX FIFO
  byte_fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .DEPTH      (FIFO_DEPTH)
  ) u_rx_fifo (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (rx_valid_from_uart && !loopback_en),
    .wr_data  (rx_byte_from_uart),
    .rd_en    (rx_fifo_rd_en),
    .rd_data  (rx_byte_from_fifo),
    .full     (rx_overflow_irq),
    .empty    (rx_fifo_empty),
    .level    (rx_fifo_level)
  );

  // TX FIFO
  byte_fifo #(
    .DATA_WIDTH (DATA_WIDTH),
    .DEPTH      (FIFO_DEPTH)
  ) u_tx_fifo (
    .clk      (clk),
    .rst_n    (rst_n),
    .wr_en    (tx_wr_en),
    .wr_data  (tx_byte_to_fifo),
    .rd_en    (tx_start && !tx_busy),
    .rd_data  (tx_byte_from_fifo),
    .full     (tx_overflow_irq),
    .empty    (tx_empty),
    .level    (tx_fifo_level)
  );

  // UART TX
  uart_tx #(
    .DATA_WIDTH (DATA_WIDTH)
  ) u_uart_tx (
    .clk      (clk),
    .rst_n    (rst_n),
    .baud_tick (baud_tick),
    .tx_start (tx_start),
    .tx_data  (tx_byte_from_fifo),
    .tx_out   (uart_tx_o),
    .tx_busy  (tx_busy),
    .tx_done  (tx_done)
  );

  // Packet parser - reads from RX FIFO
  packet_parser #(
    .MAX_PAYLOAD_BYTES (MAX_PAYLOAD_BYTES),
    .TIMEOUT_BITS      (TIMEOUT_BITS),
    .INTER_BYTE_TIMEOUT (INTER_BYTE_TIMEOUT)
  ) u_packet_parser (
    .clk                (clk),
    .rst_n              (rst_n),
    .cfg_enable         (cfg_enable),
    .timeout_enable     (ctrl_reg[2]),
    .rx_byte            (rx_byte_from_fifo),
    .rx_valid           (!rx_fifo_empty),
    .rx_ready           (parser_rx_ready),
    .cmd_valid          (cmd_valid),
    .cmd_ready          (cmd_ready),
    .cmd_seq            (cmd_seq),
    .cmd_opcode         (cmd_opcode),
    .cmd_len            (cmd_len),
    .cmd_payload        (cmd_payload),
    .cmd_status         (cmd_status),
    .cmd_from_parser_error (cmd_from_parser_error),
    .error_strobe       (error_seen_irq_from_parser),
    .error_status       ()
  );

  // Command arbiter
  command_arbiter u_command_arbiter (
    .clk            (clk),
    .rst_n          (rst_n),
    .uart_req_valid (uart_req_valid),
    .uart_req_ready (uart_req_ready),
    .uart_req_write (uart_req_write),
    .uart_req_addr  (uart_req_addr),
    .uart_req_wdata (uart_req_wdata),
    .uart_req_wstrb (uart_req_wstrb),
    .uart_resp_valid (uart_resp_valid),
    .uart_resp_status (uart_resp_status),
    .uart_resp_rdata (uart_resp_rdata),
    .apb_req_valid  (apb_req_valid),
    .apb_req_ready  (apb_req_ready),
    .apb_req_write  (apb_req_write),
    .apb_req_addr   (apb_req_addr),
    .apb_req_wdata  (apb_req_wdata),
    .apb_req_wstrb  (apb_req_wstrb),
    .apb_req_is_mem_debug (apb_req_is_mem_debug),
    .apb_resp_valid (apb_resp_valid),
    .apb_resp_status (apb_resp_status),
    .apb_resp_rdata (apb_resp_rdata),
    .req_valid      (req_valid),
    .req_ready      (req_ready),
    .req_source     (req_source),
    .req_write      (req_write),
    .req_addr       (req_addr),
    .req_wdata      (req_wdata),
    .req_wstrb      (req_wstrb),
    .resp_valid     (resp_valid),
    .resp_status    (resp_status),
    .resp_rdata     (resp_rdata),
    .arbiter_busy   (arbiter_busy)
  );

  // Command engine
  command_engine #(
    .MAX_PAYLOAD_BYTES (MAX_PAYLOAD_BYTES),
    .MEM_ADDR_WIDTH    (MEM_ADDR_WIDTH)
  ) u_command_engine (
    .clk            (clk),
    .rst_n          (rst_n),
    .cfg_enable     (cfg_enable),
    .cmd_valid      (cmd_valid),
    .cmd_ready      (cmd_ready),
    .cmd_seq        (cmd_seq),
    .cmd_opcode     (cmd_opcode),
    .cmd_len        (cmd_len),
    .cmd_payload    (cmd_payload),
    .cmd_status     (cmd_status),
    .cmd_from_parser_error (cmd_from_parser_error),
    .req_valid      (uart_req_valid),
    .req_ready      (uart_req_ready),
    .req_write      (uart_req_write),
    .req_addr       (uart_req_addr),
    .req_wdata      (uart_req_wdata),
    .req_wstrb      (uart_req_wstrb),
    .resp_valid     (uart_resp_valid),
    .resp_status    (uart_resp_status),
    .resp_rdata     (uart_resp_rdata),
    .rsp_valid      (rsp_valid),
    .rsp_ready      (rsp_ready),
    .rsp_seq_echo   (rsp_seq_echo),
    .rsp_cmd_echo   (rsp_cmd_echo),
    .rsp_status     (rsp_status),
    .rsp_len        (rsp_len),
    .rsp_payload    (rsp_payload),
    .cmd_busy       (cmd_busy),
    .rx_count_inc   (rx_count_inc),
    .error_count_inc (error_count_inc),
    .last_status    (last_status)
  );

  // Register file
  reg_file #(
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH),
    .APB_DATA_WIDTH (APB_DATA_WIDTH)
  ) u_reg_file (
    .clk            (clk),
    .rst_n          (rst_n),
    .soft_reset     (soft_reset),
    .req_valid      (req_valid && !req_source),
    .req_ready      (reg_req_ready),
    .req_write      (req_write),
    .req_addr       (req_addr),
    .req_wdata      (req_wdata),
    .req_wstrb      (req_wstrb),
    .resp_valid     (reg_resp_valid),
    .resp_status    (reg_resp_status),
    .resp_rdata     (reg_resp_rdata),
    .ctrl_reg       (ctrl_reg),
    .irq_mask_reg   (irq_mask_reg),
    .fifo_watermark_reg (fifo_watermark_reg),
    .loopback_ctrl_reg (loopback_ctrl_reg),
    .irq_status     (irq_status),
    .last_status    (last_status),
    .last_error     (last_error),
    .rx_packet_count (rx_packet_count),
    .error_count    (error_count),
    .tx_packet_count (tx_packet_count),
    .irq_clear_read (irq_clear_read),
    .irq_clear_ext  (irq_clear)
  );

  // Memory window
  memory_window #(
    .MEM_ADDR_WIDTH (MEM_ADDR_WIDTH),
    .APB_DATA_WIDTH (APB_DATA_WIDTH)
  ) u_memory_window (
    .clk        (clk),
    .rst_n      (rst_n),
    .soft_reset (soft_reset),
    .req_valid  (req_valid && req_source),
    .req_ready  (mem_req_ready),
    .req_write  (req_write),
    .req_addr   (req_addr),
    .req_wdata  (req_wdata),
    .req_wstrb  (req_wstrb),
    .resp_valid (mem_resp_valid),
    .resp_status (mem_resp_status),
    .resp_rdata (mem_resp_rdata)
  );

  // Response builder
  response_builder #(
    .MAX_PAYLOAD_BYTES (MAX_PAYLOAD_BYTES),
    .DATA_WIDTH        (DATA_WIDTH)
  ) u_response_builder (
    .clk            (clk),
    .rst_n          (rst_n),
    .cfg_enable     (cfg_enable),
    .response_enable (ctrl_reg[0]),
    .rsp_valid      (rsp_valid),
    .rsp_ready      (rsp_ready),
    .rsp_seq_echo   (rsp_seq_echo),
    .rsp_cmd_echo   (rsp_cmd_echo),
    .rsp_status     (rsp_status),
    .rsp_len        (rsp_len),
    .rsp_payload    (rsp_payload),
    .tx_wr_en       (tx_wr_en),
    .tx_wr_data     (tx_byte_to_fifo),
    .tx_full        (tx_overflow_irq),
    .tx_count_inc   (tx_count_inc)
  );

  // IRQ status control
  irq_status_ctrl u_irq_status_ctrl (
    .clk            (clk),
    .rst_n          (rst_n),
    .soft_reset     (soft_reset),
    .cmd_done       (cmd_done_irq),
    .error_seen     (error_seen_irq),
    .rx_overflow    (rx_overflow_irq),
    .tx_overflow    (tx_overflow_irq),
    .fifo_watermark (fifo_watermark_irq),
    .apb_error      (apb_error_irq),
    .irq_mask       (irq_mask_reg),
    .irq_clear_ext  (irq_clear),
    .irq_clear_read (irq_clear_read),
    .irq_status     (irq_status),
    .irq_o          (irq_o)
  );

  // APB-Lite slave
  apb_lite_slave #(
    .APB_ADDR_WIDTH (APB_ADDR_WIDTH),
    .APB_DATA_WIDTH (APB_DATA_WIDTH)
  ) u_apb_lite_slave (
    .clk            (clk),
    .rst_n          (rst_n),
    .paddr          (paddr),
    .psel           (psel),
    .penable        (penable),
    .pwrite         (pwrite),
    .pwdata         (pwdata),
    .pstrb          (pstrb),
    .prdata         (prdata),
    .pready         (pready),
    .pslverr        (pslverr),
    .req_valid      (apb_req_valid),
    .req_ready      (apb_req_ready),
    .req_write      (apb_req_write),
    .req_addr       (apb_req_addr),
    .req_wdata      (apb_req_wdata),
    .req_wstrb      (apb_req_wstrb),
    .req_is_mem_debug (apb_req_is_mem_debug),
    .resp_valid     (apb_resp_valid),
    .resp_status    (apb_resp_status),
    .resp_rdata     (apb_resp_rdata),
    .arbiter_busy   (arbiter_busy)
  );

  // Soft reset logic
  assign soft_reset = (cmd_opcode == 8'h7E) && cmd_valid && !cmd_from_parser_error &&
                      (cmd_len == 5'd2) && (cmd_payload[15:0] == 16'hDEAD);

endmodule
