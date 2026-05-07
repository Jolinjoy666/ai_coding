package uart_sequences_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_pkg::*;
  import apb_pkg::*;
  
  `include "uart_packet_sequence.sv"
  `include "uart_command_sequences.sv"
  `include "apb_sequences.sv"
endpackage
