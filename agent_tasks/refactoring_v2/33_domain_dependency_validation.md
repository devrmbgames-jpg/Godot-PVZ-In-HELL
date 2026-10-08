# Refactoring v2.33 — domain dependency validation

Status: **DONE**

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

## Result

`utils/validate_domain_dependencies.py` indexes actual project-owned Script paths/class_name and projected ownership from the approved migration map. It validates explicit source-owner/public target/operation rights; public declarations never grant an edge. Both direct paths and classname-only references are checked. Actual load/preload/extends and named constant loads are recognized; comments and diagnostic strings do not create imports. Alias and directly typed instance APIs reject private/unexported operations. Global panel/entry asset construction is checked separately from the general asset graph.

Implementation graph includes actual static/alias API calls, directly typed variable/parameter API calls, inheritance and behavioral script imports. Type/leaf-data/constant references are separated, so reciprocal coarse data/fact edges pass without a blanket domain DAG. Actual public implementation cycles fail. This is bounded lexical/type-reference analysis, not a compiler: nested/dynamic member dispatch, arbitrary dynamic loads and semantic field-write authority remain explicit ownership review/Content Doctor responsibilities.

`utils/domain_contracts.json` now declares static and directly typed instance public operations plus their individual read/query/request rights. Passive SAVE_FIELDS/link restore and NpcTraitService resistance configuration retain their narrowly documented access scopes. No public class exports a private method.

Frozen `utils/domain_dependency_baseline.json`: **88 exact entries** — **46 forbidden legacy edges**, **42 behavioral cycle cuts**. Removal task counts: **29: 68, 30: 7, 31: 10, 32: 3**. Each names exact stable source/owner/target symbol/path, reason and removal task. The earliest involved owner owns cycle removal, including necessary lower capability decomposition; file moves cannot hide debt. Exemptions expire when that task becomes DONE, stale/disappeared/non-cyclic edges fail, and strict mode requires an empty baseline. Default validation never writes/expands debt; capture refuses an already frozen baseline. `--prune-resolved` removes only genuinely resolved existing entries and cannot grant new access.

Transition enforcement is included in `utils/validate_project_structure.py` before the first 29–32 move. The current legacy debt is explicitly bounded, not a grant to retain it. All task 29 exemptions must disappear before NPC/Customers closes; baseline must be empty after 32.

## Validation

Executed 2026-10-08 after the final batch:

- Dependency fixtures: **18/18 PASS**. Allowed/forbidden path and classname, public contract, comments/diagnostic strings, actual constant load, shared→domain, domain→global UI/script/asset, public symbol on forbidden Persistence edge, unknown/mismatched target, static and typed-instance public API cycles, valid reciprocal leaf records, private alias/instance operations, declared method rights, exact/expired/new-edge exemptions, frozen capture and stale resolved cycle.
- Combined domain structure/map/dependency fixtures: **31/31 PASS**.
- `python utils/validate_domain_dependencies.py`: PASS transition with the exact frozen baseline.
- `python utils/validate_project_structure.py`: PASS, including dependency enforcement/map/private/resource checks.
- `python utils/validate_refactoring_preflight.py`: PASS.

No project-owned GDScript, authored runtime resource or scene behavior changed in this tooling task; parser/GUT/runtime checkpoint remains 27. No rendered gameplay/subjective visual QA or old-save migration.

## Current / Next

**DONE — PASS**, enforcement active before migration. Continue [29 — NPC/Customers](29_domain_npc_customers.md): resolve the declared hierarchy/BT/role/dialogue/implementation cycles, remove all 68 owning exemptions, move complete owners/UID/assets/references/save contracts, and run its Acceptance/Validation. Do not begin Phase 3; final authorized stop remains PASS 49.
