# Refactoring v2.42 — visual Entity authoring в Godot Editor

Status: **PLANNED**

Зависимости: [41_entity_templates_traits.md](41_entity_templates_traits.md).

## Goal

Traits не должны ухудшить основной workflow: дизайнер ставит реального NPC/объект на сцену и сразу видит его.

## Contract

Scene отвечает за физическое/визуальное устройство.
Template/Traits — gameplay capabilities.
Profile/Definitions — content/tuning.
Placed instance — concrete bindings/context.

Placed и runtime-spawned Entity после materialization используют один runtime contract.

## Work

- поддержать Template на placed Entity;
- optional `default_scene` для runtime factory;
- preview resolved Traits/Components/bindings;
- editor validation missing requirements;
- Simple Inspector mode для дизайнера;
- Advanced diagnostics для программиста;
- `@tool` preview допускается только для presentation/markers;
- editor preview не запускает ECS simulation/GOAP/gameplay Systems.

- Simple Inspector: Template/Profile, instance stable ID, named Home/Workplace bindings; Advanced: resolved recipes/provider provenance и conflict diagnostics.
- Scene-contained Template разрешён; отдельный Resource не обязателен для one-off object. Profile tuning не дублируется в каждом Trait.
- Duplicated instance и imported district получают stable-ID uniqueness validation; repair — явная editor operation, не автоматическая gameplay mutation preview.
- Inspector и headless validation используют provider задачи 41; не создавать два набора rules.

## Acceptance

NPC и существующий interactable можно поставить руками на сцену, видеть mesh/collision/markers и до запуска получить validation Template/bindings. Smart Object-specific Inspector validation добавляется в 43, когда его runtime contract уже существует.

## Validation

Editor/tool tests где возможно + owner visual QA.
