# Refactoring v2.44 — AI obligations, goal selection и LimboAI execution

Status: **PLANNED**

Зависимости: [43_smart_objects.md](43_smart_objects.md), [47_game_time_randomness.md](47_game_time_randomness.md), stable NPC domain.

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

## Acceptance

Existing non-combat schedule/service obligation исполняется через LimboAI/action contract; priority interrupt, target loss, action failure и resumption доказаны fixtures. Простой authored schedule не проходит через planner. GOAP не требуется для DONE.

Future GOAP разрешается отдельной задачей только при доказанной альтернативной multi-step цели, существенно неудобной для schedule/subtree, с bounded search/observability/cancellation gate. Здесь не создавать пустые planner APIs «на будущее».

## Validation

Goal/priority/cancellation deterministic fixtures + NPC smoke. Time/seed foundation берётся из 47. GOAP tests отсутствуют, пока feature отложена.
