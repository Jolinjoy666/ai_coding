module crc8_stream
  (input  logic       clk,
   input  logic       rst_n,
   input  logic       init,
   input  logic       valid,
   input  logic [7:0] data_in,
   output logic [7:0] crc_out);

  // Polynomial: x^8 + x^2 + x + 1 = 8'h07
  // Initial value: 8'h00
  // No reflection, no final XOR

  logic [7:0] crc_reg;

  function automatic logic [7:0] crc8_update(input logic [7:0] crc, input logic [7:0] data);
    logic [7:0] result;
    result = crc ^ data;
    for (int i = 0; i < 8; i++) begin
      if (result[7])
        result = (result << 1) ^ 8'h07;
      else
        result = result << 1;
    end
    return result;
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      crc_reg <= 8'h00;
    end else if (init) begin
      crc_reg <= 8'h00;
    end else if (valid) begin
      crc_reg <= crc8_update(crc_reg, data_in);
    end
  end

  assign crc_out = crc_reg;

endmodule
