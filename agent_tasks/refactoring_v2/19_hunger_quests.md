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
- существующая DEF_RefusalQuest выбирается через authored issuer/owner configuration вместо единственного hardcoded preload; сохранить текущую механику и default values, мигрировать all callers;
- два reward/deadline/dialogue variants используют один executor; новый objective/effect kind требует новой механики, generic Quest DSL здесь не вводить;
- quest instance/operation IDs и consumed outcomes/reward ledger не дублируются в Dialogue.

## Acceptance

Нет `HungerService.tick` и `RefusalQuestService.tick`.
Оставшиеся Service API называются по выполняемой операции.
Quest Definition author-selectable; repeated offer/accept/result/reload не удваивают награду. Invalid target/definition/content ID ловится provider при authored setup; variant не требует script edit.

## Validation

Hunger + refusal quest + wallet regression tests, parser.
