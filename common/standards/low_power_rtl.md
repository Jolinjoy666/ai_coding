# Low-Power RTL Standard

## Scope

This document defines RTL-level low-power practices for digital IC front-end design.

## Clock gating policy

- Do not directly gate clocks with RTL logic.
- Use register enables and let the synthesis flow infer clock gating when methodology supports it.
- Use approved clock-gating wrappers or standard ICG cells only when required by the project.
- Clock-gating enable must be stable and glitch-safe.
- Gated clocks require CTS, DFT, STA, and test-mode support.

## Clock enable style

Preferred RTL style:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_q <= '0;
    end else if (data_en) begin
        data_q <= data_d;
    end
end
```

## Operand isolation

Use operand isolation when expensive datapath units toggle unnecessarily in invalid cycles.

Example:

```systemverilog
assign mul_a = mul_en ? real_a : '0;
assign mul_b = mul_en ? real_b : '0;
```

Apply carefully:

- Isolation muxes add area and delay.
- Valid-cycle data must not change.
- High-value targets include multipliers, wide adders, SRAM address/data buses, and high-toggle comparators.

## Memory power

- Use chip enable or clock enable.
- Avoid unnecessary reads and writes.
- Consider bank gating for large memories.
- Reduce unnecessary address and write-data toggling.
- Prefer memory macros over flop arrays for large memories.

## Low-power review questions

- Are inactive datapath units unnecessarily toggling?
- Are memory enables used correctly?
- Does clock-enable logic preserve function under stall and flush?
- Does any clock gating satisfy DFT and STA methodology?
- Does isolation change X-prop, reset, or debug visibility?
