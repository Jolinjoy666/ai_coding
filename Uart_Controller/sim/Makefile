SIM       ?= vcs
UVM_TEST  ?= full_function_test
SEED      ?= 1
WAVE      ?=
PLUSARGS  ?=
TOP       ?= uvm_tb_top
DV_FLIST  ?= filelists/uvm.f
RUN_ROOT  ?= run
RUN_DIR   ?= $(RUN_ROOT)/$(UVM_TEST)_$(SEED)
PASS_MARK ?= UVM_NO_FATALS

VCS_UVM_VERSION ?= uvm-1.2
VCS_TIMESCALE   ?= 1ns/1ps
VCS_DEBUG       ?= -debug_access+all

VCS_BUILD_OPTS := -full64 -sverilog -ntb_opts $(VCS_UVM_VERSION) \
    -timescale=$(VCS_TIMESCALE) -top $(TOP) $(VCS_DEBUG)

VCS_LINK_COMPAT ?= 1
ifeq ($(VCS_LINK_COMPAT),1)
VCS_BUILD_OPTS += -cc gcc -cpp g++ -LDFLAGS -Wl,-no-as-needed
endif

ifdef VERDI_HOME
PLI_TAB ?= $(VERDI_HOME)/share/PLI/VCS/LINUXAMD64/novas.tab
PLI_A   ?= $(VERDI_HOME)/share/PLI/VCS/LINUXAMD64/pli.a
FSDB_OPTS ?= -fsdb -P $(PLI_TAB) $(PLI_A)
endif

SIM_PLUSARGS := +UVM_TESTNAME=$(UVM_TEST) +ntb_random_seed=$(SEED) +UVM_NO_RELNOTES
ifneq ($(WAVE),)
SIM_PLUSARGS += +WAVE
endif
SIM_PLUSARGS += $(PLUSARGS)

.PHONY: help compile run sim check regress verdi clean clean_all uvm_tests

help:
	@echo "VCS simulation targets:"
	@echo "  make compile UVM_TEST=<test> SEED=<seed>"
	@echo "  make run     UVM_TEST=<test> SEED=<seed> [WAVE=1] [PLUSARGS='...']"
	@echo "  make sim     UVM_TEST=<test> SEED=<seed>"
	@echo "  make check   UVM_TEST=<test> SEED=<seed>"
	@echo "  make verdi   UVM_TEST=<test> SEED=<seed>"
	@echo "  make regress TESTS='test1 test2' SEEDS='1 2 3'"
	@echo "  make clean"
	@echo ""
	@echo "Available UVM tests:"
	@echo "  ping_test           - Basic PING command test"
	@echo "  reg_access_test     - Register read/write test"
	@echo "  mem_access_test     - Memory window access test"
	@echo "  full_function_test  - Full function verification"
	@echo ""
	@echo "Variables: TOP=$(TOP) DV_FLIST=$(DV_FLIST) RUN_DIR=$(RUN_DIR)"

compile:
	mkdir -p $(RUN_DIR)
	vcs $(VCS_BUILD_OPTS) $(FSDB_OPTS) -f $(DV_FLIST) \
	    -Mdir=$(RUN_DIR)/csrc \
	    -o $(RUN_DIR)/simv \
	    -l $(RUN_DIR)/compile.log

run: compile
	./$(RUN_DIR)/simv $(SIM_PLUSARGS) -l $(RUN_DIR)/sim.log
	@if [ -f wave.fsdb ]; then mv wave.fsdb $(RUN_DIR)/wave.fsdb; fi
	@echo "=== Simulation Log Summary ==="
	@grep -E "UVM_INFO|UVM_WARNING|UVM_ERROR|UVM_FATAL|TEST_PASS|TEST_FAIL" $(RUN_DIR)/sim.log | tail -30
	@echo "=============================="

sim: run

check:
	python3 scripts/check_sim_log.py --log $(RUN_DIR)/sim.log --pass-marker $(PASS_MARK)

regress:
	@echo "Running regression..."
	@echo "Tests: $(TESTS)"
	@echo "Seeds: $(SEEDS)"
	@for test in $(TESTS); do \
	  for seed in $(SEEDS); do \
	    echo "Running $$test with seed $$seed..."; \
	    $(MAKE) run UVM_TEST=$$test SEED=$$seed || exit 1; \
	  done; \
	done
	@echo "Regression complete."

verdi:
	@if [ -f $(RUN_DIR)/wave.fsdb ]; then \
		verdi -sv -f $(DV_FLIST) -top $(TOP) -ssf $(RUN_DIR)/wave.fsdb & \
	else \
		echo "ERROR: No FSDB found. Run with WAVE=1 first."; \
		exit 1; \
	fi

uvm_tests:
	@echo "Running all UVM tests..."
	$(MAKE) regress TESTS="ping_test reg_access_test mem_access_test full_function_test" SEEDS="1"

clean:
	rm -rf $(RUN_ROOT) csrc simv simv.daidir ucli.key DVEfiles *.vpd *.fsdb *.vcd *.log
	rm -rf verdiLog novas* vc_hdrs.h vfastLog

clean_all: clean
