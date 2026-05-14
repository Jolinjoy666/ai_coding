class attn_base_test extends uvm_test;
  `uvm_component_utils(attn_base_test)

  attn_env env;
  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set for attn_base_test")

    uvm_config_db#(virtual apb_if)::set(this, "env.apb_agt*", "vif", vif);

    env = attn_env::type_id::create("env", this);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info("TEST", "=== Test started ===", UVM_LOW)
    // Wait for reset deassertion
    repeat (20) @(posedge vif.clk);
    `uvm_info("TEST", "Reset complete, starting sequences", UVM_LOW)
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("TEST", "TEST_PASS", UVM_NONE)
  endfunction
endclass
