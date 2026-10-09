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

Flat Templates, без inheritance/override framework. BuildPlan — transient validated recipes, не второй cache/runtime registry. New Trait script нужен для новой capability; content variants используют existing Trait/Profile. Arbitrary install hooks и mutable shared state запрещены. Explicit conflict policy сохраняет scene-owned engine components. Factory получает PackedScene/context и читает Template из scene instance; Template не хранит default_scene/back-reference. Existing Profile/Definition scene selector имеет одного owner, циклические Scene→Template→Scene Resources запрещены.

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

Project-owned World/bootstrap preparation выполняется до automatic World.initialize: explicit World build context, all placed recipes, duplicate stable/Entity IDs и endpoints проверяются **до** World.add_entity (его collision policy заменяет existing Entity). Не присваивать ECS.world ради compilation: setter немедленно вызывает deferred System.setup. Сохранить pinned registration once; затем обычное связывание ECS.world, setup только passive bindings, startup domain spawns/restore, endpoint fixup и ready до первого main_level tick. World startup gate и per-Entity composition-ready запрещают gameplay reactions до завершения reconstruction. Addons не изменяются; startup hook не regular scheduler. Factory использует тот же pre-registration gate. Fixtures доказывают отсутствие ID replacement и gameplay side effects при failed build/restore.

Scene/template/profile/instance ownership и explicit override/conflict policy заданы section 10 target proposal. Nested mutable state между двумя spawn instances изолирован; Definitions shared immutable. Restore применяет saved state поверх defaults до ready и не повторяет side effects. Требуются validation/diagnostic providers вместе с capability.

Composition manifest covers every existing procedural capability installer from inventory/migration map, including NPC/customer/trader, items/interactables and package/hazard factories. Representative examples are tests, not the migration scope limit. Native declarative scene Components/pure define_components recipes remain deliberate providers of intrinsic data/engine glue, validated by the same preparation path with an optional Template; no empty Template asset is mandatory. Reusable gameplay capability wiring migrates to Traits; old on_ready/factory/install branches for that capability disappear. Each Component/Relationship is contributed once; passing a compiled recipe plus old define_components output to GECS as duplicate overrides is forbidden. Provenance fixtures cover scene+code+Trait provider conflicts and no repeated Component-added reaction.

## Acceptance

Собрать representative templates для существующих capabilities: physical NPC, resident/customer, existing Trader и physical interactable object. C_Trader/DEF_TraderProfile уже существуют; здесь capability wiring, а не новая trade mechanic. Variant не требует ET script или global registration edit.
Compile-time validation ловит duplicate/incompatible providers и missing requirements.
Manifest is 100% closed: each installer removed/migrated or retained as a documented declarative intrinsic provider with no duplicate setup path. Package/item/hazard family fixtures join NPC/interactable parity tests; remaining scene-only recipes are part of the target pipeline, not a legacy fallback.

Positive/negative fixtures доказывают placed↔spawned parity, ordering-independent deterministic recipes, duplicate provider, missing binding, two-instance nested mutation isolation, failed-registration cleanup и load без повторного setup/HP reset. Cleanup не обещает отменить уже опубликованные wallet/dialogue/outcomes: таких effects до ready быть не должно. `World.add_entity` не вызывается дважды для placed scene. Setup, synchronous Observer callbacks и Entity.on_ready входят в startup ordering fixture.

## Validation

Template compiler tests + parser + representative spawn smoke.
