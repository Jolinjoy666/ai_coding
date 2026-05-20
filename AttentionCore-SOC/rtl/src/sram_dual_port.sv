// Dual-Port SRAM Wrapper
// True dual-port SRAM model for synthesis.
// Port A and Port B can operate independently.
// Writes are synchronous (registered on clock edge).
// Reads are combinational (data available same cycle as address).

module sram_dual_port
  import soc_params_pkg::*;
#(
  parameter int WORDS = 8192,
  parameter int WIDTH = 16
)(
  input  logic                    clk,

  // Port A
  input  logic                    a_cs_i,
  input  logic                    a_we_i,
  input  logic [$clog2(WORDS)-1:0] a_addr_i,
  input  logic [WIDTH-1:0]        a_wdata_i,
  output logic [WIDTH-1:0]        a_rdata_o,

  // Port B
  input  logic                    b_cs_i,
  input  logic                    b_we_i,
  input  logic [$clog2(WORDS)-1:0] b_addr_i,
  input  logic [WIDTH-1:0]        b_wdata_i,
  output logic [WIDTH-1:0]        b_rdata_o
);

  // Memory array
  logic [WIDTH-1:0] mem [0:WORDS-1];

  // Synchronous write (both ports)
  always_ff @(posedge clk) begin
    if (a_cs_i && a_we_i) begin
      mem[a_addr_i] <= a_wdata_i;
    end
    if (b_cs_i && b_we_i) begin
      mem[b_addr_i] <= b_wdata_i;
    end
  end

  // Combinational read
  assign a_rdata_o = mem[a_addr_i];
  assign b_rdata_o = mem[b_addr_i];

endmodule
