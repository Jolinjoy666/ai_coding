# AttentionCore-SOC Simulation Makefile
# Uses Synopsys VCS for simulation

# Variables
VCS = vcs
VERDI = verdi

# Directories
RTL_DIR = ../rtl/src
PKG_DIR = ../rtl/pkg
TB_DIR  = ../dv/tb
TEST_DIR = ../dv/tests

# RTL files
RTL_FILES = \
  $(PKG_DIR)/soc_params_pkg.sv \
  $(RTL_DIR)/fp16_adder.sv \
  $(RTL_DIR)/fp16_multiplier.sv \
  $(RTL_DIR)/fp16_mac.sv \
  $(RTL_DIR)/fp16_to_fp32.sv \
  $(RTL_DIR)/fp32_to_fp16.sv \
  $(RTL_DIR)/fp32_adder.sv \
  $(RTL_DIR)/fp16_mac_array.sv \
  $(RTL_DIR)/fp16_exp_lut.sv \
  $(RTL_DIR)/fp16_comparator.sv \
  $(RTL_DIR)/fp16_rowmax.sv \
  $(RTL_DIR)/fp16_rowsum.sv \
  $(RTL_DIR)/flash_attention_core.sv \
  $(RTL_DIR)/causal_mask.sv \
  $(RTL_DIR)/multi_head_scheduler.sv \
  $(RTL_DIR)/qkv_buffer.sv \
  $(RTL_DIR)/pipeline_buffer.sv \
  $(RTL_DIR)/attention_engine.sv \
  $(RTL_DIR)/gelu_hw.sv \
  $(RTL_DIR)/mlp_engine.sv \
  $(RTL_DIR)/layernorm_hw.sv \
  $(RTL_DIR)/residual_add.sv \
  $(RTL_DIR)/ctrl_regs.sv \
  $(RTL_DIR)/apb_interconnect.sv \
  $(RTL_DIR)/uart_top.sv \
  $(RTL_DIR)/gpio_top.sv \
  $(RTL_DIR)/timer_top.sv \
  $(RTL_DIR)/riscv_core.sv \
  $(RTL_DIR)/sram_single_port.sv \
  $(RTL_DIR)/sram_dual_port.sv \
  $(RTL_DIR)/attentioncore_soc_top.sv

# Testbench files
TB_FILES = $(TB_DIR)/tb_attentioncore_soc.sv

# Test files
TEST_FILES = $(TEST_DIR)/fp16_mac_test.sv

# Compilation
.PHONY: compile
compile:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
	  -debug_access+all \
	  -cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed \
	  +incdir+$(RTL_DIR) \
	  $(RTL_FILES) $(TB_FILES) \
	  -o simv_soc -l compile_soc.log

# FP16 MAC test
.PHONY: test_mac
test_mac:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
	  -debug_access+all \
	  -cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed \
	  +incdir+$(RTL_DIR) \
	  $(PKG_DIR)/soc_params_pkg.sv \
	  $(RTL_DIR)/fp16_adder.sv \
	  $(RTL_DIR)/fp16_multiplier.sv \
	  $(RTL_DIR)/fp16_mac.sv \
	  $(RTL_DIR)/fp16_to_fp32.sv \
	  $(RTL_DIR)/fp32_to_fp16.sv \
	  $(RTL_DIR)/fp32_adder.sv \
	  $(TEST_DIR)/fp16_mac_test.sv \
	  -o simv_mac -l compile_mac.log
	./simv_mac -l sim_mac.log

# FP16 Adder test
.PHONY: test_adder
test_adder:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
	  -debug_access+all \
	  -cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed \
	  +incdir+$(RTL_DIR) \
	  $(PKG_DIR)/soc_params_pkg.sv \
	  $(RTL_DIR)/fp16_adder.sv \
	  $(TEST_DIR)/fp16_adder_test.sv \
	  -o simv_adder -l compile_adder.log
	./simv_adder -l sim_adder.log

# FP16 MAC Array test
.PHONY: test_array
test_array:
	$(VCS) -full64 -sverilog -timescale=1ns/1ps \
	  -debug_access+all \
	  -cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed \
	  +incdir+$(RTL_DIR) \
	  $(PKG_DIR)/soc_params_pkg.sv \
	  $(RTL_DIR)/fp16_adder.sv \
	  $(RTL_DIR)/fp16_multiplier.sv \
	  $(RTL_DIR)/fp16_mac.sv \
	  $(RTL_DIR)/fp16_mac_array.sv \
	  $(TEST_DIR)/fp16_mac_array_test.sv \
	  -o simv_array -l compile_array.log
	./simv_array -l sim_array.log

# SOC simulation
.PHONY: sim_soc
sim_soc: compile
	./simv_soc

# SOC test (full verification)
.PHONY: test_soc
test_soc: compile
	./simv_soc -l sim_soc.log

# Waveform
.PHONY: wave
wave:
	$(VERDI) -ssf *.fsdb &

# Clean
.PHONY: clean
clean:
	rm -rf simv* *.vcd *.fsdb *.log csrc *.daidir *.key *.vpd

# All tests
.PHONY: test_all
test_all: test_adder test_mac test_array test_soc
