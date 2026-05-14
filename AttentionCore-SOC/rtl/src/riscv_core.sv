// RISC-V Core (Simplified)
// RV32IMF, 2-stage pipeline (IF + EX).
// This is a simplified model for integration.
// In production, replace with picorv32 or similar open-source core.

module riscv_core
  import soc_params_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Instruction memory interface
  output logic [31:0] inst_addr_o,
  output logic        inst_re_o,
  input  logic [31:0] inst_rdata_i,
  input  logic        inst_ready_i,

  // Data memory interface (APB master)
  output logic [31:0] data_addr_o,
  output logic        data_re_o,
  output logic        data_we_o,
  output logic [31:0] data_wdata_o,
  input  logic [31:0] data_rdata_i,
  input  logic        data_ready_i,

  // Interrupt
  input  logic        irq_i,

  // Debug
  output logic [31:0] pc_o,
  output logic [31:0] instr_o
);

  // Register file
  logic [31:0] regs [0:31];

  // Pipeline registers
  logic [31:0] pc_q, pc_d;
  logic [31:0] if_instr_q, if_instr_d;
  logic [31:0] ex_instr_q;

  // Control signals
  logic        stall;
  logic        flush;
  logic [31:0] branch_target;
  logic        branch_taken;

  // ALU
  logic [31:0] alu_a, alu_b, alu_result;
  logic [4:0]  alu_op;

  // Decode
  logic [6:0]  opcode;
  logic [4:0]  rd, rs1, rs2;
  logic [2:0]  funct3;
  logic [6:0]  funct7;
  logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

  assign opcode = if_instr_q[6:0];
  assign rd     = if_instr_q[11:7];
  assign rs1    = if_instr_q[19:15];
  assign rs2    = if_instr_q[24:20];
  assign funct3 = if_instr_q[14:12];
  assign funct7 = if_instr_q[31:25];

  // Immediate generation
  assign imm_i = {{20{if_instr_q[31]}}, if_instr_q[31:20]};
  assign imm_s = {{20{if_instr_q[31]}}, if_instr_q[31:25], if_instr_q[11:7]};
  assign imm_b = {{19{if_instr_q[31]}}, if_instr_q[31], if_instr_q[7], if_instr_q[30:25], if_instr_q[11:8], 1'b0};
  assign imm_u = {if_instr_q[31:12], 12'b0};
  assign imm_j = {{11{if_instr_q[31]}}, if_instr_q[31], if_instr_q[19:12], if_instr_q[20], if_instr_q[30:21], 1'b0};

  // PC logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_q <= '0;
    end else if (!stall) begin
      if (branch_taken) begin
        pc_q <= branch_target;
      end else begin
        pc_q <= pc_q + 4;
      end
    end
  end

  // Instruction fetch
  assign inst_addr_o = pc_q;
  assign inst_re_o   = !stall;

  // Pipeline registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      if_instr_q <= '0;
      ex_instr_q <= '0;
    end else if (!stall) begin
      if_instr_q <= inst_rdata_i;
      ex_instr_q <= if_instr_q;
    end
  end

  // Register file read
  logic [31:0] rs1_data, rs2_data;
  assign rs1_data = (rs1 != 0) ? regs[rs1] : 32'b0;
  assign rs2_data = (rs2 != 0) ? regs[rs2] : 32'b0;

  // ALU
  always_comb begin
    alu_a = rs1_data;
    alu_b = (opcode == 7'b0010011 || opcode == 7'b0000011 || opcode == 7'b1100111) ? imm_i : rs2_data;

    alu_result = '0;
    unique case (funct3)
      3'b000: alu_result = (funct7[5] && opcode == 7'b0110011) ? alu_a - alu_b : alu_a + alu_b;
      3'b001: alu_result = alu_a << alu_b[4:0];
      3'b010: alu_result = ($signed(alu_a) < $signed(alu_b)) ? 1 : 0;
      3'b011: alu_result = (alu_a < alu_b) ? 1 : 0;
      3'b100: alu_result = alu_a ^ alu_b;
      3'b101: alu_result = funct7[5] ? ($signed(alu_a) >>> alu_b[4:0]) : (alu_a >> alu_b[4:0]);
      3'b110: alu_result = alu_a | alu_b;
      3'b111: alu_result = alu_a & alu_b;
    endcase
  end

  // Branch logic
  always_comb begin
    branch_taken = 1'b0;
    branch_target = '0;

    if (opcode == 7'b1100011) begin  // Branch
      unique case (funct3)
        3'b000: branch_taken = (rs1_data == rs2_data);  // BEQ
        3'b001: branch_taken = (rs1_data != rs2_data);  // BNE
        3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));  // BLT
        3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data));  // BGE
        3'b110: branch_taken = (rs1_data < rs2_data);  // BLTU
        3'b111: branch_taken = (rs1_data >= rs2_data);  // BGEU
        default: branch_taken = 1'b0;
      endcase
      branch_target = pc_q + imm_b;
    end else if (opcode == 7'b1101111) begin  // JAL
      branch_taken = 1'b1;
      branch_target = pc_q + imm_j;
    end else if (opcode == 7'b1100111) begin  // JALR
      branch_taken = 1'b1;
      branch_target = (rs1_data + imm_i) & ~32'b1;
    end
  end

  // Register file write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 32; i++) begin
        regs[i] <= '0;
      end
    end else if (!stall) begin
      if (rd != 0) begin
        unique case (opcode)
          7'b0110011: regs[rd] <= alu_result;  // R-type
          7'b0010011: regs[rd] <= alu_result;  // I-type ALU
          7'b0000011: regs[rd] <= data_rdata_i;  // Load
          7'b0110111: regs[rd] <= imm_u;  // LUI
          7'b0010111: regs[rd] <= pc_q + imm_u;  // AUIPC
          7'b1101111: regs[rd] <= pc_q + 4;  // JAL
          7'b1100111: regs[rd] <= pc_q + 4;  // JALR
          default: ;
        endcase
      end
    end
  end

  // Data memory interface
  assign data_addr_o  = alu_result;
  assign data_re_o    = (opcode == 7'b0000011);  // Load
  assign data_we_o    = (opcode == 7'b0100011);  // Store
  assign data_wdata_o = rs2_data;

  // Stall logic
  assign stall = !inst_ready_i || (data_re_o && !data_ready_i);

  // Flush on branch
  assign flush = branch_taken;

  // Debug outputs
  assign pc_o    = pc_q;
  assign instr_o = ex_instr_q;

  // WFI detection (simplified)
  // In real implementation, would halt pipeline until interrupt

endmodule
