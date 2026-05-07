SIM       ?= vcs
UVM_TEST  ?= smoke_test
SEED      ?= 1
WAVE      ?=
PLUSARGS  ?=
TOP       ?= tb_top
DV_FLIST  ?= filelists/dv.f
RUN_ROOT  ?= run
RUN_DIR   ?= $(RUN_ROOT)/$(UVM_TEST)_$(SEED)
PASS_MARK ?= TEST_PASS

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

.PHONY: help compile run sim check regress verdi clean clean_all

help:
	@echo "VCS simulation targets:"
	@echo "  make compile UVM_TEST=<test> SEED=<seed>"
	@echo "  make run     UVM_TEST=<test> SEED=<seed> [WAVE=1] [PLUSARGS='...']"
	@echo "  make sim     UVM_TEST=<test> SEED=<seed>"
	@echo "  make check   UVM_TEST=<test> SEED=<seed>"
	@echo "  make verdi   UVM_TEST=<test> SEED=<seed>"
	@echo "  make clean"
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
	python3 scripts/check_sim_log.py --log $(RUN_DIR)/sim.log --pass-marker $(PASS_MARK)

sim: run

check:
	python3 scripts/check_sim_log.py --log $(RUN_DIR)/sim.log --pass-marker $(PASS_MARK)

regress:
	@for test in $(TESTS); do \
	  for seed in $(SEEDS); do \
	    $(MAKE) run UVM_TEST=$$test SEED=$$seed || exit 1; \
	  done; \
	done

verdi:
	@if [ -f $(RUN_DIR)/wave.fsdb ]; then \
		verdi -sv -f $(DV_FLIST) -top $(TOP) -ssf $(RUN_DIR)/wave.fsdb & \
	else \
		echo "ERROR: No FSDB found. Run with WAVE=1 first."; \
		exit 1; \
	fi

clean:
	rm -rf $(RUN_ROOT) csrc simv simv.daidir ucli.key DVEfiles *.vpd *.fsdb *.vcd *.log
	rm -rf verdiLog novas* vc_hdrs.h vfastLog

clean_all: clean
