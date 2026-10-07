# Refactoring v2.46 — Content Doctor

Status: **PLANNED**

Зависимости: [45_simulation_lod.md](45_simulation_lod.md), Templates, Smart Objects и AI contracts стабилизированы.

## Goal

Ловить content errors headless до запуска уровня.

## Checks

Как минимум:
- valid Entity Template;
- compatible Traits;
- required Components/bindings;
- stable ID uniqueness;
- referenced Dialogue;
- Smart Object executor/slot;
- existing action executor; GOAP-specific check только если optional planner введён отдельной задачей;
- schedule locations;
- animation names;
- Definition ranges;
- resource paths;
- required scene capabilities.

## Acceptance

Content Doctor имеет быстрый CLI mode и вызывается крупной structural validation.
Representative broken fixtures дают понятные ошибки с resource/path context.

Эта задача агрегирует validation providers, созданные в 41–45 вместе с соответствующим contract. Missing requirements, bindings, executor и ID errors обязаны ловиться уже в owning milestone; нельзя откладывать первую проверку до 46.

## Validation

Fixture tests + полный content scan.
