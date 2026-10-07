# Refactoring v2.27 — execution-model acceptance checkpoint

Status: **PLANNED**

Зависимости: [26_execution_graph_cleanup.md](26_execution_graph_cleanup.md).

## Goal

Закрыть первую часть Phase 2: доказать, что scheduled/reactive/service ownership стабилен **до** массового vertical-domain перемещения файлов.

## Required acceptance

- полный service inventory закрыт;
- hidden System patterns устранены;
- architecture validator PASS;
- project structure PASS;
- parser всех затронутых GDScript PASS;
- профильные GUT изменённых подсистем PASS;
- один связный headless smoke основных gameplay contracts PASS;
- save/restore smoke PASS, если persistence boundary затрагивалась;
- нет новых refactor-related errors/warnings;
- временные wrappers execution-model migration удалены.

## Review

Проверить ownership, execution ordering, service chains, event loops, duplicate authority, dead wrappers и unnecessary abstractions.

Каждый finding получает FIXED / ACCEPTED_WITH_REASON / OUT_OF_SCOPE_WITH_TASK.

## Gate

Это **не** разрешение начинать Code Style.

После PASS продолжить [28 — vertical-domain layout](28_domain_layout_contract.md). Полный архитектурный gate находится в [49_core_architecture_acceptance.md](49_core_architecture_acceptance.md).
