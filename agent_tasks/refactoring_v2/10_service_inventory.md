# Refactoring v2.10 — полный inventory сервисного слоя

Status: **DONE**

Зависимости: Phase 1 (01–04) полностью завершена, включая [04_identity_persistence_contract.md](04_identity_persistence_contract.md).

## Goal

Перед перемещением runtime-кода классифицировать каждый project-owned файл под `content/services/**`, чтобы полный рефакторинг не превратился в выборочную чистку только самых заметных мест.

## Classification

Каждый файл получает один итоговый статус:

- **KEEP_SERVICE** — явная синхронная domain operation/transaction/lookup/factory;
- **KEEP_SOLVER / RULES / GEOMETRY / PRESENTATION** — роль корректна, при необходимости rename/move;
- **MOVE_SYSTEM** — scheduled/time-based behavior;
- **MOVE_OBSERVER** — дискретный event/lifecycle transition;
- **SPLIT** — файл смешивает несколько ownership roles;
- **RENAME_MOVE** — поведение допустимо, но имя/каталог вводит в заблуждение;
- **DELETE_MERGE** — wrapper/duplicate после миграции больше не нужен.

## Required initial suspects

Обязательно отдельно проверить известные hidden scheduler paths:
`CustomerFlowService.tick`, `NpcBrainService.tick`, `NpcRouteService.tick`,
`DistrictScheduleService.tick`, `NpcAttackService.tick`, `ProjectileService.tick`,
`CustomerCombatService.tick`, `ChallengeService.tick`, `HungerService.tick`,
`RefusalQuestService.tick`, customer arrival/greeting/inspection ticks,
`ProlongedInteractionService.tick`, а также generic update/process methods в Services.

## Output

Заполнить таблицу прямо в этом файле либо создать рядом `service_inventory_result.md`.
Для каждого non-KEEP случая указать:
- текущий владелец;
- проблема ownership;
- целевой владелец/роль;
- задача Phase 2, которая исправляет его;
- риски/тестовая поверхность.

Перед migration каждого назначенного item указать bounded coherent slice: полный owned responsibility + all callers, adapter/removal condition, точный existing regression и before/after scheduler ordering. Большой смешанный файл не делает весь Service ownership одной задачей. Слишком большой scope дробится до начала edits; DONE owning task требует closure всех её slices. Baseline infrastructure failures задачи 03 должны быть устранены.

## Acceptance

- Классифицированы 100% `content/services/**/*.gd`.
- Ни один файл не оставлен как «потом посмотрим» без владельца задачи.
- KEEP не означает «не читать»: причина роли должна быть понятна.
- Phase 2 roadmap скорректирован, если inventory нашёл пропущенную самостоятельную подсистему.

## Validation

Только static audit. Runtime не менять и тесты не запускать.

## Current — 2026-10-08

Полный результат: [service_inventory_result.md](service_inventory_result.md). Классифицированы все 136 project-owned `.gd` (18 199 строк): 55 KEEP_SERVICE, 14 KEEP_RULES, 13 KEEP_PRESENTATION, 13 KEEP_SOLVER, 4 KEEP_GEOMETRY, 30 SPLIT, 6 RENAME_MOVE, 1 MOVE_SYSTEM. Для каждого файла указаны причина и owning task; для 37 non-KEEP файлов — текущие runtime callers, целевые роли и bounded migration slices с regression/ordering/removal gates. KEEP означает завершённую классификацию, а не освобождение от owning-task validation и последующей domain relocation.

40 получает пять boundary slices (Damage, Commerce, Interaction, Customer outcomes, Quests), включая reason/status/correlation trace и reentrancy/structural-flush fixtures. 11–25 получают полные responsibility slices; CustomerFlow 11/12/13 и NPC 15/16 явно разделены. Семантический scope шире lexical baseline: strike/stability/floor/loot/perception/role/cart/input paths перечислены отдельно. Новая самостоятельная подсистема не обнаружена; roadmap сохраняет dependency order, назначенные дополнительные случаи закрываются существующими owning tasks.

## Validation result

- Static coverage audit: PASS, 136/136 unique source paths, ровно одно решение/owner на файл; ни одного необъяснённого KEEP или неназначенного non-KEEP.
- Static regression-path audit и roadmap links/dependencies/encoding: PASS.
- Owned documentation whitespace check: PASS.
- Runtime-код не менялся; parser, GUT, smoke и gameplay не запускались в этой задаче.

## Next

[40_typed_commands_events.md](40_typed_commands_events.md), все пять boundary slices до scheduler migration 11.
