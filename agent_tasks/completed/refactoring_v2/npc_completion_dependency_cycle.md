# NPC completion request dependency cycle

Status: **DONE**

## Evidence and scope

Task62 exposes a pre-existing behavioral edge hidden by an explicit backslash between
the service symbol and method name. At baseline
`3e5c93dcba93a730e79a632360160db50e88945a`, the lexical dependency graph has no cycle.
After equivalent formatting, it includes `NpcDecisionService -> DistrictPopulationService`.
The resulting cycle is population -> community -> social -> decision -> population.
The engine already executes that call; formatting did not add it. Strict dependency and
project-structure gates therefore block task62 acceptance.

## Repair contract

Move the synchronous `request_phase_completion` operation into existing
`NpcScheduleActionService`, which already owns schedule execution commands. Migrate all
authored callers and tests and remove the old endpoint. Preserve captured record/decision
identity, action generation, placement defaults, synchronous event delivery and receipt.
`O_DistrictLifecycle` remains the discrete transition owner; population placement and native
physics/AI participation authority stay unchanged. Do not weaken dependency validation.

## Acceptance

- Strict dependency/project-structure and formatter/parser gates PASS.
- Focused population/lifecycle/obligation/scheduling GUT PASS.
- Independent immutable review PASS before DONE and archive.

Task62 depends on this repair; its original acceptance is unchanged.

## Current

Operation moved into existing NpcScheduleActionService; all three runtime callers and
three fixture suites migrated. Old population endpoint removed; no new execution path.
Strict dependency/project-structure, architecture/domain and changed/full style gates PASS.
Native MCP task62:163/163 checked, no diagnostics. Actual isolated lifecycle compiler:
PASS,exit0 (`.artifacts/godot_agent/completion62_isolated.stdout.log`). General CLI runner
reports FAIL solely because this fixture emits shutdown retention warnings; logs preserved
as KNOWN_ENGINE_LIMITATION / DEFERRED under owner policy. No runtime error reported.
Focused completion regression PASS:6 suites,181 tests,1282 assertions; see
`.artifacts/godot_agent/completion62_gut` logs.
Independent immutable review PASS, no material findings: BASE
`3e5c93dcba93a730e79a632360160db50e88945a`, TARGET
`4e813c68d1824ca589ddc96ab683e32c12462886`. Reviewer source review only,
ARCHITECTURE/STYLE PASS, VALIDATION NOT_RUN. Acceptance complete.
