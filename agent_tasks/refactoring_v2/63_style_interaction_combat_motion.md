# Refactoring v2.63 — Code Style: Interaction, Combat и Motion

Status: **IN_PROGRESS**

Зависимости: 62_style_npc_customers.md.

## Goal

Сделать physics-heavy код читаемым человеку без изменения его физической семантики.

## Scope

- interaction/grab/push/slot/cart;
- combat/damage;
- motion/navigation/physics solvers;
- связанные entities/glue.

Scope: оставшиеся scripts в `content/domains/{interaction,combat,motion}/` и явно назначенные shared solvers по manifest задачи 61.

## Extra focus

- ray/shape queries получают intent comments, когда используются цепочкой;
- coordinate-space и transform conversions явно разделяются;
- intermediate vectors/results типизированы и названы по роли;
- physics callback constraints документированы там, где они неочевидны;
- long expressions разбиты без изменения порядка вычисления;
- performance-sensitive hot paths не усложнять аллокациями только ради красоты.

## Acceptance

Style gate + parser PASS.
Physics ownership и ordering не изменены.

## Validation

Профильный grab/combat/physics regression только для файлов, где style cleanup потребовал не-механической перестройки.

## Current

Full manifest scope106 passes pinned formatter/linter and100 columns; changed gate86 PASS.
Source saved through native MCP; all106 path-bound compilations checked, no diagnostics.
Actual CLI parser PASS (`.artifacts/godot_agent/parsechanged-20261010-084340159` logs).
Typed motion vectors/scalars retain support-relative velocity and callback order. Named
Relationship state retains existing lifetime boundaries; anchoring query executes at the
same loop point, and openable removes the binding before event publication.
ImpactResult.Severity members use CONSTANT_CASE with numeric0–3 unchanged; all authored
callers migrated, including the mandatory callers assigned to other style tasks.
No scenes/resources/third-party addons rewritten; no rendered QA performed.

Validation PASS:17 profile GUT suites,223/223 tests,1341 assertions,25.043s; stderr empty.
Logs: `.artifacts/godot_agent/physics63_gut.{stdout,stderr}.log`.
Headless inventory and cart_transport smokes PASS:
`tests/artifacts/inventory-20261010-184505927.log`,
`tests/artifacts/cart_transport-20261010-184517042.log`.
Strict architecture/domain/dependency/structure and prior task61/62 full style PASS.

Review: REVIEW_PENDING immutable implementation checkpoint; collect/triage before DONE.
Tasks64–66 remain required.
