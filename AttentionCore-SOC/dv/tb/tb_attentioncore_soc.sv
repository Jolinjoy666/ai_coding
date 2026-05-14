// AttentionCore-SOC Testbench
// Basic testbench for SOC-level verification.

`timescale 1ns/1ps

module tb_attentioncore_soc;

  import soc_params_pkg::*;

  // Clock and reset
  logic clk;
  logic rst_n;

  // UART
  logic uart_rx;
  logic uart_tx;

  // GPIO
  logic [7:0] gpio_out;
  logic [3:0] gpio_in;

  // Interrupt
  logic irq;

  // DUT instance
  attentioncore_soc_top u_dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .gpio_out (gpio_out),
    .gpio_in  (gpio_in),
    .irq      (irq)
  );

  // Clock generation: 100MHz
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation
  initial begin
    rst_n = 0;
    uart_rx = 1;
    gpio_in = 0;
    #100;
    rst_n = 1;
  end

  // Test sequence
  initial begin
    // Wait for reset
    @(posedge rst_n);
    #100;

    // Test 1: Basic register access
    $display("[%0t] Test 1: Basic register access", $time);

    // Write to CTRL register via APB
    // (In real testbench, would drive APB signals directly)

    // Test 2: Load weights via UART
    $display("[%0t] Test 2: Load weights via UART", $time);

    // Test 3: Trigger inference
    $display("[%0t] Test 3: Trigger inference", $time);

    // Test 4: Wait for completion
    $display("[%0t] Test 4: Wait for completion", $time);

    // End simulation
    #1000;
    $display("[%0t] Simulation complete", $time);
    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("tb_attentioncore_soc.vcd");
    $dumpvars(0, tb_attentioncore_soc);
  end

  // Timeout
  initial begin
    #100000;
    $display("[%0t] ERROR: Simulation timeout!", $time);
    $finish;
  end

endmodule
