# Refactoring v2.00.04 — migration, persistence и validation audit

Status: **PLANNED**

Зависимости: [00_03_simplification_reference_audit.md](00_03_simplification_reference_audit.md).

Рекомендуемый reasoning: **xhigh**.

## Goal

Проверить, что отшлифованную target architecture реально можно внедрить без опасных half-migrations, потери save identity, сломанных resource paths и необнаруживаемых configuration errors.

## Migration review

Для каждого крупного перехода определить:
- start state;
- target state;
- migration sequence;
- временный adapter, если действительно нужен;
- точку удаления adapter;
- автоматический gate, доказывающий завершение;
- rollback/coherent commit boundary.

Особенно проверить:
- Service → System/Observer ownership;
- horizontal roots → vertical domains;
- direct cross-domain calls → explicit contracts;
- manual composition → Templates/Traits;
- existing interaction → Smart Objects;
- current NPC logic → Schedule/Utility/GOAP/LimboAI;
- physical-only NPC → Simulation LOD.

## Persistence review

Проверить влияние на:
- stable IDs;
- Relationships;
- scene/resource paths;
- Entity Templates;
- Traits;
- SpawnContext;
- schedules;
- GOAP state;
- Smart Object reservations;
- Simulation LOD;
- save schema/version migration.

Отдельно решить для каждого transient слоя:

> Это действительно нужно сохранять, или безопаснее реконструировать после load?

Не сериализовать transient runtime state только потому, что он существует.

## Validation matrix

Убедиться, что дешёвая автоматика покрывает:
- Service/System smells;
- canonical domain layout;
- forbidden domain dependencies;
- broken `res://` paths;
- Template/Trait requires/provides/conflicts;
- placed scene capability requirements;
- Smart Object slots/executors;
- GOAP actions/executors;
- stable ID uniqueness;
- Dialogue references;
- schedule locations;
- animation references;
- content ranges;
- strict "legacy architecture absent" gates.

Migration baseline/allowlist может существовать только временно и должен иметь task, который гарантированно его обнуляет.

## Milestone sizing

Проверить, что каждый implementation milestone:
- можно завершить за один длинный рабочий цикл;
- можно закоммитить coherent state;
- можно узко проверить;
- можно откатить отдельно;
- не требует долго жить в invalid half-state.

Слишком крупные tasks дробить; искусственно мелкие tasks, которые сами по себе оставляют опасный half-state, объединять.

## Acceptance

- у каждого архитектурного перехода есть безопасная migration sequence;
- persistence/save implications учтены до изменения соответствующих contracts;
- каждый temporary compatibility mechanism имеет точку удаления;
- validators/acceptance gates способны доказать отсутствие legacy state;
- размеры milestones реалистичны.

## Validation

Planning + validator tests only. Gameplay/runtime refactor запрещён.
