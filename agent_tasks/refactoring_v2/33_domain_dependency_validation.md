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

Validator вводится **до** 29–32: transition mode проверяет migrated owners и запрещает новые нарушения. Каждый legacy exemption имеет owner/removal task; после 32 strict rerun обязателен с пустой migration baseline. Shared не зависит от domains; global composition связывает public APIs без gameplay ownership. Runtime import cycles запрещены и для public APIs; разрешённый symbol не разрешает любое source→target ребро. Asset graph отдельно, не exemption runtime graph. Конкретные NPC↔Customer, domain↔Persistence, Dialogue→Quest/Commerce cycles разрываются owning adapter/composition responsibility, не public wrappers.

## Acceptance

- прямой запрещённый импорт внутреннего файла другого domain даёт FAIL;
- public contract path проходит;
- dependency map документирован;
- validator входит в общую structure validation.

## Validation

Validator fixtures: allowed/forbidden path и class_name reference, comments/strings without false symbol edge, shared→domain, public symbol on forbidden edge, unknown target, public import cycle и expired exemption. Each transition exemption names exact legacy edge/symbol, owner/removal task and must disappear by that owner's DONE; zero after 32. Transition structure при создании; strict structure/dependency rerun после 32. Regex guard не доказывает write semantics; ownership and behavior tests remain required.
