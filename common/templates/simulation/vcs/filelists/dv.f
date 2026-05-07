+incdir+../tb
+incdir+../../dv/tb
+incdir+../../dv/uvm/env
+incdir+../../dv/uvm/agents
+incdir+../../dv/uvm/sequences
+incdir+../../dv/uvm/tests
+incdir+../../dv/uvm/scoreboard
+incdir+../../dv/uvm/coverage
+
+# Recommended order:
+# 1. Interfaces.
+# 2. Agent packages.
+# 3. Env packages.
+# 4. Sequence packages.
+# 5. Test packages.
+# 6. TB top.
+# 7. RTL filelist.
+
+# ../../dv/tb/dut_if.sv
+# ../../dv/uvm/agents/<agent>_pkg.sv
+# ../../dv/uvm/env/<env>_pkg.sv
+# ../../dv/uvm/sequences/<seq>_pkg.sv
+# ../../dv/uvm/tests/<test>_pkg.sv
+# ../../dv/tb/tb_top.sv
+
-f filelists/rtl.f
