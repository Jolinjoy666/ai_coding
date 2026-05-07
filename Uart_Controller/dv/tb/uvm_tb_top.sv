module uvm_tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_pkg::*;
  import apb_pkg::*;
  import uart_env_pkg::*;
  import uart_sequences_pkg::*;
  import uart_tests_pkg::*;

  // Clock generation
  logic clk;
  initial clk = 0;
  always #10 clk = ~clk; // 50MHz

  // Reset
  logic rst_n;
  initial begin
    rst_n = 0;
    repeat(10) @(posedge clk);
    rst_n = 1;
  end

  // Interface instances
  uart_if uart_vif();
  apb_if apb_vif(.clk(clk));

  // Control signals
  logic cfg_enable;
  logic irq_clear;
  logic soft_reset_clear;

  // Status signals
  logic irq_o;
  logic busy_o;
  logic [15:0] rx_packet_count;
  logic [15:0] tx_packet_count;
  logic [15:0] error_count;
  logic [3:0]  last_error;
  logic        soft_reset_seen;

  // DUT instantiation
  uart_packet_controller #(
    .CLK_FREQ_HZ(50_000_000),
    .BAUD_RATE(115_200),
    .OVERSAMPLE(16),
    .DATA_WIDTH(8),
    .FIFO_DEPTH(32),
    .MAX_PAYLOAD_BYTES(16),
    .MEM_ADDR_WIDTH(4),
    .APB_ADDR_WIDTH(8),
    .APB_DATA_WIDTH(32),
    .TIMEOUT_BITS(16),
    .INTER_BYTE_TIMEOUT(50_000)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .uart_rx_i(uart_vif.rx_i),
    .uart_tx_o(uart_vif.tx_o),
    .cfg_enable(cfg_enable),
    .irq_clear(irq_clear),
    .soft_reset_clear(soft_reset_clear),
    .paddr(apb_vif.paddr),
    .psel(apb_vif.psel),
    .penable(apb_vif.penable),
    .pwrite(apb_vif.pwrite),
    .pwdata(apb_vif.pwdata),
    .pstrb(apb_vif.pstrb),
    .prdata(apb_vif.prdata),
    .pready(apb_vif.pready),
    .pslverr(apb_vif.pslverr),
    .irq_o(irq_o),
    .busy_o(busy_o),
    .rx_packet_count(rx_packet_count),
    .tx_packet_count(tx_packet_count),
    .error_count(error_count),
    .last_error(last_error),
    .soft_reset_seen(soft_reset_seen)
  );

  // Initialize control signals
  initial begin
    cfg_enable = 1'b1;
    irq_clear = 1'b0;
    soft_reset_clear = 1'b0;
  end

  // Set interfaces in config database
  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "uvm_test_top*", "uart_vif", uart_vif);
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top*", "apb_vif", apb_vif);
  end

  // Run test
  initial begin
    run_test();
  end

  // Waveform dump
  initial begin
    $dumpfile("uvm_wave.vcd");
    $dumpvars(0, uvm_tb_top);
  end

  // Monitor UART TX for debug
  initial begin
    forever begin
      @(negedge uart_vif.tx_o);
      `uvm_info("TB", $sformatf("[%0t] UART TX start detected", $time), UVM_HIGH)
    end
  end
endmodule
