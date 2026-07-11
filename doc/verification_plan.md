# UART FIFO Verification Plan

## Scope

The verification environment checks the UART-to-FIFO loopback path. It drives
serial data on `rx`, monitors serial data on `tx`, and compares the observed
bytes with a scoreboard-owned expected-data queue. RTL behavior is not changed
by this environment.

## Test Matrix

| Scenario | Stimulus | Primary checks |
| --- | --- | --- |
| `single` | `A5` | One input byte appears unchanged at `tx`. |
| `multi` | `11 22 33 44` | Four bytes retain ordering without loss. |
| `stream` | `00` through `13` | Twenty sequential bytes retain ordering. |
| `fifo` | Eight writes followed by eight reads | `full` asserts after filling; `empty` asserts after draining. |
| `reset` | Reset followed by `A5` | Loopback resumes after reset. |
| `all` | All scenarios | Full regression returns zero errors and no pending expected bytes. |

## Pass Criteria

- Every monitored byte matches the next expected byte in the scoreboard queue.
- No unexpected bytes are observed.
- The expected-data queue is empty at the end of the test.
- FIFO `full` and `empty` are never asserted together.
- The simulation exits successfully with `ERROR : 0`.
