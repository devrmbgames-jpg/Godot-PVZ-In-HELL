# Refactoring v2.45 — NPC Simulation LOD

Status: **PLANNED**

Зависимости: [44_ai_schedule_utility_goap.md](44_ai_schedule_utility_goap.md), [04_identity_persistence_contract.md](04_identity_persistence_contract.md), [47_game_time_randomness.md](47_game_time_randomness.md).

## Goal

Разделить физическое представление NPC и macro simulation, чтобы население могло жить без постоянных Node3D/physics/BT.

## Representation modes

- PHYSICAL: canonical lightweight GECS Entity + physical/visual child + LimboAI;
- MACRO: та же Entity и authoritative Components/Relationships, без body/BT.

Cadence/budget independent of representation. Четыре tiers и population aggregation — DEFER до measured need. NpcRecord становится snapshot DTO, не параллельной live authority. Текущий physical-root E_DistrictNpc и C_District.people требуют явной migration всех direct body casts, BT agent bindings, damage/interaction target resolution, scene exports/paths и save adapters.

## Coherent slices

1. **45A identity/representation separation:** все NPC используют один canonical Entity owner при ещё обязательном PHYSICAL; DTO/live-record duplication удалена; consumers и save/load мигрированы; no old physical-root gameplay path. Gate: actor/body resolution, health/inventory/links, placed/spawn parity, current-format save, NPC/combat/interaction regression.
2. **45B macro transition:** detach/attach child, macro obligations/travel timestamps, safe materialization, token/idempotency, pinning active combat/hold/dialogue/slot usage. Gate: physical↔macro, blocked spawn, deletion/death/target loss, concurrent transition и links continuity.
3. **45C acceptance:** save/reload в обоих modes, no duplicate state/outcomes, performance sanity, remove transition adapters/allowlist. DONE только после A–C; каждый slice — самостоятельный coherent commit/rollback.

## Work

- materialize/dematerialize contract;
- stable identity;
- travel/arrival macro state;
- reservation/goal behavior при representation transition;
- save/restore;
- deterministic transition tests;
- macro Entity остаётся enabled; gameplay queries фильтруют required capabilities;
- body/glue не вторая gameplay Entity; physical state остаётся Godot authority;
- diagnostic provider показывает mode/pin/transition reason и pending arrival.

## Acceptance

Representative NPC может уйти из physical representation, продолжить macro lifecycle и восстановиться без duplicate identity/state.

Authored placed NPC остаётся видимым в Editor. Legacy physical-root gameplay callers/parallel NpcRecord authority отсутствуют. Offscreen combat/new economy не добавляются. Schema changes используют version bump, old-save migration не требуется.

## Validation

LOD transition tests + save/restore smoke + performance sanity check.
