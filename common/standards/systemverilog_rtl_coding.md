# SystemVerilog RTL Coding Standard

## Scope

This standard defines the default synthesizable SystemVerilog coding style for digital IC RTL in this workspace.

## Recommended language subset

Use synthesizable SystemVerilog constructs when supported by the project toolchain:

- `logic`
- `always_ff`
- `always_comb`
- `typedef enum logic [...]`
- `struct packed`
- `localparam`
- `generate` / `genvar`
- packed and unpacked arrays
- `interface` / `modport` only when tool support is confirmed

Avoid in synthesizable RTL:

- `#delay`
- `force` / `release`
- unprotected `$display`, `$finish`, `$stop`
- dynamic arrays, queues, classes, mailboxes, semaphores
- file I/O
- simulation delta-cycle dependent behavior
- `initial` for functional state unless FPGA or memory initialization support is explicit

## Naming conventions

Use consistent project-level naming. Recommended defaults:

- Clock: `clk`, `clk_<domain>`
- Active-low reset: `rst_n`
- Active-high reset: `rst`
- Input suffix: `_i`
- Output suffix: `_o`
- Register current value: `_q`
- Register next value: `_d`
- Ready/valid transfer: `*_fire`
- Write signals: `we`, `waddr`, `wdata`
- Read signals: `re`, `raddr`, `rdata`
- FSM state: `state_q`, `state_d`
- Counter: `*_cnt_q`, `*_cnt_d`
- Enable: `*_en`
- Synchronized signal: `*_sync`
- Delayed or pipelined signal: `*_d1`, `*_d2`, `*_pipe`

Active-low signals must show active-low polarity in the name.

## Parameters and widths

- Use parameters for configurable width, depth, port count, ID count, burst length, and pipeline stage count.
- Use `localparam` for derived constants that must not be overridden externally.
- Handle `$clog2` carefully when depth may be 1.
- Use sized constants in control and datapath arithmetic.
- Make concatenation, slicing, extension, truncation, and shifting explicit.

Recommended address width pattern:

```systemverilog
localparam int unsigned ADDR_W = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
logic [ADDR_W-1:0] rd_addr_q;
```

## Sequential logic

- Use `always_ff` for flip-flops.
- Use nonblocking assignment `<=` in sequential logic.
- Drive each register from exactly one `always_ff` block.
- Keep reset branches simple and deterministic.
- Do not drive register variables from combinational logic.

Recommended pattern:

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_q <= 1'b0;
    end else begin
        valid_q <= valid_d;
    end
end
```

## Combinational logic

- Use `always_comb` for complex combinational logic.
- Use blocking assignment `=` in combinational logic.
- Assign safe defaults to every output and next-state variable.
- Use `unique`, `unique0`, or `priority` when they express real intent.
- Include a `default` branch for `case` statements unless a project-specific formal proof covers completeness.
- Avoid combinational loops and self-feedback.

Recommended pattern:

```systemverilog
always_comb begin
    grant_o = '0;
    unique0 case (1'b1)
        req_i[0]: grant_o[0] = 1'b1;
        req_i[1]: grant_o[1] = 1'b1;
        req_i[2]: grant_o[2] = 1'b1;
        default: grant_o = '0;
    endcase
end
```

## Common anti-patterns

- Blocking assignment for flop update.
- Missing combinational default assignment causing unintended latch.
- Unsized constants in arithmetic.
- Multiple procedural drivers for one register.
- Implicit signed/unsigned conversion.
- Large asynchronous-read flop array when a RAM is intended.
- Hand-written clock gating.
- Simulation-only behavior hidden in synthesizable RTL.
