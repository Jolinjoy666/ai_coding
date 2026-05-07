class ping_sequence extends uart_packet_sequence;
  `uvm_object_utils(ping_sequence)

  function new(string name = "ping_sequence");
    super.new(name);
    cmd_opcode = 8'h01;
    payload.delete();
  endfunction
endclass

class reg_read_sequence extends uart_packet_sequence;
  `uvm_object_utils(reg_read_sequence)
  
  rand bit [7:0] reg_addr;

  function new(string name = "reg_read_sequence");
    super.new(name);
    cmd_opcode = 8'h10;
  endfunction
  
  task body();
    payload = new[1];
    payload[0] = reg_addr;
    super.body();
  endtask
endclass

class reg_write_sequence extends uart_packet_sequence;
  `uvm_object_utils(reg_write_sequence)
  
  rand bit [7:0] reg_addr;
  rand bit [7:0] reg_data;

  function new(string name = "reg_write_sequence");
    super.new(name);
    cmd_opcode = 8'h11;
  endfunction
  
  task body();
    payload = new[2];
    payload[0] = reg_addr;
    payload[1] = reg_data;
    super.body();
  endtask
endclass

class mem_read_sequence extends uart_packet_sequence;
  `uvm_object_utils(mem_read_sequence)
  
  rand bit [7:0] mem_addr;
  rand bit [7:0] read_len;

  constraint c_read_len {
    read_len inside {[1:16]};
  }

  function new(string name = "mem_read_sequence");
    super.new(name);
    cmd_opcode = 8'h20;
  endfunction
  
  task body();
    payload = new[2];
    payload[0] = mem_addr;
    payload[1] = read_len;
    super.body();
  endtask
endclass

class mem_write_sequence extends uart_packet_sequence;
  `uvm_object_utils(mem_write_sequence)
  
  rand bit [7:0] mem_addr;
  rand bit [7:0] write_data[];

  constraint c_write_data_size {
    write_data.size() inside {[1:16]};
  }

  function new(string name = "mem_write_sequence");
    super.new(name);
    cmd_opcode = 8'h21;
  endfunction
  
  task body();
    payload = new[1 + write_data.size()];
    payload[0] = mem_addr;
    for (int i = 0; i < write_data.size(); i++) begin
      payload[1 + i] = write_data[i];
    end
    super.body();
  endtask
endclass

class status_read_sequence extends uart_packet_sequence;
  `uvm_object_utils(status_read_sequence)

  function new(string name = "status_read_sequence");
    super.new(name);
    cmd_opcode = 8'h30;
    payload.delete();
  endfunction
endclass

class fifo_status_sequence extends uart_packet_sequence;
  `uvm_object_utils(fifo_status_sequence)

  function new(string name = "fifo_status_sequence");
    super.new(name);
    cmd_opcode = 8'h31;
    payload.delete();
  endfunction
endclass

class loopback_cfg_sequence extends uart_packet_sequence;
  `uvm_object_utils(loopback_cfg_sequence)
  
  rand bit loopback_enable;

  function new(string name = "loopback_cfg_sequence");
    super.new(name);
    cmd_opcode = 8'h40;
  endfunction
  
  task body();
    payload = new[1];
    payload[0] = {7'b0, loopback_enable};
    super.body();
  endtask
endclass

class soft_reset_sequence extends uart_packet_sequence;
  `uvm_object_utils(soft_reset_sequence)

  function new(string name = "soft_reset_sequence");
    super.new(name);
    cmd_opcode = 8'h7E;
  endfunction
  
  task body();
    payload = new[2];
    payload[0] = 8'hDE;
    payload[1] = 8'hAD;
    super.body();
  endtask
endclass
