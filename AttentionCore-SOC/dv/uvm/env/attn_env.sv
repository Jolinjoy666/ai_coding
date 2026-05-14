class attn_env extends uvm_env;
  `uvm_component_utils(attn_env)

  apb_agent       apb_agt;
  attn_scoreboard scb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    apb_agt = apb_agent::type_id::create("apb_agt", this);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "apb_agt", "is_active", UVM_ACTIVE);

    scb = attn_scoreboard::type_id::create("scb", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    apb_agt.monitor.ap.connect(scb.apb_imp);
  endfunction
endclass
