# Refactoring v2.45 — NPC Simulation LOD

Status: **IN_PROGRESS**

Зависимости: [44_ai_schedule_utility_goap.md](../completed/refactoring_v2/44_ai_schedule_utility_goap.md), [04_identity_persistence_contract.md](../completed/refactoring_v2/04_identity_persistence_contract.md), [47_game_time_randomness.md](../completed/refactoring_v2/47_game_time_randomness.md).

## Goal

Снизить processing cost населения через ACTIVE/DORMANT participation и независимую cadence, сохранив существующие physical-root Entity и scene contracts. Это не обещание убрать allocated Node3D/body memory.

## Representation modes

- ACTIVE: existing physical-root Entity + enabled physics/navigation/LimboAI;
- DORMANT: та же registered Entity/body, hidden/frozen/zero collision, navigation/BT disabled.

Cadence/budget independent of participation. NpcRecord остаётся ECS-owned metadata в C_District.people; HP/inventory — actor Components, live links — Relationships. Per-field writer map исключает mutable mode/placement/action copies; identity mirrors readonly, death_day — history committed C_Death outcome. Disabled actors не исчезают из stable-ID resolver/save. Body detach/shell, четыре tiers, новый offscreen travel и aggregation — DEFER: нужны measurements, доказательство недостаточности dormancy и отдельная full caller/scene/BT/save migration task.

## Coherent slices

1. **45A participation ownership:** unify existing set_participating/placement/enable paths behind one owning operation; preserve physical-root scenes. Gate: per-field authority map, no competing caller, all dormant actors resolvable, no nav/BT/physics work while dormant.
2. **45B safe transition:** phase/obligation-driven active↔dormant, generation/idempotency, pin/cancel hold/combat/dialogue/slot session, valid reactivation position and bounded failure. Gate: target loss/removal/death/blocked placement, preserved durable links, released transient sessions and no repeated arrival/settlement. No speculative macro travel.
3. **45C acceptance:** save/reload both modes, same identity/HP/inventory/calendar metadata, performance comparison with population count/processing counters, remove transition adapters/allowlist. DONE only after A–C; each slice coherent commit.

## Work

- one participation/activation contract;
- stable identity;
- existing home/outside/phase progression;
- reservation/goal behavior при representation transition;
- save/restore;
- deterministic transition tests;
- aggregate population queries progress dormant metadata; default enabled-only actor queries are not used for save/cleanup/schedule;
- body and Entity stay the same owner; physical state remains Godot authority;
- diagnostic provider показывает mode/pin/transition reason и pending arrival.
- Street NPC is not hidden merely because it leaves camera view; ACTIVE/DORMANT follows existing placement/participation semantics. Reduced active cadence is separate, with bounded response latency. Dormant hunger/health/action timers follow their current absent-phase owner policy; no blanket elapsed-time catchup/new offscreen outcomes.

## Acceptance

Representative NPC stops active processing, preserves existing absent-phase lifecycle and reactivates without duplicate identity/state. Body allocation is explicitly retained; measured update savings are recorded, not assumed.

Authored placed NPC remains visible in Editor. All old participation dispatchers/duplicate writers removed; retained physical-root and aggregate metadata are the chosen target, not temporary adapters. No offscreen combat/new economy. Schema changes versioned; old-save migration not required.

## Validation

LOD transition tests + save/restore smoke + performance sanity check.

## Current / Next

45A reviewed at `69a3b9729f21be26e0e75cf08a3aaa509e51a874`, repaired at
`4e549abab5b5c03280b3363be9f3182f539cdcea`; targeted ARCHITECTURE/STYLE PASS.
45B checkpoint `c119bcb6f0bb53aabd0c390afa884361d44d1423` implements bounded native
shape preflight, explicit phase-arrival retry and rejection before service/home activation.
Its review found RV-002 (missing arrival target). The reproduced defect is repaired;
next: commit/targeted repair review, then final 45C acceptance review and archive.
One placement owner; retained physical roots; no speculative scheduler or mode mirror.
Writer map and measured scope: [NPC participation](../../docs/npc_participation.md).
Full task remains IN_PROGRESS until all slices and review gates are complete.

## Evidence / Current gate

- Baseline: 12 retained bodies, 5 ACTIVE, 5 processing roots, 12 processing mixers.
  `tests/artifacts/refactoring_v2_45_baseline.log`: PASS, 7 tests / 57 assertions.
- After: same 12 bodies / 5 ACTIVE, 5 processing roots / 5 processing mixers.
  Root savings already belonged to GECS; the change stops 7 dormant child mixers.
  Frame time, shipping FPS and body memory savings: NOT_MEASURED / not claimed.
- 45A participation/callback/snapshot acceptance: PASS, 23 tests / 246 assertions
  (`tests/artifacts/refactoring_v2_45a_final_gut.log`).
- RV-001 repair: PASS, 12 tests / 133 assertions, including Night policy
  (`tests/artifacts/refactoring_v2_45a_rv001_after.log`).
- 45B affected customer/BT/activation regression: PASS, 153 tests / 1071 assertions
  (`tests/artifacts/refactoring_v2_45b_regression.log`); parser PASS, 9 files / 0 failures.
- RV-002 reproduction: FAIL, 2 tests / 12 assertions
  (`tests/artifacts/refactoring_v2_45b_rv002_before.log`). Repair: PASS, 20 tests / 204
  assertions (`tests/artifacts/refactoring_v2_45b_rv002_after.log`).
- 45C disk roundtrip ACTIVE/DORMANT, fresh absent body, district persistence and processing
  acceptance: PASS, 54 tests / 554 assertions (`tests/artifacts/refactoring_v2_45c_gut.log`).
- Actual main-level second-day queue headless smoke: PASS
  (`tests/artifacts/refactoring_v2_45_main_smoke.log`, before strict target repair).
- Formatter/lint, changed-source, strict architecture and project-structure gates: PASS.
  Compilation PASS, 6 files / 0 actual compile failures. Isolated fixture child exits 0
  with PASS before shutdown diagnostics; wrapper retention rejection is KNOWN_ENGINE_LIMITATION /
  DEFERRED (`tests/artifacts/refactoring_v2_45c_isolated_parser.log`). Review/QA build pending. No owner visual QA claimed.
  Shutdown-only specified retention remains KNOWN_ENGINE_LIMITATION / DEFERRED.

## Review triage

RV-001 (45A reviewer R1, P1, `DistrictPopulationService.set_placement`): confirmed death
inside native suspension originally failed to supersede a nonterminal placement.
FIXED at `4e549abab5b5c03280b3363be9f3182f539cdcea`, actual C_Death-disable fixture;
targeted review ARCHITECTURE/STYLE PASS. Night's uncommitted history retains its morning owner.

RV-002 (45B reviewer R1, P1, arrival callers): missing home/portal Definitions could resolve
to origin and start a visit. Missing declared anchor could silently use fallback coordinates.
ACCEPTED / FIX_IMPLEMENTED: activation callers require the declared target/anchor, and
nonfinite missing-target poses reject before mode/pose/generation or role/visit mutation.
Actual phase/service missing-home/portal/anchor fixtures reproduce and pass after the repair.
Original 45B review ARCHITECTURE FAIL / STYLE PASS; targeted repair review pending.
Reviewer VALIDATION NOT_RUN; main's executed evidence is listed separately above.
