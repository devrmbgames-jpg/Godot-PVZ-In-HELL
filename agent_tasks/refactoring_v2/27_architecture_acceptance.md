# Refactoring v2.27 — приёмка архитектурного рефакторинга

Status: **PLANNED**

Зависимости: [26_execution_graph_cleanup.md](26_execution_graph_cleanup.md).

## Goal

Закрыть Phase 2 до начала массового Code Style pass.

## Required acceptance

- полный service inventory закрыт;
- hidden System patterns устранены;
- architecture validator PASS;
- project structure PASS;
- parser всех project-owned GDScript PASS;
- профильные GUT по изменённым подсистемам PASS;
- один связный headless smoke основного уровня/основных gameplay contracts PASS;
- save/restore smoke PASS, если persistence boundary затрагивалась;
- нет новых ошибок/предупреждений, связанных с refactor;
- behavior changes отсутствуют либо отдельно документированы как неизбежная compatibility fix.

## Review

Провести отдельный architecture review:
- ownership;
- execution ordering;
- service dependency chains;
- event loops;
- duplicate authority;
- dead wrappers;
- unnecessary abstractions.

Каждый finding получает статус FIXED / ACCEPTED_WITH_REASON / OUT_OF_SCOPE_WITH_TASK.

## Gate

Phase 3 нельзя начинать, пока Phase 2 не имеет стабильную зелёную архитектурную baseline. Иначе style pass создаст шум поверх ещё движущихся файлов.
