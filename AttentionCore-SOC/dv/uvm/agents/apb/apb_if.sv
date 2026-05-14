interface apb_if(input logic clk);
  logic [31:0] paddr;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] pwdata;
  logic [3:0]  pstrb;
  logic [31:0] prdata;
  logic        pready;
  logic        pslverr;

  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output paddr;
    output psel;
    output penable;
    output pwrite;
    output pwdata;
    output pstrb;
    input  prdata;
    input  pready;
    input  pslverr;
  endclocking

  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input paddr;
    input psel;
    input penable;
    input pwrite;
    input pwdata;
    input pstrb;
    input prdata;
    input pready;
    input pslverr;
  endclocking

  modport driver(clocking driver_cb, input clk, paddr, psel, penable, pwrite, pwdata, pstrb, output prdata, pready, pslverr);
  modport monitor(clocking monitor_cb, input clk, paddr, psel, penable, pwrite, pwdata, pstrb, prdata, pready, pslverr);
endinterface
