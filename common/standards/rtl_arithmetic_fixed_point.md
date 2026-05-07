# RTL Arithmetic and Fixed-Point Standard

## Scope

This document defines RTL guidance for arithmetic, bit width, signedness, fixed-point behavior, rounding, truncation, saturation, and overflow.

## Bit-width management

- Define input, internal, and output widths for every datapath.
- Addition and subtraction usually require one extra bit for carry or borrow.
- Multiplication result width is usually the sum of operand widths.
- Accumulator width must account for maximum accumulation count.
- Shift behavior must define whether sign is preserved.
- Concatenation and slicing must be explicit.
- Avoid unsized constants in datapath expressions.

## Signed and unsigned rules

- Declare signed signals explicitly when signed math is intended.
- Use `$signed()` casts at expression boundaries.
- Do not rely on implicit signed/unsigned conversion.
- Mixed signed/unsigned comparison must be manually normalized.
- Concatenation results are unsigned unless explicitly cast.
- Arithmetic right shift requires signed operand intent to be clear.

Example:

```systemverilog
logic signed [15:0] a_s;
logic signed [15:0] b_s;
logic signed [31:0] prod_s;

assign prod_s = $signed(a_s) * $signed(b_s);
```

## Truncation, rounding, and saturation

Every numeric datapath should define:

- Whether truncation takes low bits, high bits, or a fixed-point slice.
- Whether rounding is disabled or uses round-half-up, round-to-nearest-even, stochastic rounding, or another rule.
- Whether overflow wraps, saturates, raises error, or is illegal.
- Saturation boundaries when saturation is used.
- Signed saturation asymmetry when using two's complement numbers.

## Reference model alignment

Any RTL change that affects numeric behavior must update or validate the reference model.

This includes:

- Width change.
- Cast change.
- Rounding change.
- Saturation change.
- Pipeline latency change in numerical output.
- Overflow behavior change.

## Common bugs

- One operand is cast signed but the other is not.
- Unsized constant widens or changes expression signedness.
- Shift drops sign unintentionally.
- Accumulator overflows for maximum legal sequence.
- Truncation semantics differ from reference model.
- Saturation boundary is off by one.
