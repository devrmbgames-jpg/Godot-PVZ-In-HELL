# Refactoring v2.41 — Entity Templates / Traits runtime composition

Status: **PLANNED**

Зависимости: strict domains и authoritative ECS contracts.

## Goal

Добавить authoring/compiler слой, позволяющий собирать Entity capabilities из Traits без нового runtime scheduler.

## Required types

Как минимум:
- `EntityTrait`;
- `DEF_EntityTemplate`;
- `EntityBuildPlan`;
- `EntitySpawnContext`;
- `EntityTemplateCompiler`;
- `EntityFactory`.

## Invariants

- Trait immutable/config only;
- Trait не тикает;
- Trait не хранит mutable runtime state;
- runtime Components создаются отдельными экземплярами;
- Systems не знают, каким Trait создан Component;
- Trait может require/provide capability и initial Relationship binding;
- same template + definitions + spawn context → deterministic composition;
- current `DEF_NpcTrait` gameplay quirks не смешивать с authoring `ET_*`.

## Acceptance

Собрать минимум несколько representative templates: physical NPC, resident/trader NPC и physical interactable object.
Compile-time validation ловит duplicate/incompatible providers и missing requirements.

## Validation

Template compiler tests + parser + representative spawn smoke.
