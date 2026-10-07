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

Validator вводится **до** 29–32: transition mode проверяет migrated owners и запрещает новые нарушения. Каждый legacy exemption имеет owner/removal task; после 32 strict rerun пустая baseline. Shared does not import domains; domains do not import global UI/composition or persistence. Actual file/symbol behavioral implementation cycles fail, including public API cycles. Coarse reciprocal domain edges through declared leaf data/read/query/fact contracts can pass when actual implementation graph acyclic and writer ownership one-way; no blanket coarse DAG/no wrapper tax. Public symbol alone does not authorize an edge. Asset graph separate. NPC↔Customer and Dialogue cycles resolve existing responsibility, not forwarding APIs.

## Acceptance

- прямой запрещённый импорт внутреннего файла другого domain даёт FAIL;
- public contract path проходит;
- dependency map документирован;
- validator входит в общую structure validation.

## Validation

Validator fixtures: allowed/forbidden path/class_name, comments/strings false-positive, shared→domain, domain→global UI, public symbol on forbidden edge, unknown target, actual public implementation cycle, valid reciprocal coarse leaf-contract references and expired exemption. Exemption names exact legacy edge/symbol, owner/removal task; removed by owner's DONE, zero after 32. Transition structure now, strict rerun after 32. Static guard does not prove method semantics/write authority; ownership review and behavior tests required.
