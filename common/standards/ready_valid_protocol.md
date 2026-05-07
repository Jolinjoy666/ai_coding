# Ready/Valid Protocol Standard

## Scope

This standard defines the default ready/valid streaming handshake convention.

## Basic semantics

- A transfer occurs when `valid && ready` is true on a clock edge.
- `valid` means the source has a stable payload.
- `ready` means the sink can accept the payload.
- When `valid && !ready`, payload and sideband must remain stable.
- The source should not wait for `ready` before asserting `valid`, otherwise deadlock may occur.
- The sink may use resource availability to assert or deassert `ready`.

Recommended fire signal:

```systemverilog
assign in_fire  = in_valid  && in_ready;
assign out_fire = out_valid && out_ready;
```

## Payload stability

Payload includes all fields transferred with `valid`:

- data
- byte enables
- address
- command
- ID
- last
- user sideband
- error/status sideband

All payload fields must stay aligned with their corresponding `valid` bit.

## Backpressure

- Ready can be combinational or registered depending on timing requirements.
- Long combinational ready chains should be broken with skid buffers or elastic buffers.
- Ready paths must not form combinational loops.
- Adding a buffer changes internal latency and may affect external latency if not transparent.

## Skid and elastic buffers

Use buffering when:

- Ready path is too long.
- A module must accept one more beat after downstream stalls.
- Backpressure must be decoupled between blocks.
- Timing closure requires breaking control feedback.

Check:

- Full/empty state.
- Same-cycle push and pop.
- Payload hold under stall.
- Valid/data/sideband alignment.
- Reset state of valid/full bits.

## Assertion recommendations

Useful properties:

- Payload stable when stalled.
- No transfer when invalid.
- No overflow or underflow in buffers.
- Eventually-ready or fairness assumptions when required by protocol.

Example:

```systemverilog
`ifndef SYNTHESIS
assert property (@(posedge clk) disable iff (!rst_n)
    in_valid && !in_ready |-> $stable(in_data)
);
`endif
```

## Common bugs

- Source waits for ready before asserting valid.
- Payload changes while stalled.
- Valid pipeline depth differs from data pipeline depth.
- Sideband is not pipelined with data.
- Ready path forms a long cross-module combinational chain.
- A skid buffer mishandles same-cycle push and pop.
