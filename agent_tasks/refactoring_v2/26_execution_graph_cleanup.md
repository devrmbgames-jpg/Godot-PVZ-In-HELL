# Refactoring v2.26 — очистка execution graph

Status: **PLANNED**

Зависимости: все доменные migration tasks Phase 2 завершены.

## Goal

Сделать финальный статический проход по execution model и удалить остаточные wrappers/aliases, появившиеся во время миграции.

## Work

- найти project-owned `Service.tick/update/process`;
- найти Systems, чей process только делегирует generic service method;
- найти broad ECS queries внутри remaining scheduled service paths;
- проверить `deps()` после появления новых Systems;
- удалить orphan wrapper methods/files;
- проверить class_name/path naming;
- проверить, что System не вызывает System;
- проверить observers/events на циклы и дублированные transitions;
- обновить `content/ARCHITECTURE.md` только если итоговая реализация уточнила контракт.

## Acceptance

Architecture validator имеет пустой migration baseline либо только документированные engine-bound исключения.
Execution order можно восстановить по Systems/Observers без чтения service graph.

## Validation

Structural architecture validator + parser всех изменённых files + targeted dependency/order tests.
