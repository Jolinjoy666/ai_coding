class ping_test extends uart_base_test;
  `uvm_component_utils(ping_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ping_sequence ping_seq;
    
    phase.raise_objection(this);
    
    #1000ns; // Wait for reset
    
    `uvm_info("TEST", "=== Starting PING Test ===", UVM_LOW)
    
    // Send PING command
    ping_seq = ping_sequence::type_id::create("ping_seq");
    ping_seq.seq_id = 8'h01;
    ping_seq.start(env.uart_agt.sequencer);
    
    #50000ns; // Wait for response
    
    `uvm_info("TEST", "=== PING Test Complete ===", UVM_LOW)
    
    phase.drop_objection(this);
  endtask
endclass

class reg_access_test extends uart_base_test;
  `uvm_component_utils(reg_access_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    reg_read_sequence reg_rd_seq;
    reg_write_sequence reg_wr_seq;
    apb_read_sequence apb_rd_seq;
    apb_write_sequence apb_wr_seq;
    
    phase.raise_objection(this);
    
    #1000ns; // Wait for reset
    
    `uvm_info("TEST", "=== Starting Register Access Test ===", UVM_LOW)
    
    // Test 1: Write CTRL register via UART
    `uvm_info("TEST", "Test 1: UART REG_WRITE to CTRL", UVM_LOW)
    reg_wr_seq = reg_write_sequence::type_id::create("reg_wr_seq");
    reg_wr_seq.seq_id = 8'h01;
    reg_wr_seq.reg_addr = 8'h00;
    reg_wr_seq.reg_data = 8'h07;
    reg_wr_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 2: Read CTRL register via UART
    `uvm_info("TEST", "Test 2: UART REG_READ from CTRL", UVM_LOW)
    reg_rd_seq = reg_read_sequence::type_id::create("reg_rd_seq");
    reg_rd_seq.seq_id = 8'h02;
    reg_rd_seq.reg_addr = 8'h00;
    reg_rd_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 3: Write IRQ_MASK register via APB
    `uvm_info("TEST", "Test 3: APB WRITE to IRQ_MASK", UVM_LOW)
    apb_wr_seq = apb_write_sequence::type_id::create("apb_wr_seq");
    apb_wr_seq.addr = 8'h02;
    apb_wr_seq.wdata = 32'h000000FF;
    apb_wr_seq.strb = 4'b0001;
    apb_wr_seq.start(env.apb_agt.sequencer);
    #1000ns;
    
    // Test 4: Read IRQ_MASK register via APB
    `uvm_info("TEST", "Test 4: APB READ from IRQ_MASK", UVM_LOW)
    apb_rd_seq = apb_read_sequence::type_id::create("apb_rd_seq");
    apb_rd_seq.addr = 8'h02;
    apb_rd_seq.start(env.apb_agt.sequencer);
    #1000ns;
    
    `uvm_info("TEST", "=== Register Access Test Complete ===", UVM_LOW)
    
    phase.drop_objection(this);
  endtask
endclass

class mem_access_test extends uart_base_test;
  `uvm_component_utils(mem_access_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    mem_write_sequence mem_wr_seq;
    mem_read_sequence mem_rd_seq;
    
    phase.raise_objection(this);
    
    #1000ns; // Wait for reset
    
    `uvm_info("TEST", "=== Starting Memory Access Test ===", UVM_LOW)
    
    // Write to memory window
    `uvm_info("TEST", "Test 1: MEM_WRITE", UVM_LOW)
    mem_wr_seq = mem_write_sequence::type_id::create("mem_wr_seq");
    mem_wr_seq.seq_id = 8'h01;
    mem_wr_seq.mem_addr = 8'h10;
    mem_wr_seq.write_data = '{8'hAA, 8'hBB, 8'hCC, 8'hDD};
    mem_wr_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Read from memory window
    `uvm_info("TEST", "Test 2: MEM_READ", UVM_LOW)
    mem_rd_seq = mem_read_sequence::type_id::create("mem_rd_seq");
    mem_rd_seq.seq_id = 8'h02;
    mem_rd_seq.mem_addr = 8'h10;
    mem_rd_seq.read_len = 4;
    mem_rd_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    `uvm_info("TEST", "=== Memory Access Test Complete ===", UVM_LOW)
    
    phase.drop_objection(this);
  endtask
endclass

class full_function_test extends uart_base_test;
  `uvm_component_utils(full_function_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    ping_sequence ping_seq;
    reg_read_sequence reg_rd_seq;
    reg_write_sequence reg_wr_seq;
    mem_write_sequence mem_wr_seq;
    mem_read_sequence mem_rd_seq;
    status_read_sequence status_seq;
    fifo_status_sequence fifo_seq;
    loopback_cfg_sequence loopback_seq;
    soft_reset_sequence reset_seq;
    
    phase.raise_objection(this);
    
    #1000ns; // Wait for reset
    
    `uvm_info("TEST", "=== Starting Full Function Test ===", UVM_LOW)
    
    // Test 1: PING
    `uvm_info("TEST", "Test 1: PING", UVM_LOW)
    ping_seq = ping_sequence::type_id::create("ping_seq");
    ping_seq.seq_id = 8'h01;
    ping_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 2: Write CTRL register
    `uvm_info("TEST", "Test 2: REG_WRITE CTRL", UVM_LOW)
    reg_wr_seq = reg_write_sequence::type_id::create("reg_wr_seq");
    reg_wr_seq.seq_id = 8'h02;
    reg_wr_seq.reg_addr = 8'h00;
    reg_wr_seq.reg_data = 8'h07;
    reg_wr_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 3: Read CTRL register
    `uvm_info("TEST", "Test 3: REG_READ CTRL", UVM_LOW)
    reg_rd_seq = reg_read_sequence::type_id::create("reg_rd_seq");
    reg_rd_seq.seq_id = 8'h03;
    reg_rd_seq.reg_addr = 8'h00;
    reg_rd_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 4: Write to memory
    `uvm_info("TEST", "Test 4: MEM_WRITE", UVM_LOW)
    mem_wr_seq = mem_write_sequence::type_id::create("mem_wr_seq");
    mem_wr_seq.seq_id = 8'h04;
    mem_wr_seq.mem_addr = 8'h10;
    mem_wr_seq.write_data = '{8'hAA, 8'hBB};
    mem_wr_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 5: Read from memory
    `uvm_info("TEST", "Test 5: MEM_READ", UVM_LOW)
    mem_rd_seq = mem_read_sequence::type_id::create("mem_rd_seq");
    mem_rd_seq.seq_id = 8'h05;
    mem_rd_seq.mem_addr = 8'h10;
    mem_rd_seq.read_len = 2;
    mem_rd_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 6: STATUS_READ
    `uvm_info("TEST", "Test 6: STATUS_READ", UVM_LOW)
    status_seq = status_read_sequence::type_id::create("status_seq");
    status_seq.seq_id = 8'h06;
    status_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 7: FIFO_STATUS
    `uvm_info("TEST", "Test 7: FIFO_STATUS", UVM_LOW)
    fifo_seq = fifo_status_sequence::type_id::create("fifo_seq");
    fifo_seq.seq_id = 8'h07;
    fifo_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 8: LOOPBACK_CFG
    `uvm_info("TEST", "Test 8: LOOPBACK_CFG", UVM_LOW)
    loopback_seq = loopback_cfg_sequence::type_id::create("loopback_seq");
    loopback_seq.seq_id = 8'h08;
    loopback_seq.loopback_enable = 1'b0;
    loopback_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    // Test 9: SOFT_RESET
    `uvm_info("TEST", "Test 9: SOFT_RESET", UVM_LOW)
    reset_seq = soft_reset_sequence::type_id::create("reset_seq");
    reset_seq.seq_id = 8'h09;
    reset_seq.start(env.uart_agt.sequencer);
    #10000ns;
    
    `uvm_info("TEST", "=== Full Function Test Complete ===", UVM_LOW)
    
    phase.drop_objection(this);
  endtask
endclass
