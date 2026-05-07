class apb_driver extends uvm_driver #(apb_transaction);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set for apb_driver")
  endfunction

  task run_phase(uvm_phase phase);
    apb_transaction txn;
    
    // Initialize APB signals
    vif.paddr <= '0;
    vif.psel <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite <= 1'b0;
    vif.pwdata <= '0;
    vif.pstrb <= '0;
    
    forever begin
      seq_item_port.get_next_item(txn);
      drive_apb(txn);
      seq_item_port.item_done();
    end
  endtask

  task drive_apb(apb_transaction txn);
    // Setup phase
    @(posedge vif.clk);
    vif.paddr <= txn.addr;
    vif.psel <= 1'b1;
    vif.penable <= 1'b0;
    vif.pwrite <= txn.write;
    if (txn.write) begin
      vif.pwdata <= txn.wdata;
      vif.pstrb <= txn.strb;
    end
    
    // Access phase
    @(posedge vif.clk);
    vif.penable <= 1'b1;
    
    // Wait for ready
    do begin
      @(posedge vif.clk);
    end while (!vif.pready);
    
    // Capture read data
    if (!txn.write) begin
      txn.rdata = vif.prdata;
      txn.slverr = vif.pslverr;
    end
    txn.slverr = vif.pslverr;
    
    // End transaction
    vif.psel <= 1'b0;
    vif.penable <= 1'b0;
    vif.pwrite <= 1'b0;
  endtask
endclass
