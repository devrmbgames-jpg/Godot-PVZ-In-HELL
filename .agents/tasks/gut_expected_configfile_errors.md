# GUT-CFG01 — Expected ConfigFile diagnostics in the local runner

Status: **IN_PROGRESS**
Priority: **P2**
BASE_SHA: `1420e952b85ab71358faad84c01dceb5e7f72f8a`

## Task state

### Goal
Fix the local runner's evidenced false FAIL for explicitly asserted native ConfigFile parse errors without ignoring unhandled diagnostics or a failing process.

### Current
PVZ-B01's isolated malformed-container GUT passed with exit 0, but `utils/godot_agent.ps1` flagged both `[ExpectedError]` confirmations and the matching native errors. Reproduction: `.artifacts/godot_agent/gut-20261015-163034893.stdout.log` / `.stderr.log`. The repair matches exact per-path native error counts to assertions only for GUT exit 0, strips ANSI for matching and preserves all other diagnostic failures. No production error suppression is used.

### Next
Verify RV-001, commit the bounded repair and request targeted re-review. PVZ-B01 remains open until its required checks and review pass.

### Validation
PASS: 6 Python/native PowerShell contracts, including mismatch counts/path, non-GUT, nonzero exit, ANSI, unrelated/script diagnostics and generic marker rejection. PASS: actual malformed-container GUT 10/10, 147 assertions, runner exit 0; `.artifacts/godot_agent/gut-20261015-163205210.stdout.log` / `.stderr.log`. Expected errors remain in preserved logs. PASS: project structure. Review REVIEW_PENDING. No gameplay/visual checks are required or run (0/8).

### Owner QA / blockers
No owner decision is required for this reversible validation repair. Do not weaken non-GUT, failing process, unmatched error/count or script-error handling.

### Review / triage
Initial read-only review FAIL on TARGET_SHA `2e838766b5312ab56ac884b02d8c47e82a32565e`.
RV-001 (R1), P2, **ACCEPTED**: counts covered stdout markers/stderr native diagnostics, while suppression covered both streams. An additional native stdout line or marker in stderr could be suppressed without being counted. Main confirmed the exact source logic. Repair counts both patterns across the same combined streams used for suppression; a regression covers both counterexamples and a valid reversed-stream pair. Fix SHA and targeted re-review pending.

### Completion
Only DONE after relevant Python/PowerShell tests, real negative-input GUT, immutable review and triage; then archive the same record with corrected links.
