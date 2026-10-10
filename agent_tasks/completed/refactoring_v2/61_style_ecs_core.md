# Refactoring v2.61 — Code Style: ECS core

Status: **DONE**

Зависимости: [60_style_tooling.md](60_style_tooling.md).

## Goal

Привести Systems, Observers, Components, Relationships и Definitions к human-first Code Style после завершённой архитектурной миграции.

## Scope

- `content/domains/*/{systems,observers,components,relationships,definitions}/**`;
- соответствующие canonical role folders в `content/shared/`.

Сформировать explicit script manifest для 61–65: каждый project-owned `.gd` имеет один owning style task. Последующие задачи исключают уже принятые файлы. Старые horizontal roots не являются style scope и должны отсутствовать после 32.

## Focus

- narrative code;
- descriptive names;
- concrete typing;
- logical blank-line phases;
- intent comments над сложными physics/ECS/transform blocks;
- public API ## docs;
- meaningful regions;
- guard clauses;
- readable boolean rules;
- <=100 chars через естественное wrapping;
- no cosmetic architecture changes.

Не добавлять комментарии к очевидным строкам и не дробить код на бессмысленные tiny helpers.

## Acceptance

Full style gate PASS для перечисленных каталогов.
Parser PASS.
Behavior diff отсутствует.

## Validation

Formatter/linter full scope + Godot parser для затронутых scripts. Профильные tests только если ручная правка могла изменить semantics.

## Current

Task60 independently reviewed PASS at `515f54b95ff0ee3ea8cf1fdb087efbdfd1ed58a7`.
Explicit disjoint ownership: [script manifest](../../../utils/gdscript_style_manifest.json),
980 authored scripts: task61=309,62=163,63=106,64=72,65=330. Generated
`tests/artifacts` (ignored by Git and Godot) are excluded. The `--task` gate rejects
missing, duplicate and stale entries before checking the whole assigned scope.
The whole ECS role scope passes pinned0.26.2 full formatter/linter and100 columns.
Typed expression stages preserve query construction/execution order; GECS getter provides
a fresh builder per access. Regions delimit methods, deferred lifetime guards stay intact.
Hazard enum members use CONSTANT_CASE; numeric values0/1 and authored/save contracts
remain unchanged. All authored callers migrated; their final full style acceptance remains
with their manifest owner. No scenes/resources or third-party addons were rewritten.

## Validation

- PASS full `--task61`:309 scripts; changed-line gate and actual CLI parser.
- PASS native MCP path-bound compilation:309/309, checked, error_code0, no diagnostics.
  Anonymous MCP script writer can return spurious error43 for existing global classes;
  companion tool compiles real resource paths, captures diagnostics and creates no actors.
- PASS GUT18 suites:248/248 tests,2600 assertions,28.241s; stderr empty.
  Logs: `.artifacts/godot_agent/ecs61_gut.{stdout,stderr}.log`.
- PASS focused companion after JSON protocol repair:7/7 tests,17 assertions.
- PASS tooling141/141, strict architecture/domain/dependency, structure/change gates.
- Source defaults, ordering and physical authority preserved; no rendered QA performed.

PASS independent immutable review: BASE `515f54b95ff0ee3ea8cf1fdb087efbdfd1ed58a7`,
TARGET `3e5c93dcba93a730e79a632360160db50e88945a`; pinned GECS
`14d4282e5c1cb2713c187706ba2f5ff4e315d36e`. No material findings;
ARCHITECTURE/STYLE PASS, reviewer validation NOT_RUN (read-only source review).
PASS headless hazards smoke: `tests/artifacts/hazards-20261010-181107926.log`.
Acceptance complete. Continue with62; tasks62–66 remain required.
