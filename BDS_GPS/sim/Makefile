# BDS_GPS Makefile
# 用于编译和仿真

# 工具定义
VCS = vcs
VERDI = verdi

# 源文件
RTL_DIR = ../rtl/generated
TB_DIR = ../dv/tb
TOP_MODULE = tb_bds_gps_top

# 源文件列表
RTL_FILES = \
	$(RTL_DIR)/bds_gps_top.sv \
	$(RTL_DIR)/time_slice_scheduler.sv \
	$(RTL_DIR)/ca_code_generator.sv \
	$(RTL_DIR)/correlator.sv \
	$(RTL_DIR)/accumulator.sv \
	$(RTL_DIR)/acquisition_detector.sv \
	$(RTL_DIR)/tracking_controller.sv \
	$(RTL_DIR)/output_interface.sv

TB_FILES = \
	$(TB_DIR)/tb_bds_gps_top.sv

# 编译选项
VCS_OPTS = -full64 -sverilog -debug_access+all -kdb -l compile.log

# 仿真选项
SIM_OPTS = -l simulation.log +vcd

# 默认目标
all: compile sim

# 编译
compile:
	$(VCS) $(VCS_OPTS) $(RTL_FILES) $(TB_FILES) -o simv

# 仿真
sim: compile
	./simv $(SIM_OPTS)

# 波形查看
wave: sim
	$(VERDI) -ssf tb_bds_gps_top.fsdb &

# 清理
clean:
	rm -rf simv *.log *.vcd *.fsdb csrc *.key *.vpd

# 帮助
help:
	@echo "Available targets:"
	@echo "  all      - Compile and simulate"
	@echo "  compile  - Compile the design"
	@echo "  sim      - Run simulation"
	@echo "  wave     - View waveform"
	@echo "  clean    - Clean generated files"
	@echo "  help     - Show this help"

.PHONY: all compile sim wave clean help