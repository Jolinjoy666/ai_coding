class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_agent     uart_agt;
  apb_agent      apb_agt;
  uart_scoreboard scb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    uart_agt = uart_agent::type_id::create("uart_agt", this);
    apb_agt = apb_agent::type_id::create("apb_agt", this);
    scb = uart_scoreboard::type_id::create("scb", this);
    
    // Set agent active
    uvm_config_db#(uvm_active_passive_enum)::set(this, "uart_agt", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_agt", "is_active", UVM_ACTIVE);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    // Connect monitors to scoreboard
    uart_agt.monitor.ap.connect(scb.uart_imp);
    apb_agt.monitor.ap.connect(scb.apb_imp);
  endfunction
endclass
