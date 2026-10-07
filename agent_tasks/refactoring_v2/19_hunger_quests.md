# Refactoring v2.19 — Hunger и Quests

Status: **PLANNED**

Зависимости: [18_challenges.md](18_challenges.md), [13_customer_outcomes.md](13_customer_outcomes.md).

## Goal

Исправить два небольших, но показательных shell patterns и установить эталон для простых ECS миграций.

## Hunger

- `S_Hunger` владеет query и regular progression;
- pure tier/multiplier/growth расчёты вынести/оставить как `HungerRules` либо узкий Service без tick;
- текущая phase/alive/paused семантика сохраняется.

## Quests

- `S_RefusalQuest` владеет deadline/outcome progression;
- accept/ignore/offer/lookup/payment transaction остаются explicit operations;
- event-driven resolution использовать там, где это уменьшает polling без усложнения.

## Acceptance

Нет `HungerService.tick` и `RefusalQuestService.tick`.
Оставшиеся Service API называются по выполняемой операции.

## Validation

Hunger + refusal quest + wallet regression tests, parser.
