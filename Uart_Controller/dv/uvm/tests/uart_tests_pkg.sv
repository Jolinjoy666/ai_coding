package uart_tests_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_pkg::*;
  import apb_pkg::*;
  import uart_env_pkg::*;
  import uart_sequences_pkg::*;
  
  `include "uart_base_test.sv"
  `include "uart_tests.sv"
endpackage
