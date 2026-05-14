// GPIO Top Module
// 8-bit output (LED), 4-bit input (buttons).

module gpio_top
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

  // GPIO pins
  output logic [7:0]  gpio_out_o,
  input  logic [3:0]  gpio_in_i,

  // Interrupt
  output logic        irq_o
);

  // Register offsets
  localparam bit [3:0] GPIO_DATA_OUT = 4'h0;
  localparam bit [3:0] GPIO_DATA_IN  = 4'h4;
  localparam bit [3:0] GPIO_DIR      = 4'h8;

  // Output register
  logic [7:0] data_out_q;
  logic [3:0] data_in_sync, data_in_sync2;

  // Synchronize input
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_in_sync  <= '0;
      data_in_sync2 <= '0;
    end else begin
      data_in_sync  <= gpio_in_i;
      data_in_sync2 <= data_in_sync;
    end
  end

  // APB write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out_q <= '0;
    end else begin
      if (psel_i && penable_i && pwrite_i) begin
        if (paddr_i[3:0] == GPIO_DATA_OUT) begin
          data_out_q <= pwdata_i[7:0];
        end
      end
    end
  end

  // APB read
  always_comb begin
    prdata_o = '0;
    pready_o = 1'b1;
    pslverr_o = 1'b0;

    if (psel_i && !pwrite_i) begin
      unique case (paddr_i[3:0])
        GPIO_DATA_OUT: prdata_o = {24'b0, data_out_q};
        GPIO_DATA_IN:  prdata_o = {28'b0, data_in_sync2};
        default:       prdata_o = '0;
      endcase
    end
  end

  // Output
  assign gpio_out_o = data_out_q;

  // No interrupt for simple GPIO
  assign irq_o = 1'b0;

endmodule
