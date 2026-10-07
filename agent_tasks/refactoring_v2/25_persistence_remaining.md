# Refactoring v2.25 — Persistence и remaining services

Status: **PLANNED**

Зависимости: [24_economy_inventory_commerce.md](24_economy_inventory_commerce.md); задачи 10–23 завершены по последовательному execution chain.

## Goal

Закрыть весь service inventory: отдельно проверить persistence/input/UI/debug и все файлы, не попавшие в доменные задачи.

## Persistence

Codec/snapshot/store/migration helpers обычно остаются вне ECS scheduling.
Отделить serialization от gameplay authority.
Не менять save schema только ради архитектурной чистоты без отдельной необходимости.

## Remaining services

Для каждого ещё не закрытого inventory item выполнить назначенный KEEP/MOVE/SPLIT/RENAME/DELETE.
Проверить naming: класс с ролью Geometry/Rules/Solver/Presentation не обязан называться Service.

## Acceptance

100% строк service inventory имеют финальный статус **DONE/KEPT_WITH_REASON**.
Нет «временно оставленных» hidden schedulers.

## Validation

Persistence/save regression tests для затронутых файлов; parser; structural validator.
