module command_arbiter
  (input  logic clk,
   input  logic rst_n,
   // UART command request
   input  logic       uart_req_valid,
   output logic       uart_req_ready,
   input  logic       uart_req_write,
   input  logic [7:0] uart_req_addr,
   input  logic [31:0] uart_req_wdata,
   input  logic [3:0]  uart_req_wstrb,
   output logic       uart_resp_valid,
   output logic [7:0] uart_resp_status,
   output logic [31:0] uart_resp_rdata,
   // APB request
   input  logic       apb_req_valid,
   output logic       apb_req_ready,
   input  logic       apb_req_write,
   input  logic [7:0] apb_req_addr,
   input  logic [31:0] apb_req_wdata,
   input  logic [3:0]  apb_req_wstrb,
   input  logic       apb_req_is_mem_debug,
   output logic       apb_resp_valid,
   output logic [7:0] apb_resp_status,
   output logic [31:0] apb_resp_rdata,
   // Shared resource request
   output logic       req_valid,
   input  logic       req_ready,
   output logic       req_source, // 0=UART, 1=APB
   output logic       req_write,
   output logic [7:0] req_addr,
   output logic [31:0] req_wdata,
   output logic [3:0]  req_wstrb,
   // Shared resource response
   input  logic       resp_valid,
   input  logic [7:0] resp_status,
   input  logic [31:0] resp_rdata,
   // Busy signal
   output logic       arbiter_busy);

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_UART,
    ST_APB,
    ST_WAIT
  } state_t;

  state_t state;
  logic uart_active;
  logic apb_pending;

  assign arbiter_busy = (state != ST_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= ST_IDLE;
      uart_active <= 1'b0;
      apb_pending <= 1'b0;
    end else begin
      case (state)
        ST_IDLE: begin
          if (uart_req_valid) begin
            state       <= ST_UART;
            uart_active <= 1'b1;
          end else if (apb_req_valid) begin
            if (apb_req_is_mem_debug) begin
              // Memory debug needs arbitration
              state <= ST_APB;
            end else begin
              // Register access can proceed
              state <= ST_APB;
            end
          end
        end

        ST_UART: begin
          if (resp_valid) begin
            uart_active <= 1'b0;
            if (apb_pending) begin
              state       <= ST_APB;
              apb_pending <= 1'b0;
            end else begin
              state <= ST_IDLE;
            end
          end
        end

        ST_APB: begin
          if (resp_valid) begin
            if (uart_req_valid && !uart_active) begin
              state       <= ST_UART;
              uart_active <= 1'b1;
            end else begin
              state <= ST_IDLE;
            end
          end
        end

        ST_WAIT: begin
          state <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

  // Request mux
  always_comb begin
    req_valid  = 1'b0;
    req_write  = 1'b0;
    req_addr   = '0;
    req_wdata  = '0;
    req_wstrb  = '0;
    req_source = 1'b0;

    case (state)
      ST_UART: begin
        req_valid  = uart_req_valid && !uart_active;
        req_write  = uart_req_write;
        req_addr   = uart_req_addr;
        req_wdata  = uart_req_wdata;
        req_wstrb  = uart_req_wstrb;
        req_source = 1'b0;
      end
      ST_APB: begin
        req_valid  = apb_req_valid;
        req_write  = apb_req_write;
        req_addr   = apb_req_addr;
        req_wdata  = apb_req_wdata;
        req_wstrb  = apb_req_wstrb;
        req_source = 1'b1;
      end
      default: begin
        req_valid  = 1'b0;
        req_write  = 1'b0;
        req_addr   = '0;
        req_wdata  = '0;
        req_wstrb  = '0;
        req_source = 1'b0;
      end
    endcase
  end

  // Response demux
  always_comb begin
    uart_resp_valid  = 1'b0;
    uart_resp_status = '0;
    uart_resp_rdata  = '0;
    apb_resp_valid   = 1'b0;
    apb_resp_status  = '0;
    apb_resp_rdata   = '0;
    uart_req_ready   = 1'b0;
    apb_req_ready    = 1'b0;

    if (resp_valid) begin
      if (state == ST_UART || uart_active) begin
        uart_resp_valid  = 1'b1;
        uart_resp_status = resp_status;
        uart_resp_rdata  = resp_rdata;
        uart_req_ready   = 1'b1;
      end else if (state == ST_APB) begin
        apb_resp_valid  = 1'b1;
        apb_resp_status = resp_status;
        apb_resp_rdata  = resp_rdata;
        apb_req_ready   = 1'b1;
      end
    end
  end

endmodule
