class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env env;
  virtual uart_if uart_vif;
  virtual apb_if apb_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
    
    // Get virtual interfaces
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "uart_vif", uart_vif))
      `uvm_fatal("NOVIF", "UART virtual interface not set")
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", apb_vif))
      `uvm_fatal("NOVIF", "APB virtual interface not set")
    
    // Set interfaces for agents
    uvm_config_db#(virtual uart_if)::set(this, "env.uart_agt*", "vif", uart_vif);
    uvm_config_db#(virtual apb_if)::set(this, "env.apb_agt*", "vif", apb_vif);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    // Wait for reset
    #1000ns;
    
    `uvm_info("TEST", "Starting test sequence", UVM_LOW)
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("TEST", "=== Test Report ===", UVM_LOW)
  endfunction
endclass
