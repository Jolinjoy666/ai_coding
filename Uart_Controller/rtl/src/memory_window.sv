module memory_window
  #(parameter int MEM_ADDR_WIDTH = 4,
    parameter int APB_DATA_WIDTH = 32)
   (input  logic       clk,
    input  logic       rst_n,
    input  logic       soft_reset,
    // Access interface
    input  logic       req_valid,
    output logic       req_ready,
    input  logic       req_write,
    input  logic [7:0] req_addr,
    input  logic [APB_DATA_WIDTH-1:0] req_wdata,
    input  logic [3:0]  req_wstrb,
    output logic       resp_valid,
    output logic [7:0] resp_status,
    output logic [APB_DATA_WIDTH-1:0] resp_rdata);

  localparam int MEM_DEPTH = 2 ** MEM_ADDR_WIDTH;

  // Status codes
  localparam logic [7:0] STATUS_OK         = 8'h00;
  localparam logic [7:0] STATUS_ADDR_ERROR = 8'h04;

  // Memory array
  logic [7:0] mem [MEM_DEPTH];

  // Address bounds
  localparam logic [7:0] MEM_BASE = 8'h10;
  localparam logic [7:0] MEM_END  = MEM_BASE + MEM_DEPTH - 1;

  logic addr_valid;
  logic [MEM_ADDR_WIDTH-1:0] local_addr;

  assign addr_valid = (req_addr >= MEM_BASE) && (req_addr <= MEM_END);
  assign local_addr = req_addr[MEM_ADDR_WIDTH-1:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < MEM_DEPTH; i++) mem[i] <= '0;
      resp_valid  <= 1'b0;
      resp_status <= '0;
      resp_rdata  <= '0;
      req_ready   <= 1'b0;
    end else begin
      resp_valid <= 1'b0;
      req_ready  <= 1'b0;

      // Soft reset
      if (soft_reset) begin
        for (int i = 0; i < MEM_DEPTH; i++) mem[i] <= '0;
      end

      if (req_valid) begin
        req_ready <= 1'b1;
        if (addr_valid) begin
          if (req_write) begin
            // Byte write with strobe
            if (req_wstrb[0]) mem[local_addr] <= req_wdata[7:0];
            resp_valid  <= 1'b1;
            resp_status <= STATUS_OK;
          end else begin
            // Read
            resp_valid  <= 1'b1;
            resp_status <= STATUS_OK;
            resp_rdata  <= {24'b0, mem[local_addr]};
          end
        end else begin
          resp_valid  <= 1'b1;
          resp_status <= STATUS_ADDR_ERROR;
          resp_rdata  <= '0;
        end
      end
    end
  end

endmodule
