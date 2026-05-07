module baud_tick_gen
  #(parameter int CLK_FREQ_HZ    = 50_000_000,
    parameter int BAUD_RATE      = 115_200,
    parameter int OVERSAMPLE     = 16)
   (input  logic clk,
    input  logic rst_n,
    output logic baud_tick,
    output logic oversample_tick);

  localparam int BAUD_DIV   = CLK_FREQ_HZ / BAUD_RATE;
  localparam int OSAMP_DIV  = BAUD_DIV / OVERSAMPLE;

  logic [$clog2(BAUD_DIV)-1:0]  baud_cnt;
  logic [$clog2(OSAMP_DIV)-1:0] osamp_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_cnt        <= '0;
      baud_tick       <= 1'b0;
    end else begin
      if (baud_cnt == BAUD_DIV - 1) begin
        baud_cnt  <= '0;
        baud_tick <= 1'b1;
      end else begin
        baud_cnt  <= baud_cnt + 1'b1;
        baud_tick <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      osamp_cnt       <= '0;
      oversample_tick <= 1'b0;
    end else begin
      if (osamp_cnt == OSAMP_DIV - 1) begin
        osamp_cnt       <= '0;
        oversample_tick <= 1'b1;
      end else begin
        osamp_cnt       <= osamp_cnt + 1'b1;
        oversample_tick <= 1'b0;
      end
    end
  end

endmodule
