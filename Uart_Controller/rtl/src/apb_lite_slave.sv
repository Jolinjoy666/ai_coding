module apb_lite_slave
  #(parameter int APB_ADDR_WIDTH = 8,
    parameter int APB_DATA_WIDTH = 32)
   (input  logic       clk,
    input  logic       rst_n,
    // APB interface
    input  logic [APB_ADDR_WIDTH-1:0]  paddr,
    input  logic       psel,
    input  logic       penable,
    input  logic       pwrite,
    input  logic [APB_DATA_WIDTH-1:0]  pwdata,
    input  logic [APB_DATA_WIDTH/8-1:0] pstrb,
    output logic [APB_DATA_WIDTH-1:0]  prdata,
    output logic       pready,
    output logic       pslverr,
    // Register access interface
    output logic       req_valid,
    input  logic       req_ready,
    output logic       req_write,
    output logic [7:0] req_addr,
    output logic [APB_DATA_WIDTH-1:0] req_wdata,
    output logic [3:0]  req_wstrb,
    output logic       req_is_mem_debug,
    // Response interface
    input  logic       resp_valid,
    input  logic [7:0] resp_status,
    input  logic [APB_DATA_WIDTH-1:0] resp_rdata,
    // Conflict signal
    input  logic       arbiter_busy);

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_SETUP,
    ST_ACCESS,
    ST_DONE
  } state_t;

  state_t state;
  logic [APB_ADDR_WIDTH-1:0] addr_reg;
  logic write_reg;
  logic [APB_DATA_WIDTH-1:0] wdata_reg;
  logic [APB_DATA_WIDTH/8-1:0] strb_reg;
  logic is_mem_debug_reg;

  localparam logic [7:0] MEM_DEBUG_BASE = 8'h10;
  localparam logic [7:0] MEM_DEBUG_END  = 8'h1F;

  assign is_mem_debug_reg = (addr_reg >= MEM_DEBUG_BASE) && (addr_reg <= MEM_DEBUG_END);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= ST_IDLE;
      addr_reg   <= '0;
      write_reg  <= 1'b0;
      wdata_reg  <= '0;
      strb_reg   <= '0;
      prdata     <= '0;
      pready     <= 1'b1;
      pslverr    <= 1'b0;
      req_valid  <= 1'b0;
      req_write  <= 1'b0;
      req_addr   <= '0;
      req_wdata  <= '0;
      req_wstrb  <= '0;
      req_is_mem_debug <= 1'b0;
    end else begin
      pslverr    <= 1'b0;
      req_valid  <= 1'b0;

      case (state)
        ST_IDLE: begin
          if (psel && !penable) begin
            // Setup phase
            addr_reg  <= paddr;
            write_reg <= pwrite;
            wdata_reg <= pwdata;
            strb_reg  <= pstrb;
            state     <= ST_SETUP;
          end
        end

        ST_SETUP: begin
          if (psel && penable) begin
            // Access phase
            // Check for memory debug access conflict
            if (is_mem_debug_reg && arbiter_busy) begin
              // Wait state
              pready <= 1'b0;
              state  <= ST_ACCESS;
            end else begin
              // Proceed with access
              req_valid  <= 1'b1;
              req_write  <= write_reg;
              req_addr   <= addr_reg[7:0];
              req_wdata  <= wdata_reg;
              req_wstrb  <= strb_reg;
              req_is_mem_debug <= is_mem_debug_reg;
              state      <= ST_ACCESS;
            end
          end
        end

        ST_ACCESS: begin
          if (resp_valid) begin
            req_valid <= 1'b0;
            pready    <= 1'b1;
            prdata    <= resp_rdata;
            if (resp_status != 8'h00) begin
              pslverr <= 1'b1;
            end
            state <= ST_DONE;
          end else if (is_mem_debug_reg && arbiter_busy) begin
            // Continue waiting
            pready <= 1'b0;
          end
        end

        ST_DONE: begin
          pready <= 1'b1;
          pslverr <= 1'b0;
          state  <= ST_IDLE;
        end

        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
