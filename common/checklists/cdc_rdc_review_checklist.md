# CDC/RDC Review Checklist

## Domain mapping

- **Clock list**: All clocks are listed with frequency, relationship, and source.
- **Reset list**: All resets are listed with polarity, assertion style, release style, and affected domains.
- **Domain ownership**: Each state element belongs to a known clock/reset domain.
- **Generated clocks**: Generated or gated clocks are documented and constrained.

## CDC crossing classification

- **Single-bit level**: Uses a proper synchronizer when crossing asynchronous domains.
- **Single-bit pulse**: Uses toggle synchronizer or request/ack protocol with pulse preservation.
- **Multi-bit data**: Uses async FIFO, handshake with stable bus, or safe protocol.
- **Configuration bus**: Stability window or handshake is documented.
- **Streaming data**: Uses async FIFO or equivalent protocol.
- **Reconvergence**: Recombined synchronized signals are reviewed.

## RDC crossing classification

- **Reset release**: Async release is synchronized to destination clock.
- **Reset ordering**: Domain release order assumptions are documented.
- **Half-reset state**: Consumers cannot observe invalid producer state.
- **Isolation**: Isolation or handshake exists where reset domains can be active independently.
- **Reset synchronizer**: Attributes and constraints are documented.

## Unsafe pattern checks

- **Multi-bit flop chain**: Multi-bit bus is not synchronized with independent two-flop chains without proof.
- **Pulse loss**: Pulse width is safe for destination domain or converted to toggle/handshake.
- **Combinational CDC**: No unregistered combinational crossing exists.
- **Async reset logic**: Reset path does not contain unsafe complex logic.
- **Async FIFO pointers**: Gray-code pointer and full/empty logic are correct.

## Constraints and waivers

- **Clock groups**: Asynchronous clock relationships are constrained.
- **False paths**: Async reset and synchronizer paths follow methodology.
- **Attributes**: Synchronizer flops have appropriate async-reg attributes.
- **Waiver evidence**: Every waiver has crossing type, structure, assumption, and proof.
- **Tool coverage**: CDC/RDC tool setup sees all relevant clocks, resets, and black boxes.

## Verification

- **Assertions**: Handshake, pulse preservation, FIFO overflow/underflow, and reset sequencing are checked.
- **Formal**: FIFO and protocol-based crossings have formal candidates.
- **Reset tests**: Simulation includes different reset release orders.
- **Backpressure tests**: Async stream tests include both sides stalling or rate-changing.
