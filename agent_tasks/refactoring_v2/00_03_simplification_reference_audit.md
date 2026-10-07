# Refactoring v2.00.03 — simplification, overengineering и reference audit

Status: **PLANNED**

Зависимости: [00_02_usability_authoring_audit.md](00_02_usability_authoring_audit.md).

Рекомендуемый reasoning: **xhigh**.

## Goal

Провести отдельный adversarial review всех новых framework/layers и убрать архитектуру, которая существует только потому, что она "правильная", модная или похожа на чужой engine.

## Core question

Для каждого крупного слоя спросить:

1. Какую реальную проблему проекта он решает?
2. Почему существующий механизм не решает её достаточно хорошо?
3. Сколько новых concepts/API/files он добавляет?
4. Сколько boilerplate потребуется на один новый content item?
5. Можно ли получить 80–90% пользы существенно проще?
6. Как это дебажить?
7. Как валидировать?
8. Кто основной пользователь: programmer, designer/editor или runtime?
9. Не появляется ли второй source of truth?
10. Насколько сложно удалить/заменить слой позже?

## Explicitly challenge

Не считать обязательными только потому, что они уже записаны:
- GOAP;
- Utility layer;
- полный Trait framework;
- Smart Objects в текущем виде;
- четыре Simulation LOD;
- конкретное разбиение domains;
- общий Commands/Events abstraction;
- Template inheritance;
- отдельные authoring/compiler classes.

Разрешено предложить более простой механизм.

## External references

Использовать Unreal Mass/Flecs/другие зрелые ECS/data-oriented systems как источник опыта, а не blueprint.

Для каждой borrowed idea проверить:

```text
Какая проблема решается в reference?
↓
Есть ли та же проблема у нас?
↓
Подходит ли решение для Godot + GECS?
↓
Можно ли реализовать проще?
↓
Как это ощущается в ежедневной работе?
```

Unreal Mass особенно релевантен как reference для:
- Entity Templates / Traits;
- processors vs observers;
- deferred structural changes;
- Simulation/Representation LOD;
- signals/event-driven work;
- Smart Object integration.

Не переносить Unreal-specific lifecycle/API/complexity без собственной причины.

## Decision format

Для каждого существенного изменения:

```text
Problem
Current proposed solution
Suggested improvement
Why it is better for this project
Complexity cost
Migration impact
Decision: ADOPT / REJECT / DEFER
```

## Freedom pass

В конце задать вопрос:

> Если бы сегодня это ядро проектировалось с нуля специально для Godot + GECS + LimboAI + Dialogue Manager и нашего workflow — сделали бы мы его именно так?

Искать возможность:
- убрать слой;
- объединить похожие механизмы;
- заменить runtime abstraction на authoring-time compilation;
- улучшить Inspector/editor tooling;
- заменить documentation-only rule дешёвым validator;
- уменьшить число mandatory Resources;
- сократить число мест, редактируемых для нового content;
- улучшить observability;
- уменьшить AI-agent context footprint.

## Acceptance

- нет известного architecture layer без конкретной project-specific причины;
- borrowed ideas имеют явную ссылку/обоснование и адаптированы под Godot/GECS;
- overengineering либо удалён, либо сознательно принят с объяснением;
- roadmap отражает принятые simplifications/improvements.

## Validation

Planning/docs/validator-only. Runtime implementation запрещён.
