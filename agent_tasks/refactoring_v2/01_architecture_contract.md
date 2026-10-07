# Refactoring v2.01 — архитектурные роли и ownership

Status: **PLANNED**

Зависимости: нет.

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
