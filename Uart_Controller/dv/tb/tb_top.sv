module tb_top;

  // Parameters
  parameter int CLK_FREQ_HZ       = 50_000_000;
  parameter int BAUD_RATE         = 115_200;
  parameter int OVERSAMPLE        = 16;
  parameter int DATA_WIDTH        = 8;
  parameter int FIFO_DEPTH        = 32;
  parameter int MAX_PAYLOAD_BYTES = 16;
  parameter int MEM_ADDR_WIDTH    = 4;
  parameter int APB_ADDR_WIDTH    = 8;
  parameter int APB_DATA_WIDTH    = 32;
  parameter int TIMEOUT_BITS      = 16;
  parameter int INTER_BYTE_TIMEOUT = 50_000;

  // Clock and reset
  logic clk;
  logic rst_n;

  // UART interface
  logic uart_rx_i;
  logic uart_tx_o;

  // Control inputs
  logic cfg_enable;
  logic irq_clear;
  logic soft_reset_clear;

  // APB-Lite interface
  logic [APB_ADDR_WIDTH-1:0]  paddr;
  logic psel;
  logic penable;
  logic pwrite;
  logic [APB_DATA_WIDTH-1:0]  pwdata;
  logic [APB_DATA_WIDTH/8-1:0] pstrb;
  logic [APB_DATA_WIDTH-1:0]  prdata;
  logic pready;
  logic pslverr;

  // Status outputs
  logic irq_o;
  logic busy_o;
  logic [15:0] rx_packet_count;
  logic [15:0] tx_packet_count;
  logic [15:0] error_count;
  logic [3:0]  last_error;
  logic        soft_reset_seen;

  // Clock generation
  initial clk = 0;
  always #10 clk = ~clk; // 50MHz clock

  // DUT instantiation
  uart_packet_controller #(
    .CLK_FREQ_HZ       (CLK_FREQ_HZ),
    .BAUD_RATE         (BAUD_RATE),
    .OVERSAMPLE        (OVERSAMPLE),
    .DATA_WIDTH        (DATA_WIDTH),
    .FIFO_DEPTH        (FIFO_DEPTH),
    .MAX_PAYLOAD_BYTES (MAX_PAYLOAD_BYTES),
    .MEM_ADDR_WIDTH    (MEM_ADDR_WIDTH),
    .APB_ADDR_WIDTH    (APB_ADDR_WIDTH),
    .APB_DATA_WIDTH    (APB_DATA_WIDTH),
    .TIMEOUT_BITS      (TIMEOUT_BITS),
    .INTER_BYTE_TIMEOUT (INTER_BYTE_TIMEOUT)
  ) dut (
    .clk              (clk),
    .rst_n            (rst_n),
    .uart_rx_i        (uart_rx_i),
    .uart_tx_o        (uart_tx_o),
    .cfg_enable       (cfg_enable),
    .irq_clear        (irq_clear),
    .soft_reset_clear (soft_reset_clear),
    .paddr            (paddr),
    .psel             (psel),
    .penable          (penable),
    .pwrite           (pwrite),
    .pwdata           (pwdata),
    .pstrb            (pstrb),
    .prdata           (prdata),
    .pready           (pready),
    .pslverr          (pslverr),
    .irq_o            (irq_o),
    .busy_o           (busy_o),
    .rx_packet_count  (rx_packet_count),
    .tx_packet_count  (tx_packet_count),
    .error_count      (error_count),
    .last_error       (last_error),
    .soft_reset_seen  (soft_reset_seen)
  );

  // CRC-8 calculation function
  function automatic logic [7:0] crc8_calc(input logic [7:0] data[], input int len);
    logic [7:0] crc;
    logic [7:0] result;
    crc = 8'h00;
    for (int i = 0; i < len; i++) begin
      result = crc ^ data[i];
      for (int j = 0; j < 8; j++) begin
        if (result[7])
          result = (result << 1) ^ 8'h07;
        else
          result = result << 1;
      end
      crc = result;
    end
    return crc;
  endfunction

  // Test sequence
  initial begin
    logic [7:0] pkt_data[];
    logic [7:0] crc_val;

    // Initialize
    rst_n = 0;
    cfg_enable = 0;
    irq_clear = 0;
    soft_reset_clear = 0;
    uart_rx_i = 1; // Idle high
    paddr = '0;
    psel = 0;
    penable = 0;
    pwrite = 0;
    pwdata = '0;
    pstrb = '0;

    // Reset
    repeat(10) @(posedge clk);
    rst_n = 1;
    repeat(5) @(posedge clk);

    // Enable configuration
    cfg_enable = 1;
    repeat(5) @(posedge clk);

    // Test 1: Send PING command via UART
    $display("Test 1: Sending PING command");
    // Build packet: START, SEQ, CMD, LEN, CRC, END
    pkt_data = new[3];
    pkt_data[0] = 8'h01; // SEQ
    pkt_data[1] = 8'h01; // CMD (PING)
    pkt_data[2] = 8'h00; // LEN
    crc_val = crc8_calc(pkt_data, 3);

    send_uart_byte(8'hA5); // START
    send_uart_byte(8'h01); // SEQ
    send_uart_byte(8'h01); // CMD (PING)
    send_uart_byte(8'h00); // LEN
    send_uart_byte(crc_val); // CRC
    send_uart_byte(8'h5A); // END

    // Wait for response
    repeat(5000) @(posedge clk);

    // Check results
    $display("After PING: rx_packet_count = %0d, tx_packet_count = %0d", rx_packet_count, tx_packet_count);

    // Test 2: APB register read
    $display("Test 2: APB register read");
    @(posedge clk);
    paddr = 8'h00; // CTRL register
    psel = 1;
    penable = 0;
    pwrite = 0;
    @(posedge clk);
    penable = 1;
    @(posedge clk);
    wait(pready);
    $display("APB Read: addr=%h, data=%h", paddr, prdata);
    psel = 0;
    penable = 0;

    // Test 3: APB register write
    $display("Test 3: APB register write");
    @(posedge clk);
    paddr = 8'h02; // IRQ_MASK register
    psel = 1;
    penable = 0;
    pwrite = 1;
    pwdata = 32'h000000FF;
    pstrb = 4'b0001;
    @(posedge clk);
    penable = 1;
    @(posedge clk);
    wait(pready);
    psel = 0;
    penable = 0;
    pwrite = 0;

    // Final check
    repeat(100) @(posedge clk);
    $display("Simulation complete");
    $display("rx_packet_count = %0d", rx_packet_count);
    $display("tx_packet_count = %0d", tx_packet_count);
    $display("error_count = %0d", error_count);
    $display("last_error = %h", last_error);
    $display("soft_reset_seen = %b", soft_reset_seen);

    if (rx_packet_count > 0 && tx_packet_count > 0) begin
      $display("TEST_PASS");
    end else begin
      $display("TEST_FAIL");
    end

    $finish;
  end

  // UART byte send task
  task send_uart_byte(input logic [7:0] data);
    real bit_time;
    bit_time = 1.0 / BAUD_RATE * 1e9; // in ns

    // Start bit
    uart_rx_i = 0;
    #(bit_time);

    // Data bits (LSB first)
    for (int i = 0; i < 8; i++) begin
      uart_rx_i = data[i];
      #(bit_time);
    end

    // Stop bit
    uart_rx_i = 1;
    #(bit_time);
  endtask

  // Monitor UART TX
  initial begin
    forever begin
      @(negedge uart_tx_o);
      $display("[%0t] UART TX start detected", $time);
      // Wait for response packet
      repeat(10) begin
        #(1.0 / BAUD_RATE * 1e9);
      end
    end
  end

  // Waveform dump
  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_top);
  end

endmodule
