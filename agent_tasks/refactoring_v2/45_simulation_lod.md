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

Authorized by active Goal; task44 reviewed at
`06fdc4c27406f41286d1ba40909f63dab3b98c63` (ARCHITECTURE/STYLE PASS).
45A nearest owner is existing `DistrictPopulationService.set_placement`; restore currently
duplicates its World/body writes. `E_DistrictNpc.set_participating` is the physical adapter,
`NpcBrainService.set_participating` the native BT adapter. Retain one placement operation
and derive ACTIVE/DORMANT from roster placement/death instead of adding a mode copy.
Baseline proves GECS already suspends dormant root callbacks, but child animation mixers
remain active; measure their actual processing eligibility before changing the native adapter.
45A implemented, REVIEW_PENDING: restore uses the single placement operation, repeated
requests are idempotent, callback boundaries reject nested opposite GECS mode commits,
and inherited child processing suspends with the body. Writer map and measured scope:
[NPC participation](../../docs/npc_participation.md).
Base: `0cbd5eaa832c6ab715f05a0699d0c2cc88da1fc5`.
Next: review 45A checkpoint; 45B bounded activation failure/session cleanup, then 45C
same-mode save/reload and final measured processing acceptance. Full task remains IN_PROGRESS.

## Evidence / Current gate

- Baseline: 12 retained bodies, 5 ACTIVE, 5 processing roots, 12 processing animation mixers.
  `tests/artifacts/refactoring_v2_45_baseline.log`: PASS, 7 tests / 57 assertions.
- After 45A: same 12 bodies / 5 ACTIVE, 5 processing roots / 5 processing mixers.
  Root callback savings already belonged to GECS; this change stops 7 dormant child mixers.
  Frame time, shipping FPS and body memory savings: NOT_MEASURED / not claimed.
- Focused participation + previous obligation/cadence: PASS, 105 tests / 708 assertions
  (`tests/artifacts/refactoring_v2_45a_gut.log`, before final callback-lock fixture).
- Final participation/reentrant-native-signal/dormant snapshot: PASS, 23 tests / 246 assertions
  (`tests/artifacts/refactoring_v2_45a_final_gut.log`).
- Parser: PASS, 5 owned files / 0 failures (`tests/artifacts/refactoring_v2_45a_parser.log`).
- Formatter/lint and architecture/structure gates: PASS. Review: REVIEW_PENDING.
- 45B–C acceptance and the final NPC/save smoke are NOT_RUN; no owner visual QA claimed.
  Shutdown-only specified retention remains KNOWN_ENGINE_LIMITATION / DEFERRED.
