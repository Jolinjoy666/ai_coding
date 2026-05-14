// Timer Top Module
// Simple 32-bit timer with compare match interrupt.

module timer_top
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

  // Interrupt
  output logic        irq_o
);

  // Register offsets
  localparam bit [3:0] TIMER_COUNT  = 4'h0;
  localparam bit [3:0] TIMER_COMPARE = 4'h4;
  localparam bit [3:0] TIMER_CTRL   = 4'h8;
  localparam bit [3:0] TIMER_STATUS = 4'hC;

  // Timer registers
  logic [31:0] count_q, count_d;
  logic [31:0] compare_q;
  logic        enable_q;
  logic        irq_en_q;
  logic        irq_status_q;

  // Count logic
  always_comb begin
    count_d = count_q;
    if (enable_q) begin
      count_d = count_q + 1;
    end
  end

  // APB write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count_q    <= '0;
      compare_q  <= '0;
      enable_q   <= 1'b0;
      irq_en_q   <= 1'b0;
      irq_status_q <= 1'b0;
    end else begin
      count_q <= count_d;

      // Compare match
      if (enable_q && count_d == compare_q) begin
        irq_status_q <= 1'b1;
      end

      // APB write
      if (psel_i && penable_i && pwrite_i) begin
        unique case (paddr_i[3:0])
          TIMER_COUNT:   count_q <= pwdata_i;
          TIMER_COMPARE: compare_q <= pwdata_i;
          TIMER_CTRL: begin
            enable_q <= pwdata_i[0];
            irq_en_q <= pwdata_i[1];
          end
          TIMER_STATUS: begin
            if (pwdata_i[0]) irq_status_q <= 1'b0;  // W1C
          end
          default: ;
        endcase
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
        TIMER_COUNT:   prdata_o = count_q;
        TIMER_COMPARE: prdata_o = compare_q;
        TIMER_CTRL:    prdata_o = {30'b0, irq_en_q, enable_q};
        TIMER_STATUS:  prdata_o = {31'b0, irq_status_q};
        default:       prdata_o = '0;
      endcase
    end
  end

  // Interrupt
  assign irq_o = irq_status_q & irq_en_q;

endmodule
