# FSM Design Standard

## Scope

This standard defines recommended finite state machine structure for synthesizable RTL.

## Recommended styles

Use two-process or three-process FSM style:

- Two-process FSM: combinational next-state logic plus sequential state register.
- Three-process FSM: next-state logic, state register, and registered output logic.

## State declaration

Use an explicit enum type:

```systemverilog
typedef enum logic [1:0] {
    ST_IDLE,
    ST_BUSY,
    ST_DONE,
    ST_ERR
} state_e;

state_e state_q, state_d;
```

## Next-state logic

- Default `state_d = state_q`.
- Cover all legal states.
- Include safe illegal-state recovery.
- Use `unique case` only when the assumption is valid.
- Keep transition conditions stable and understandable.

Example:

```systemverilog
always_comb begin
    state_d = state_q;
    unique case (state_q)
        ST_IDLE: begin
            if (start_i) begin
                state_d = ST_BUSY;
            end
        end
        ST_BUSY: begin
            if (error_i) begin
                state_d = ST_ERR;
            end else if (last_fire) begin
                state_d = ST_DONE;
            end
        end
        ST_DONE: begin
            state_d = ST_IDLE;
        end
        ST_ERR: begin
            if (clear_i) begin
                state_d = ST_IDLE;
            end
        end
        default: begin
            state_d = ST_IDLE;
        end
    endcase
end
```

## State register

```systemverilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_q <= ST_IDLE;
    end else begin
        state_q <= state_d;
    end
end
```

## Output guidance

- Register outputs that drive external modules when glitches are risky.
- Keep combinational outputs simple and fully assigned.
- Do not allow output behavior to depend on unstable asynchronous inputs.

## Encoding guidance

- Binary encoding is usually area-efficient.
- One-hot encoding may improve high-frequency control decode.
- Gray encoding may help when encoded state is involved in crossing or low-toggle transitions, but CDC still requires safe structure.
- Encoding choices should be driven by timing, area, and tool behavior.

## Checklist

- All legal states are covered.
- Default recovery exists for illegal states.
- Reset state is architecturally valid.
- State transitions are free of off-by-one errors.
- Deadlock and livelock conditions are considered.
- Timeout or clear behavior exists when required.
- State outputs are glitch-safe for consumers.
