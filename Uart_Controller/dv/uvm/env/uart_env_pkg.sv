package uart_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import uart_pkg::*;
  import apb_pkg::*;
  
  // Define analysis imp types before scoreboard
  `uvm_analysis_imp_decl(_uart)
  `uvm_analysis_imp_decl(_apb)
  
  `include "uart_scoreboard.sv"
  `include "uart_env.sv"
endpackage
