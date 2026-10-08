# Refactoring v2.26 — очистка execution graph

Status: **PLANNED**

Зависимости: [25_persistence_remaining.md](25_persistence_remaining.md), все execution tasks 11–24 завершены. Foundation 40 уже завершена до 11; поздние layout/core tasks 28–33 и 41–49 не являются prerequisites этого checkpoint.

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

Task 24 regression confirmed a concrete queued-lifetime trap: binding a Node/Entity directly to a typed Callable argument raises an engine type error if that Node is freed before flush, before any is_instance_valid guard inside the callback can run. Inventory death completion now captures WeakRef and resolves its typed Entity inside the callback. Audit the migrated queued System/Observer callbacks for the same actual freed-owner case (not only disabled/component-replaced cases), and close relevant lifetime paths with safe captured references and regression coverage before checkpoint 27. Resource Component identity guards remain necessary after resolving the owner. This is a validation/ownership issue, not an old-save migration or gameplay choice.

## Acceptance

Architecture validator имеет пустой migration baseline либо только документированные engine-bound исключения.
Execution order можно восстановить по Systems/Observers без чтения service graph.

## Validation

Structural architecture validator + parser всех изменённых files + targeted dependency/order tests.
