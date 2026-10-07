# Refactoring v2.33 — domain dependency validation

Status: **PLANNED**

Зависимости: [28_domain_layout_contract.md](28_domain_layout_contract.md).

## Goal

Не дать vertical domains снова превратиться в общую связанную массу.

## Work

Добавить статический validator допустимых dependency directions.

Проверять project-owned res:// references/imports по domain ownership. Разрешённые cross-domain зависимости должны проходить через:
- typed commands/events;
- stable public domain contracts;
- content/shared low-level contracts;
- явно документированные integration boundaries.

Не строить полноценный GDScript compiler. Проверять path-level references и project `class_name` references через symbol-to-owner index: отсутствие preload не означает отсутствие зависимости. Dynamic loads остаются явным review/content gate.

Validator вводится **до** 29–32: transition mode проверяет migrated owners и запрещает новые нарушения. Каждый legacy exemption имеет owner/removal task; после 32 strict rerun обязателен с пустой migration baseline. Shared не зависит от domain internals; global composition может связывать domains через public contracts. Authored asset references проверяются отдельно от runtime code dependencies.

## Acceptance

- прямой запрещённый импорт внутреннего файла другого domain даёт FAIL;
- public contract path проходит;
- dependency map документирован;
- validator входит в общую structure validation.

## Validation

Validator fixtures: allowed/forbidden path и class_name reference, shared→domain, public contract, unknown target, cycle и expired exemption. Transition structure при создании; strict structure/dependency rerun после 32.
