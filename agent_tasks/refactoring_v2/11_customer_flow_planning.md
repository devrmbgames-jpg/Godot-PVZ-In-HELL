# Refactoring v2.11 — CustomerFlow: planning, arrival и day transitions

Status: **PLANNED**

Зависимости: [10_service_inventory.md](10_service_inventory.md).

## Goal

Убрать из `CustomerFlowService.tick()` planning/day-transition/arrival orchestration и сделать соответствующий execution ownership видимым в ECS graph.

## Scope

Разобрать как минимум:
- arrival cooldown progression;
- `plan_day`;
- package history synchronization;
- morning-only missed registration;
- due followup reactivation;
- `actionable_remaining`;
- `spawn_next_due`.

Дискретные действия, которые должны выполняться один раз на переход фазы/дня, предпочитать Observer/event path вместо polling каждый frame.

## Preserve

- стабильные visit/package/history IDs;
- registration eligibility;
- district vs isolated-scene behavior;
- arrival cooldown semantics;
- CommandBuffer/GECS safety.

## Target shape

`S_CustomerFlow` или несколько узких Systems владеют регулярным scheduling/query.
Morning/day transitions принадлежат отдельному Observer/transition path.
`CustomerFlowService` сохраняет только явные reusable commands/lookups, которым действительно нужен service boundary.

## Acceptance

- planning/arrival graph виден по Systems/Observers и deps;
- отсутствует morning logic, проверяемая каждый обычный frame без причины;
- `CustomerFlowService.tick()` больше не является владельцем этого lifecycle.

## Validation

Parser changed files + профильные customer timing/flow tests. Не запускать весь проект.
