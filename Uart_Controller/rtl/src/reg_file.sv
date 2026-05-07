module reg_file
  #(parameter int APB_ADDR_WIDTH = 8,
    parameter int APB_DATA_WIDTH = 32)
   (input  logic       clk,
    input  logic       rst_n,
    input  logic       soft_reset,
    // Register access interface
    input  logic       req_valid,
    output logic       req_ready,
    input  logic       req_write,
    input  logic [7:0] req_addr,
    input  logic [APB_DATA_WIDTH-1:0] req_wdata,
    input  logic [3:0]  req_wstrb,
    output logic       resp_valid,
    output logic [7:0] resp_status,
    output logic [APB_DATA_WIDTH-1:0] resp_rdata,
    // Register outputs
    output logic [7:0] ctrl_reg,
    output logic [7:0] irq_mask_reg,
    output logic [7:0] fifo_watermark_reg,
    output logic [7:0] loopback_ctrl_reg,
    // Status inputs
    input  logic [7:0] irq_status,
    input  logic [7:0] last_status,
    input  logic [3:0] last_error,
    input  logic [15:0] rx_packet_count,
    input  logic [15:0] error_count,
    input  logic [15:0] tx_packet_count,
    // IRQ status clear
    output logic       irq_clear_read,
    input  logic       irq_clear_ext);

  // Register addresses
  localparam logic [7:0] ADDR_CTRL           = 8'h00;
  localparam logic [7:0] ADDR_IRQ_STATUS     = 8'h01;
  localparam logic [7:0] ADDR_IRQ_MASK       = 8'h02;
  localparam logic [7:0] ADDR_LAST_STATUS    = 8'h03;
  localparam logic [7:0] ADDR_RX_COUNT_L     = 8'h04;
  localparam logic [7:0] ADDR_RX_COUNT_H     = 8'h05;
  localparam logic [7:0] ADDR_ERR_COUNT_L    = 8'h06;
  localparam logic [7:0] ADDR_ERR_COUNT_H    = 8'h07;
  localparam logic [7:0] ADDR_TX_COUNT_L     = 8'h08;
  localparam logic [7:0] ADDR_TX_COUNT_H     = 8'h09;
  localparam logic [7:0] ADDR_FIFO_WATERMARK = 8'h0A;
  localparam logic [7:0] ADDR_LOOPBACK_CTRL  = 8'h0B;
  localparam logic [7:0] ADDR_MEM_DEBUG_BASE = 8'h10;
  localparam logic [7:0] ADDR_MEM_DEBUG_END  = 8'h1F;

  // Status codes
  localparam logic [7:0] STATUS_OK         = 8'h00;
  localparam logic [7:0] STATUS_ADDR_ERROR = 8'h04;

  // Registers
  logic [7:0] ctrl_reg_r;
  logic [7:0] irq_status_r;
  logic [7:0] irq_mask_reg_r;
  logic [7:0] last_status_r;
  logic [7:0] fifo_watermark_reg_r;
  logic [7:0] loopback_ctrl_reg_r;

  // Memory debug bytes
  logic [7:0] mem_debug [16];

  // Read-clear tracking
  logic irq_clear_pending;

  assign ctrl_reg           = ctrl_reg_r;
  assign irq_mask_reg       = irq_mask_reg_r;
  assign fifo_watermark_reg = fifo_watermark_reg_r;
  assign loopback_ctrl_reg  = loopback_ctrl_reg_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_reg_r           <= 8'h01;
      irq_status_r         <= '0;
      irq_mask_reg_r       <= 8'h03;
      last_status_r        <= '0;
      fifo_watermark_reg_r <= 8'h10;
      loopback_ctrl_reg_r  <= '0;
      irq_clear_pending    <= 1'b0;
      for (int i = 0; i < 16; i++) mem_debug[i] <= '0;
      resp_valid   <= 1'b0;
      resp_status  <= '0;
      resp_rdata   <= '0;
      req_ready    <= 1'b0;
      irq_clear_read <= 1'b0;
    end else begin
      resp_valid <= 1'b0;
      req_ready  <= 1'b0;
      irq_clear_read <= 1'b0;

      // Soft reset
      if (soft_reset) begin
        ctrl_reg_r           <= 8'h01;
        irq_mask_reg_r       <= 8'h03;
        last_status_r        <= '0;
        fifo_watermark_reg_r <= 8'h10;
        loopback_ctrl_reg_r  <= '0;
        for (int i = 0; i < 16; i++) mem_debug[i] <= '0;
      end

      // IRQ status update from command engine
      // (handled externally, irq_status input)

      // IRQ clear
      if (irq_clear_ext) begin
        irq_status_r <= '0;
      end

      // Register access
      if (req_valid) begin
        req_ready <= 1'b1;
        if (req_write) begin
          // Write
          case (req_addr)
            ADDR_CTRL: begin
              ctrl_reg_r <= req_wdata[7:0];
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
            end
            ADDR_IRQ_MASK: begin
              irq_mask_reg_r <= req_wdata[7:0];
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
            end
            ADDR_FIFO_WATERMARK: begin
              fifo_watermark_reg_r <= req_wdata[7:0];
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
            end
            ADDR_LOOPBACK_CTRL: begin
              loopback_ctrl_reg_r <= req_wdata[7:0];
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
            end
            ADDR_MEM_DEBUG_BASE: begin
              if (req_addr <= ADDR_MEM_DEBUG_END) begin
                mem_debug[req_addr[3:0]] <= req_wdata[7:0];
                resp_valid <= 1'b1;
                resp_status <= STATUS_OK;
              end else begin
                resp_valid <= 1'b1;
                resp_status <= STATUS_ADDR_ERROR;
              end
            end
            default: begin
              // Check memory debug range
              if (req_addr >= ADDR_MEM_DEBUG_BASE && req_addr <= ADDR_MEM_DEBUG_END) begin
                mem_debug[req_addr[3:0]] <= req_wdata[7:0];
                resp_valid <= 1'b1;
                resp_status <= STATUS_OK;
              end else begin
                resp_valid <= 1'b1;
                resp_status <= STATUS_ADDR_ERROR;
              end
            end
          endcase
        end else begin
          // Read
          case (req_addr)
            ADDR_CTRL: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, ctrl_reg_r};
            end
            ADDR_IRQ_STATUS: begin
              // Read-clear: return current value, then clear
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, irq_status_r};
              irq_clear_read <= 1'b1;
            end
            ADDR_IRQ_MASK: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, irq_mask_reg_r};
            end
            ADDR_LAST_STATUS: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, last_status_r};
            end
            ADDR_RX_COUNT_L: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, rx_packet_count[7:0]};
            end
            ADDR_RX_COUNT_H: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, rx_packet_count[15:8]};
            end
            ADDR_ERR_COUNT_L: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, error_count[7:0]};
            end
            ADDR_ERR_COUNT_H: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, error_count[15:8]};
            end
            ADDR_TX_COUNT_L: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, tx_packet_count[7:0]};
            end
            ADDR_TX_COUNT_H: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, tx_packet_count[15:8]};
            end
            ADDR_FIFO_WATERMARK: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, fifo_watermark_reg_r};
            end
            ADDR_LOOPBACK_CTRL: begin
              resp_valid <= 1'b1;
              resp_status <= STATUS_OK;
              resp_rdata <= {24'b0, loopback_ctrl_reg_r};
            end
            default: begin
              // Check memory debug range
              if (req_addr >= ADDR_MEM_DEBUG_BASE && req_addr <= ADDR_MEM_DEBUG_END) begin
                resp_valid <= 1'b1;
                resp_status <= STATUS_OK;
                resp_rdata <= {24'b0, mem_debug[req_addr[3:0]]};
              end else begin
                resp_valid <= 1'b1;
                resp_status <= STATUS_ADDR_ERROR;
                resp_rdata <= '0;
              end
            end
          endcase
        end
      end

      // Update last_status from command engine
      if (last_status != STATUS_OK) begin
        last_status_r <= last_status;
      end
    end
  end

endmodule
