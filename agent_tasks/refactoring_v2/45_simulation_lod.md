# Refactoring v2.45 — NPC Simulation LOD

Status: **PLANNED**

Зависимости: [44_ai_schedule_utility_goap.md](44_ai_schedule_utility_goap.md), [04_identity_persistence_contract.md](04_identity_persistence_contract.md), [47_game_time_randomness.md](47_game_time_randomness.md).

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

## Acceptance

Representative NPC stops active processing, preserves existing absent-phase lifecycle and reactivates without duplicate identity/state. Body allocation is explicitly retained; measured update savings are recorded, not assumed.

Authored placed NPC remains visible in Editor. All old participation dispatchers/duplicate writers removed; retained physical-root and aggregate metadata are the chosen target, not temporary adapters. No offscreen combat/new economy. Schema changes versioned; old-save migration not required.

## Validation

LOD transition tests + save/restore smoke + performance sanity check.
