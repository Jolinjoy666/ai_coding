// Single-Port SRAM Wrapper
// Generic single-port SRAM model for synthesis.

module sram_single_port
  import soc_params_pkg::*;
#(
  parameter int WORDS = 8192,
  parameter int WIDTH = 16
)(
  input  logic                    clk,
  input  logic                    cs_i,
  input  logic                    we_i,
  input  logic [$clog2(WORDS)-1:0] addr_i,
  input  logic [WIDTH-1:0]        wdata_i,
  output logic [WIDTH-1:0]        rdata_o
);

  // Memory array
  logic [WIDTH-1:0] mem [0:WORDS-1];

  // Read/Write operation
  always_ff @(posedge clk) begin
    if (cs_i) begin
      if (we_i) begin
        mem[addr_i] <= wdata_i;
      end
      rdata_o <= mem[addr_i];
    end
  end

endmodule
