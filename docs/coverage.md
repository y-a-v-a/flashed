# Core coverage

NFR-3 requires `Core/` to have **≥90% line coverage** under unit tests.
This document records the measurement procedure and the current state.

## How to measure

From the repository root:

```sh
./scripts/measure-core-coverage.sh
```

The script runs `swift test --enable-code-coverage` and prints a per-file
report via `xcrun llvm-cov`. Test files and SwiftPM build artifacts are
excluded.

## Current state (as of TASKS 1.7 close-out)

| File                       | Line coverage |
|----------------------------|--------------:|
| ElementKind.swift          |      100.00 % |
| MorseEncoder.swift         |       88.64 % |
| MorseRenderer.swift        |      100.00 % |
| MorseTable.swift           |      100.00 % |
| ScheduleTick.swift         |      100.00 % |
| TimedElement.swift         |      100.00 % |
| TimingProfile.swift        |      100.00 % |
| TransmissionSchedule.swift |      100.00 % |
| ValidatedMessage.swift     |       96.77 % |
| **Total**                  |  **97.21 %**  |

## What the misses are

The two non-100 % files contain unreachable defensive branches that the
type system rules out by construction. Pinning these down is more useful
than chasing 100 %:

1. **`MorseEncoder.swift` — the `preconditionFailure` branch.** The
   encoder calls `MorseTable.symbols(for:)` after `ValidatedMessage` has
   already guaranteed every non-space character is supported. The `nil`
   path therefore cannot fire; the precondition is there to crash loudly
   if an invariant is ever broken by future refactors.

2. **`ValidatedMessage.swift` — the `normalize` fallback `return character`.**
   `normalize` is only called after `MorseTable.supports(_:)` accepts the
   character. `supports` rejects non-ASCII, so the non-ASCII branch in
   `normalize` is unreachable. Same justification: defensive against
   future refactors.

Neither is in the public API surface; both are guards against logic bugs.
The cost of reaching them in tests would be either lying to the type
system (constructing invalid `ValidatedMessage`s) or removing the guards,
both of which are worse than the missed coverage.
