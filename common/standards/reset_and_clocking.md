# Reset and Clocking Standard

## Scope

This standard defines reset and clocking guidance for synthesizable digital IC RTL.

## Reset strategy options

Common strategies:

- Asynchronous assert and synchronous release.
- Fully synchronous reset.
- No-reset datapath register protected by valid/control logic.
- Memory not reset through full-array reset logic.

Choose the reset style based on project methodology, STA assumptions, DFT requirements, and target implementation.

## Objects that usually require reset

Reset these unless the architecture explicitly says otherwise:

- FSM state.
- Valid bits.
- Ready/credit/control state.
- Counters that affect visible control behavior.
- Software-visible registers.
- Sticky status and error bits.
- CDC/RDC synchronizer state.
- Reset handshakes and isolation state.

## Objects that may avoid reset

These may remain unreset when protected by valid or initialization protocol:

- Payload pipeline registers.
- Temporary datapath registers.
- Large memory arrays.
- Non-visible intermediate arithmetic state.

## Asynchronous reset guidance

- Async assert must not rely on complex combinational logic.
- Async release should be synchronized to each destination clock domain.
- Reset synchronizers should be recognized by CDC/RDC tools.
- Apply proper async-reg attributes and timing exceptions according to project methodology.
- Consider reset tree fanout and timing impact.

## Synchronous reset guidance

- Synchronous reset is STA-friendly and often easier for synthesis optimization.
- It requires a running clock during reset.
- High-fanout synchronous reset may become a timing path and require replication or hierarchy planning.

## Memory reset guidance

- Do not reset large RAMs or register files with loops unless explicitly required.
- Reset control metadata instead, such as valid bits, pointers, counters, and status.
- If memory contents are architecturally visible after reset, define initialization behavior explicitly.

## Clocking guidance

- Do not create internal clocks with random RTL logic.
- Do not directly gate clocks with combinational expressions.
- Use enables or approved clock-gating wrappers.
- Generated clocks must be documented and constrained.
- Test mode and scan requirements must be considered for gated or generated clocks.

## Review questions

- Is reset polarity and synchronization clear?
- Are all visible control states reset deterministically?
- Are datapath registers safely masked if unreset?
- Are reset release crossings analyzed?
- Is reset behavior consistent with verification and software expectations?
