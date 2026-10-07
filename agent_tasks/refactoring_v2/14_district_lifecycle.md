# Refactoring v2.14 — District lifecycle, population и schedule

Status: **DONE**

Зависимости: [13_customer_outcomes.md](13_customer_outcomes.md); customer planning/runtime завершены через 11–13.

## Goal

Сделать районный scheduled lifecycle явным и убрать `S_District -> DistrictScheduleService.tick` shell pattern.

## Scope

- `S_District`;
- `DistrictScheduleService`;
- scheduled части `DistrictPopulationService`;
- day/phase placement transitions;
- death/placement reconciliation;
- spawn/despawn/participation one-shot operations.

`DistrictPopulationService` не нужно уничтожать: lookup, spawn commands и registry operations могут оставаться сервисом.

## Acceptance

- phase/schedule progression принадлежит System/Observer;
- population Service не становится scheduler;
- district ordering относительно Customer/Day/NPC Intent остаётся явно заданным через deps/events.

## Validation

District population/schedule tests + parser.

## Completed migration

- Deleted DistrictScheduleService and its tick/forwarder. S_District only bootstraps a
  missing/restored calendar snapshot; deps explicitly precede CustomerFlow, DayPhase,
  NpcDecision and NpcIntent. O_DistrictLifecycle owns calendar/death reactions and
  phase goal/completion/preparation mutation. No per-frame population polling remains.
- Population Service retains explicit registry, materialization, participation and death
  transactions. Removed plan_phase/complete_phase writers and migrated all runtime,
  native BT, tests and smoke callers to typed commands; no compatibility aliases.
- NpcScheduleRules contains pure authored goal/completed-placement selection. Resources
  remain records inside the authoritative C_District aggregate; command identity references
  only reject replaced records and are never persisted or independent live bindings.
- Preparation/plan/completion receipts become terminal at actual buffer commit/rejection.
  Queued completion revalidates body registration, record identity, service role, goal and
  decision owner. Native completion leaf stays RUNNING while pending. Dormant retained
  bodies can be reactivated; enabled-only interaction availability is not their lifetime rule.
- Service release/defer publishes one forced replan instead of invalidating a cache for
  recurring polling. Escape/route-skip submit explicit completion intent. Physical placement
  stays an explicit synchronization/participation operation; Godot owns normal movement.
- Night save waits for actual future-morning preparation before capture and retries without
  repeating evening closure/reset/replacement. Current-format restore invalidates transient
  lifecycle cache; actual S_District bootstrap rebuilds it. Old-save migration is not needed.

## Acceptance result

**PASS**: phase/schedule ownership is explicit System/Observer execution, population Service
is not a scheduler, and District/Customer/Day/decision/intent ordering is declared.

## Validation result

- District population/lifecycle/native BT/snapshot/stage acceptance/persistence baseline and
  world-snapshot GUT: **152/152**, **1340 assertions**.
- Final lifecycle GUT after actual System bootstrap coverage: **17/17**, **116 assertions**.
  Includes replay, night death boundary, queued stale record/goal/interruption, native pending
  completion, duplicate future-morning preparation and night-save receipt gates.
- Changed-script Godot parser: **21 files, 0 failures**.
- Actual main-level headless district delivery-offers smoke: **write PASS + restore PASS**
  in separate engine processes, with current-format full-world snapshot.
- Structure, architecture (**25** remaining lexical findings), persistence baseline,
  roadmap preflight and diff checks: **PASS**. District scheduler allowances removed.
- Headless editor import refreshed class metadata; known third-party shutdown diagnostics
  are separate from clean parser/GUT/runtime checks. No rendered or subjective QA performed.

Next: [15_npc_brain.md](15_npc_brain.md). No owner gameplay/visual QA is required here.
