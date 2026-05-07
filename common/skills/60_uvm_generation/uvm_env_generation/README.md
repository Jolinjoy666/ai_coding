# uvm_env_generation

## Purpose

Generate or update a UVM verification environment for a digital IC block.

This skill creates verification architecture and UVM components from interface contracts, micro-architecture, RTL behavior, and testplan intent.

## When to use

Use this skill when:

- A block needs UVM verification.
- Agents, env, sequences, tests, scoreboard, or coverage need to be created or updated.
- RTL interface or latency changes require DV updates.
- A testplan needs mapping to UVM components.

## Inputs

- Interface contract.
- Micro-architecture document.
- RTL module interfaces.
- Testplan or verification intent.
- Reference model behavior.
- Existing UVM environment if any.

## Outputs

- UVM environment architecture.
- Agent/driver/monitor/sequencer plan.
- Sequence and test plan mapping.
- Scoreboard and reference model integration plan.
- Functional coverage plan.
- Assertion recommendations.
- Filelist and simulation-flow update notes.

## Rules

- Do not generate UVM components without a clear interface contract.
- Monitor sampling latency must match DUT protocol.
- Scoreboard expected behavior must match reference model and RTL latency.
- Coverage must map to requirements and testplan items.
- UVM changes must include simulation commands or flow update notes.
