class uart_packet_sequence extends uvm_sequence #(uart_transaction);
  `uvm_object_utils(uart_packet_sequence)

  rand bit [7:0] seq_id;
  rand bit [7:0] cmd_opcode;
  rand bit [7:0] payload[];
  rand int       response_timeout;

  constraint c_valid_opcode {
    cmd_opcode inside {8'h01, 8'h10, 8'h11, 8'h20, 8'h21, 8'h30, 8'h31, 8'h40, 8'h7E};
  }

  constraint c_response_timeout {
    response_timeout inside {[1000:10000]};
  }

  function new(string name = "uart_packet_sequence");
    super.new(name);
  endfunction

  // CRC-8 calculation function
  function bit [7:0] calc_crc8(bit [7:0] data[], int len);
    bit [7:0] crc;
    bit [7:0] result;
    crc = 8'h00;
    for (int i = 0; i < len; i++) begin
      result = crc ^ data[i];
      for (int j = 0; j < 8; j++) begin
        if (result[7])
          result = (result << 1) ^ 8'h07;
        else
          result = result << 1;
      end
      crc = result;
    end
    return crc;
  endfunction

  task body();
    uart_transaction txn;
    bit [7:0] pkt_data[];
    bit [7:0] crc_val;
    int pkt_len;
    
    // Calculate packet length: SEQ + CMD + LEN + PAYLOAD
    pkt_len = 3 + payload.size();
    pkt_data = new[pkt_len];
    
    // Build packet data for CRC calculation
    pkt_data[0] = seq_id;
    pkt_data[1] = cmd_opcode;
    pkt_data[2] = payload.size();
    for (int i = 0; i < payload.size(); i++) begin
      pkt_data[3 + i] = payload[i];
    end
    
    // Calculate CRC
    crc_val = calc_crc8(pkt_data, pkt_len);
    
    // Send START byte
    txn = uart_transaction::type_id::create("txn");
    txn.data = 8'hA5;
    start_item(txn);
    finish_item(txn);
    
    // Send SEQ byte
    txn = uart_transaction::type_id::create("txn");
    txn.data = seq_id;
    start_item(txn);
    finish_item(txn);
    
    // Send CMD byte
    txn = uart_transaction::type_id::create("txn");
    txn.data = cmd_opcode;
    start_item(txn);
    finish_item(txn);
    
    // Send LEN byte
    txn = uart_transaction::type_id::create("txn");
    txn.data = payload.size();
    start_item(txn);
    finish_item(txn);
    
    // Send payload bytes
    for (int i = 0; i < payload.size(); i++) begin
      txn = uart_transaction::type_id::create("txn");
      txn.data = payload[i];
      start_item(txn);
      finish_item(txn);
    end
    
    // Send CRC byte
    txn = uart_transaction::type_id::create("txn");
    txn.data = crc_val;
    start_item(txn);
    finish_item(txn);
    
    // Send END byte
    txn = uart_transaction::type_id::create("txn");
    txn.data = 8'h5A;
    start_item(txn);
    finish_item(txn);
    
    `uvm_info("SEQ", $sformatf("Sent packet: SEQ=%02h CMD=%02h LEN=%02h CRC=%02h",
              seq_id, cmd_opcode, payload.size(), crc_val), UVM_LOW)
  endtask
endclass
