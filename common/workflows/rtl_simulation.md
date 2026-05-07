# RTL Simulation Workflow

1. Confirm DUT, TB top, filelist, expected behavior, and pass marker.
2. Use `rtl_simulation_debug` for simulator-agnostic smoke or directed tests.
3. Use `vcs_simulation_flow` when the project uses Synopsys VCS.
4. Run smoke simulation.
5. Run wave/debug simulation only when needed.
6. Save logs, waves, commands, and results under `sim/`.
7. If failures occur, invoke regression/debug skills.
