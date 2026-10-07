# Refactoring v2.41 — Entity Templates / Traits runtime composition

Status: **PLANNED**

Зависимости: [47_game_time_randomness.md](47_game_time_randomness.md), strict domains и authoritative ECS contracts.

## Goal

Добавить authoring/compiler слой, позволяющий собирать Entity capabilities из Traits без нового runtime scheduler.

## Minimal contracts

Достаточно следующих ролей; отдельная public class для каждой не обязательна:
- `EntityTrait`;
- `DEF_EntityTemplate`;
- `EntityBuildPlan`;
- typed SpawnContext contract;
- compile/validate operation;
- существующая factory boundary с Template support.

Flat Templates, без inheritance/override framework. BuildPlan — transient validated recipes, не второй cache/runtime registry. New Trait script нужен для новой capability; content variants используют existing Trait/Profile. Arbitrary install hooks и mutable shared state запрещены. Explicit conflict policy сохраняет scene-owned engine components.

## Invariants

- Trait immutable/config only;
- Trait не тикает;
- Trait не хранит mutable runtime state;
- runtime Components создаются отдельными экземплярами;
- Systems не знают, каким Trait создан Component;
- Trait может require/provide capability и initial Relationship binding;
- same template + definitions + spawn context → deterministic composition;
- current `DEF_NpcTrait` gameplay quirks не смешивать с authoring `ET_*`.

Placed и spawned composition реализуются в этой задаче через один compile/validate path. GECS `_initialize` получает подготовленные fresh recipes; ready barrier и endpoint fixup предотвращают реакцию consumers на частичную композицию. Не ждать 42 для placed runtime support: 42 добавляет Inspector/preview tooling.

Project-owned World/bootstrap preparation выполняется до automatic World.initialize: ECS.world context, all placed recipes, duplicate stable/Entity IDs и endpoints проверяются **до** World.add_entity (его collision policy заменяет existing Entity). Затем pinned registration once, endpoint fixup и ready до первого main_level tick. Addons не изменяются; startup hook не regular scheduler. Factory использует тот же pre-registration gate. Fixture с duplicate placed IDs доказывает, что existing Entity не была заменена.

Scene/template/profile/instance ownership и explicit override/conflict policy заданы section 10 target proposal. Nested mutable state между двумя spawn instances изолирован; Definitions shared immutable. Restore применяет saved state поверх defaults до ready и не повторяет side effects. Требуются validation/diagnostic providers вместе с capability.

## Acceptance

Собрать representative templates для существующих capabilities: physical NPC, resident/customer NPC и physical interactable object. Trader Template требуется только при готовой trading capability; новую механику ради demo не добавлять.
Compile-time validation ловит duplicate/incompatible providers и missing requirements.

Positive/negative fixtures доказывают placed↔spawned parity, ordering-independent deterministic recipes, duplicate provider, missing binding, two-instance nested mutation isolation, failed-registration rollback и load без повторного setup/HP reset. `World.add_entity` не вызывается дважды для placed scene.

## Validation

Template compiler tests + parser + representative spawn smoke.
