# Micro-Architecture Review Checklist

- **Module partitioning clear**: Block responsibilities and boundaries are defined.
- **Interface contracts clear**: Protocol, latency, backpressure, sideband, and error behavior are explicit.
- **Parameters defined**: Widths, depths, ID counts, and legal ranges are known.
- **Control defined**: FSM, counters, arbitration, flush, clear, timeout, and error paths are documented.
- **Datapath defined**: Pipeline, alignment, arithmetic, and formatting are clear.
- **Memory defined**: Latency, collision, reset/init, and mapping strategy are explicit.
- **Reset/CDC/RDC defined**: Domains and crossing strategies are documented.
- **Verification seeded**: Assertions, tests, and coverage points are identified.
