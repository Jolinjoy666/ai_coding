// DV/UVM filelist for AttentionCore-SOC
// Compilation order: interfaces -> agent pkgs -> env pkgs -> seq pkgs -> test pkgs -> tb_top -> rtl

// Include directories
+incdir+../dv/tb
+incdir+../dv/uvm/agents/apb
+incdir+../dv/uvm/env
+incdir+../dv/uvm/scoreboard
+incdir+../dv/uvm/sequences
+incdir+../dv/uvm/tests

// APB interface (must be before packages that use it)
../dv/uvm/agents/apb/apb_if.sv

// Agent packages
../dv/uvm/agents/apb/apb_pkg.sv

// Environment package (imports apb_pkg, includes scoreboard and env)
../dv/uvm/env/attn_env_pkg.sv

// Sequence package
../dv/uvm/sequences/attn_sequences_pkg.sv

// Test package
../dv/uvm/tests/attn_tests_pkg.sv

// TB top
../dv/tb/uvm_tb_top.sv

// RTL (included last)
-f filelists/rtl.f
