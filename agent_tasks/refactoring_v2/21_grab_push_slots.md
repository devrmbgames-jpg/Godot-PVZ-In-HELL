# Refactoring v2.21 — Grab, Push, Carry и physical slots

Status: **PLANNED**

Зависимости: [20_interaction_input.md](20_interaction_input.md).

## Goal

Разделить крупные interaction services по реальным ролям и убедиться, что scheduled state progression остаётся в Systems/Observers, а imperative operations — в Services.

## Scope

- `GrabService`;
- `PushService`;
- `PhysicalSlotService`;
- anchoring/cart/carry related services;
- lifecycle Observers;
- Relationships `R_HeldBy`, `R_PushedBy` и derived caches.

## Constraints

Не ломать physics ownership и текущие Relationship authorities.
Не переносить physics callback solvers в ECS ради единообразия.

## Acceptance

Каждый крупный interaction Service имеет одну объяснимую роль.
Scheduled behavior не скрыт внутри Service.
Структурные add/remove операции используют корректный GECS lifecycle/CommandBuffer path.

## Validation

`test_s_grab.gd` и профильные cart/slot tests, parser.
