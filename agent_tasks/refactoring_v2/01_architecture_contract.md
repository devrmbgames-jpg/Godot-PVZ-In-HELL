# Refactoring v2.01 — архитектурные роли и ownership

Status: **DONE**

Зависимости: [00_05_preflight_readiness_gate.md](00_05_preflight_readiness_gate.md) должен завершиться результатом `READY_FOR_IMPLEMENTATION`.

## Goal

Закрепить один проектный архитектурный словарь до изменения runtime-кода, чтобы последующий рефакторинг не зависел от вкуса отдельного агента.

Полная target architecture зафиксирована в [`docs/project_core_architecture_proposal.md`](../../docs/project_core_architecture_proposal.md). Эта задача должна превратить её ключевые invariants в короткие canonical rules.

## Scope

Обновить долговечные архитектурные документы и agent rules. Runtime-код не рефакторить.

Зафиксировать:

- `C_*` — intrinsic/config/runtime state или явно документированный derived cache;
- `R_*` — authoritative live Entity-to-Entity binding;
- `S_*` — scheduled GECS behavior: query, iteration, temporal progression и ordering;
- `O_*` — discrete/reactive lifecycle/event transitions;
- `*Service` — явная синхронная domain-операция/transaction/lookup/factory boundary, но не регулярный scheduler;
- `*Rules` / `*Calculation` — преимущественно чистые правила и вычисления;
- `*Geometry` — пространственные вычисления/queries без ownership игрового lifecycle;
- `*Solver` — изолированный алгоритм, включая engine-bound physics callback;
- `*Presentation` — визуальное/UI представление без gameplay authority;
- `*Factory` — создание/конструирование без владения регулярным lifecycle;
- UI — обычный Godot glue, не ECS;
- `ET_*` Traits / Entity Templates — authoring/compiler layer, не runtime state/scheduler;
- vertical domains — целевой owner layout после execution-model cleanup;
- typed Commands/Requests — intent, Events/Results — authoritative outcome.

## Required decisions

- Код может быть крупным внутри System, если он представляет одну coherent scheduled responsibility.
- Нельзя выносить scheduled код в Service только ради уменьшения размера System.
- Если System становится слишком широким — делить на несколько Systems с явным `deps()`, а не на скрытые сервисные ticks.
- Service может вызывать другой узкий Service/Rules helper как часть одной синхронной операции, но не создавать неявный scheduler graph.
- Engine callback ownership имеет приоритет над ECS scheduling: код, который обязан исполняться внутри `_integrate_forces`, остаётся solver/entity glue.
- Архитектурные роли важнее суффикса имени: при обнаружении неверно названного класса планировать rename/move, а не оправдывать роль именем.

## Files expected

- `content/ARCHITECTURE.md`
- `.agents/skills/gecs-v8/SKILL.md`
- при необходимости короткая ссылка/инвариант в `AGENTS.md`

Не дублировать подробный контракт одновременно во всех трёх местах.

## Acceptance

- Для каждого типа класса существует однозначный ownership contract.
- Есть правило выбора между System и Service на примере scheduled tick.
- Есть отдельное исключение для physics/engine-bound solvers.
- Существующие правила «System не вызывает другой System» и Components/Relationships не ослаблены.
- Зафиксировано правило scene-first authoring: Traits не заменяют видимый placed NPC/object в Godot Editor.
- Зафиксирован full-refactor invariant: выбранный migration scope не закрывается с permanent dual architecture.

## Validation

Documentation-only: проверить ссылки, `git diff --check` и отсутствие противоречий между `AGENTS.md`, architecture doc и GECS skill. Godot/GUT не запускать.

## Current — 2026-10-07

Canonical role/ownership contract закреплён в [content/ARCHITECTURE.md](../../content/ARCHITECTURE.md#canonical-roles-and-ownership). Таблица различает C/R, scheduled S, reactive O, synchronous Service, Rules/Calculation, Geometry, Solver, Presentation, Factory, Entity glue, Definitions, UI, Traits/Templates и typed intent/outcome.

Правило выбора execution owner содержит конкретный cooldown/query/delta пример: полный recurring шаг остаётся в System, размер файла сам по себе не оправдывает Service.tick. Разные responsibilities/cadence делятся на Systems с deps(); System→System imperative calls запрещены. Узкие Services могут композировать synchronous operations без второго scheduler graph. Required physics callback получает отдельное исключение для независимых non-System Solvers.

Зафиксированы single-writer C/R/aggregate authority, scene-first видимые placed объекты, единый materialized runtime contract и full-refactor completion внутри объявленного scope. Подробный словарь не размножен: AGENTS и GECS skill ссылаются на canonical документ; skill сохраняет только краткие execution reminders и pinned GECS rules. Runtime-код, сцены и addon не менялись. Следующие execution-smell примеры/flush semantics принадлежат 02, static guardrails и infrastructure repair — 03, identity baseline — 04.

## Validation result

- `python utils/validate_refactoring_preflight.py`: PASS — roadmap links/dependencies/encoding.
- Локальные ссылки и anchors в изменённых contract/rule документах: PASS.
- `git diff --check`: PASS.
- Ручное сопоставление AGENTS, architecture doc, GECS skill и target proposal: роли, C/R authority, System→System запрет, physical authority, scene-first и scope completion согласованы.
- `python utils/validate_project_structure.py`: FAIL — те же 31 pre-existing diagnostics (missing smoke script reference + metadata шести R26 tasks), явно назначены 03; новых diagnostics нет.

`--require-gate` остаётся проверкой frozen Phase 0 readiness snapshot (будущие tasks PLANNED, next01); после старта implementation используется обычная проверка roadmap. Godot/GUT/parser/gameplay не запускались: этап documentation-only, project-owned GDScript не менялся. Owner QA для этого контракта не требуется.

## Next

[02_execution_ownership_rules.md](02_execution_ownership_rules.md) — следующий отдельный рабочий запрос согласно правилу README. Phase 1 целиком ещё не закрыта; runtime migration начинается только после 02–04.
