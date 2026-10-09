# Refactoring v2.44 — AI obligations, goal selection и LimboAI execution

Status: **IN_PROGRESS**

Зависимости: [43_smart_objects.md](../completed/refactoring_v2/43_smart_objects.md), [47_game_time_randomness.md](../completed/refactoring_v2/47_game_time_randomness.md), stable NPC domain.

## Goal

Разделить macro planning и realtime execution.

## Ownership

- authored schedule — deterministic obligations;
- bounded Goal selection — текущий приоритет и interruption policy;
- pure Utility scoring optional при реальной конкуренции целей; без отдельного framework;
- GOAP — DEFER, вне обязательного scope;
- LimboAI — local execution, combat, interrupts и realtime reactions;
- ECS — authoritative state.

## Constraints

- выбранная obligation/action в ECS; derived scoring не становится authority;
- decision layer не управляет physics;
- combat остаётся LimboAI/local systems;
- action adapters ограничены existing capabilities;
- selection имеет budget/cadence, meaningful wake events и bounded fallback;
- local/emergency/combat flow виден в LimboAI tree; macro selection не дублирует его;
- interruption/cancel освобождает intent/reservation через owning command; running action не перезапускается каждый decision tick;
- validation/diagnostic provider возникает здесь: selected/rejected reason, obligation source, active action, timeout/cancel reason.
- reuse the existing decision/action state after 15–16; replace overlapping selection paths atomically rather than adding a second goal model. Schedule target is a required obligation, current local target/action is execution state, not a second schedule writer;
- budget belongs to each expensive System responsibility, not a new global scheduler. Stable fair cursor/coalesced wakes + authored work-unit cap + bounded max wait; urgent interrupts cancel stale queued work;
- action identity/lifecycle is ECS-owned accepted/running/completed/failed/cancelled; BT handles control flow, queries result and never restarts or publishes terminal success independently.

## Acceptance

Existing non-combat schedule/service obligation исполняется через LimboAI/action contract; priority interrupt, target loss, action failure и resumption доказаны fixtures. Простой authored schedule не проходит через planner. GOAP не требуется для DONE.
Budget burst fixture proves no unbounded wake queue/starvation and reports due/processed/deferred/max-wait counters. Old selection/intent writer path removed; local emergency decisions remain native LimboAI branches.

Future GOAP разрешается отдельной задачей только при доказанной альтернативной multi-step цели, существенно неудобной для schedule/subtree, с bounded search/observability/cancellation gate. Здесь не создавать пустые planner APIs «на будущее».

## Validation

Goal/priority/cancellation deterministic fixtures + NPC smoke. Time/seed foundation берётся из 47. GOAP tests отсутствуют, пока feature отложена.

## Current / Next

Implemented; awaiting immutable checkpoint review. Base:
`e28cd033e6b127a9b91639b803fc35fcb11590ac`. Task42 visual acceptance remains open.
`S_NpcCadence` caps/coalesces due work with stable-ID fairness; the existing sampled
sensor/trait/BT graph consumes the same captured interval. Route planning retains its own cap.
`C_NpcDecision` owns accepted/running/completed/failed/cancelled schedule execution.
`NpcScheduleActionService` makes explicit transitions; `O_DistrictLifecycle` alone commits
captured goal completion. Emergency/service/control flow remains native LimboAI.
Removed idle's write to `NpcRecord.goal_id`; local activity now belongs to current decision state.
No planner/utility/GOAP path added. Read provider and contract:
[NPC obligation execution](../../docs/npc_obligation_execution.md).
Next: collect exact-SHA review, triage findings, then archive and activate task45.
Completion: all declared fixture/static/parser/NPC smoke gates and review PASS.

## Evidence

- Formatter/lint: PASS, 24 owned scripts.
- Parser: PASS, 24 files / 0 failures; final modified owners also compiled by runtime fixtures.
- Architecture/agent/structure gates: PASS; detected Service cycle removed before checkpoint.
- Final regression: PASS, 160 tests / 1051 assertions across obligation, budget,
  district BT lifecycle and GameClock fixtures (`tests/artifacts/refactoring_v2_44_final_gut.log`).
- Final strengthened timeout/restore fixture: PASS, 47 tests / 308 assertions
  (`tests/artifacts/refactoring_v2_44_final_action_gut.log`).
- Main-level native second-day queue: PASS (`tests/artifacts/refactoring_v2_44_npc_smoke.log`).
- Burst covers duplicate wakes, roster reordering, urgent queued-step invalidation,
  authored work cap and ceil(N/cap) service bound. Diagnostics read existing due/processed/
  deferred/max-wait state, without another mutable provider.
- Review: REVIEW_PENDING. No visual/gameplay-feel QA claimed. Specified shutdown retention:
  KNOWN_ENGINE_LIMITATION / DEFERRED; original logs preserved.
