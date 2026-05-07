module irq_status_ctrl
  (input  logic clk,
   input  logic rst_n,
   input  logic soft_reset,
   // IRQ source inputs
   input  logic cmd_done,
   input  logic error_seen,
   input  logic rx_overflow,
   input  logic tx_overflow,
   input  logic fifo_watermark,
   input  logic apb_error,
   // IRQ control
   input  logic [7:0] irq_mask,
   input  logic       irq_clear_ext,
   input  logic       irq_clear_read,
   // IRQ output
   output logic [7:0] irq_status,
   output logic       irq_o);

  logic [7:0] irq_status_r;

  assign irq_status = irq_status_r;
  assign irq_o = |(irq_status_r & irq_mask);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      irq_status_r <= '0;
    end else if (soft_reset) begin
      irq_status_r <= '0;
    end else begin
      // Set sticky bits
      if (cmd_done)     irq_status_r[0] <= 1'b1;
      if (error_seen)   irq_status_r[1] <= 1'b1;
      if (rx_overflow)  irq_status_r[2] <= 1'b1;
      if (tx_overflow)  irq_status_r[3] <= 1'b1;
      if (fifo_watermark) irq_status_r[4] <= 1'b1;
      if (apb_error)    irq_status_r[5] <= 1'b1;

      // Clear
      if (irq_clear_ext) begin
        irq_status_r <= '0;
      end else if (irq_clear_read) begin
        // Read-clear: clear after read
        irq_status_r <= '0;
      end
    end
  end

endmodule
