module uvm_tb_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Clock and reset
  logic clk;
  logic rst_n;

  // Clock generation: 50MHz (20ns period)
  initial begin
    clk = 0;
    forever #10 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 0;
    repeat (10) @(posedge clk);
    rst_n = 1;
  end

  // APB interface
  apb_if apb_vif(clk);

  // DUT signals
  logic        uart_rx;
  logic        uart_tx;
  logic [7:0]  gpio_out;
  logic [3:0]  gpio_in;
  logic        irq;

  // Tie GPIO input to a known value
  assign gpio_in = gpio_out[3:0];  // Loopback for testing

  // Tie UART RX idle
  assign uart_rx = 1'b1;

  // DUT instantiation
  attentioncore_soc_top u_dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .uart_rx        (uart_rx),
    .uart_tx        (uart_tx),
    .gpio_out       (gpio_out),
    .gpio_in        (gpio_in),
    .irq            (irq),
    .test_mode_i    (1'b1),           // Bypass RISC-V core
    .test_paddr_i   (apb_vif.paddr),
    .test_psel_i    (apb_vif.psel),
    .test_penable_i (apb_vif.penable),
    .test_pwrite_i  (apb_vif.pwrite),
    .test_pwdata_i  (apb_vif.pwdata),
    .test_prdata_o  (apb_vif.prdata),
    .test_pready_o  (apb_vif.pready),
    .test_pslverr_o (apb_vif.pslverr)
  );

  // Set virtual interface for UVM
  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "uvm_test_top*", "apb_vif", apb_vif);
  end

  // Waveform dump (if +WAVE plusarg)
  initial begin
    if ($test$plusargs("WAVE")) begin
      $fsdbDumpfile("uvm_waves.fsdb");
      $fsdbDumpvars(0, uvm_tb_top);
    end
  end

  // Run test
  initial begin
    run_test();
  end

  // Timeout watchdog
  initial begin
    #100_000_000;  // 100ms timeout
    `uvm_fatal("TIMEOUT", "Simulation timed out")
  end
endmodule
