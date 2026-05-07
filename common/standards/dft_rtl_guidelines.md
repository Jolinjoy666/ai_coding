# DFT RTL Guidelines

## Scope

This document defines RTL design considerations for Design-for-Test readiness.

## General rules

- Avoid uncontrolled internally generated clocks.
- Avoid unapproved gated clocks.
- Keep reset controllable and observable.
- Avoid latch inference unless explicitly required and testable.
- Avoid internal tristate structures.
- Provide clean test mode behavior when required.
- Expose memory BIST, repair, or test hooks through wrappers when required.

## Clock and reset considerations

- Clock gating must use approved cells or methodology.
- Test mode may need to force clock gates open.
- Async resets should be simple and controllable.
- Reset synchronizers must be compatible with scan and reset testing.
- Multiple clock domains need a test-mode clock control strategy.

## Low-power and DFT interaction

- Isolation and retention logic must have test-mode behavior.
- Clock gating must not block scan shifting or capture unless intentionally controlled.
- Power gating and retention are usually handled by UPF/CPF and implementation methodology, but RTL must expose required controls.

## Memory DFT

- SRAM wrappers should expose BIST or repair ports if required.
- Wrapper simulation models should account for test-mode behavior when relevant.
- Do not hide memory behavior behind untestable internal control.

## Review questions

- Are all flops scannable or intentionally excluded?
- Are resets controllable in test mode?
- Are clock gates test-controllable?
- Are generated clocks documented and constrained?
- Are memories wrapped for BIST/repair needs?
- Are latches avoided or explicitly justified?
