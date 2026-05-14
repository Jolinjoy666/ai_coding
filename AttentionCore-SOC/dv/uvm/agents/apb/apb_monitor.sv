class apb_monitor extends uvm_monitor;
  `uvm_component_utils(apb_monitor)

  virtual apb_if vif;

  uvm_analysis_port #(apb_transaction) ap;

  int unsigned read_count;
  int unsigned write_count;
  int unsigned error_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not set for apb_monitor")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      apb_transaction txn;
      txn = apb_transaction::type_id::create("txn");

      @(posedge vif.clk iff (vif.psel && !vif.penable));

      txn.addr = vif.paddr;
      txn.write = vif.pwrite;
      if (txn.write) begin
        txn.wdata = vif.pwdata;
        txn.strb = vif.pstrb;
      end

      @(posedge vif.clk iff (vif.psel && vif.penable));

      do begin
        @(posedge vif.clk);
      end while (!vif.pready);

      txn.rdata = vif.prdata;
      txn.slverr = vif.pslverr;
      txn.ready = vif.pready;

      if (txn.write) begin
        write_count++;
        `uvm_info("APB_MON", $sformatf("Write: %s", txn.convert2string()), UVM_HIGH)
      end else begin
        read_count++;
        `uvm_info("APB_MON", $sformatf("Read: %s", txn.convert2string()), UVM_HIGH)
      end

      if (txn.slverr) begin
        error_count++;
        `uvm_warning("APB_MON", $sformatf("SLVERR detected: %s", txn.convert2string()))
      end

      ap.write(txn);
    end
  endtask
endclass
