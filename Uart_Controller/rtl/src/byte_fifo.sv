module byte_fifo
  #(parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 32)
   (input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  wr_en,
    input  logic [DATA_WIDTH-1:0] wr_data,
    input  logic                  rd_en,
    output logic [DATA_WIDTH-1:0] rd_data,
    output logic                  full,
    output logic                  empty,
    output logic [$clog2(DEPTH):0] level);

  localparam int ADDR_W = $clog2(DEPTH);

  logic [DATA_WIDTH-1:0] mem [DEPTH];
  logic [ADDR_W-1:0]     wr_ptr, rd_ptr;
  logic [ADDR_W:0]       count;

  assign full  = (count == DEPTH);
  assign empty = (count == 0);
  assign level = count;
  assign rd_data = mem[rd_ptr];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      wr_ptr <= '0;
      rd_ptr <= '0;
      count  <= '0;
    end else begin
      // Write
      if (wr_en && !full) begin
        mem[wr_ptr] <= wr_data;
        wr_ptr <= (wr_ptr == ADDR_W'(DEPTH-1)) ? '0 : wr_ptr + 1'b1;
      end
      // Read
      if (rd_en && !empty) begin
        rd_ptr <= (rd_ptr == ADDR_W'(DEPTH-1)) ? '0 : rd_ptr + 1'b1;
      end
      // Count update
      case ({wr_en && !full, rd_en && !empty})
        2'b10:   count <= count + 1'b1;
        2'b01:   count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end

endmodule
