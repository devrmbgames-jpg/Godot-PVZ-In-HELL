# Refactoring v2.02 — scheduled execution и Service boundaries

Status: **DONE**

Зависимости: [01_architecture_contract.md](01_architecture_contract.md).

## Goal

Сделать критерии «Service превратился в скрытую System» достаточно конкретными, чтобы агент мог применять их одинаково по всей кодовой базе.

## Rules to закрепить

Считать architecture smell, если выполняется одно или несколько условий:

- `System.process()` почти полностью состоит из `SomeService.tick/update/process(...)`;
- Service имеет регулярный `tick/update/process`, который вызывается из System каждый frame/physics tick;
- Service внутри регулярного шага делает broad `ECS.world.query...` по сущностям, которыми должен владеть System query;
- Service владеет `delta`, cooldown/time progression, frame budget, регулярным lifecycle или ordering между подсистемами;
- Service оркестрирует несколько других services каждый кадр и тем самым создаёт второй execution graph;
- `cmd.add_custom()` используется главным образом чтобы вынести целую System в статический Service, а не для безопасной structural mutation/deferred operation;
- phase/day/state transition polling идёт каждый frame, хотя это дискретное событие и может принадлежать Observer/event path.

Не считать проблемой автоматически:

- transaction API вроде `WalletService.submit()`;
- request boundary вроде `DamageRequestService.submit()`;
- lookup/read API;
- factory/spawn command;
- Geometry/Rules/Calculation;
- physics Solver, вызываемый из обязательного Godot callback;
- explicit one-shot command, даже если он изменяет несколько Components/Relationships.

Pinned GECS events dispatch synchronously and may flush Observer commands after callback. deps() orders Systems inside coarse groups; PER_GROUP structural work is not visible to a later System in that same group merely because it declares deps. Each request boundary declares synchronous vs deferred mutation, flush point and terminal outcome timing. Publish a fact only after all fields/structural changes it describes are visible; rejected/deferred submit cannot be treated as completed. No recursive command/outcome chain without a bounded owner/test.

## Migration rule

Для каждого найденного smell выбрать одно:

1. move scheduled ownership в существующую System;
2. split в несколько Systems с `deps()`;
3. заменить polling на Observer/event;
4. оставить Service, но переименовать/сузить его до explicit operation;
5. оставить как документированное engine-bound исключение.

## Acceptance

Правила должны позволять однозначно объяснить судьбу как минимум:
- `CustomerFlowService.tick`;
- `HungerService.tick`;
- `ProjectileService.tick`;
- `NpcBrainService.tick`;
- `CharacterMotionSolver.integrate_forces`;
- `WalletService.submit`;
- `DamageRequestService.submit`.

## Validation

Documentation-only + точечный аудит примеров. Runtime-код не менять.

## Current — 2026-10-07

Canonical smells, допустимые explicit operations, пять вариантов migration и request/flush/reentrancy rules закреплены в [architecture contract](../../content/ARCHITECTURE.md#service-smells-and-request-timing). Таблица содержит все семь acceptance examples с evidence и owning tasks. Runtime-код не менялся.

Проверены прямые callers `S_CustomerFlow`, `S_Hunger`, `S_CombatProjectile`, `S_NpcDecision`, четыре Service.tick implementations, callback Solver, Wallet submit/apply и Damage submit/O_Damage. Pinned source `world.gd`, `system.gd`, `observer.gd` подтверждает synchronous dispatch, PER_CALLBACK/PER_SYSTEM/PER_GROUP/MANUAL timing. Не предполагается, что deps flush-ит structural work; Damage bool не трактуется как applied outcome.

## Validation result

- `python utils/validate_refactoring_preflight.py`: PASS.
- `git diff --check`: PASS.
- Focused source/contract audit всех семи symbols и GECS timing: PASS; это static/documentation evidence, не behavioral run.

Godot/GUT не запускались: документация и аудит без runtime edits. Owner QA не требуется.

## Next

[03_architecture_validation.md](03_architecture_validation.md) — static guardrails и устранение 31 infrastructure diagnostics.
