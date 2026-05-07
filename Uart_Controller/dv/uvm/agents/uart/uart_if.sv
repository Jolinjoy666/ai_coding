interface uart_if(input logic clk);
  logic rx_i;
  logic tx_o;
  
  // Clocking blocks for synchronization
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output rx_i;
    input  tx_o;
  endclocking
  
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input rx_i;
    input tx_o;
  endclocking
  
  modport driver_mp(clocking driver_cb, input clk, output rx_i, input tx_o);
  modport monitor_mp(clocking monitor_cb, input clk, input rx_i, input tx_o);
endinterface
