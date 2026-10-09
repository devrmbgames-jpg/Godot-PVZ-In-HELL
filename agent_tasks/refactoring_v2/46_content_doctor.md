# Refactoring v2.46 — Content Doctor

Status: **IN_PROGRESS**

Зависимости: [45_simulation_lod.md](../completed/refactoring_v2/45_simulation_lod.md), Templates, Smart Objects и AI contracts стабилизированы.

## Goal

Ловить content errors headless до запуска уровня.

## Checks

Как минимум:
- valid Entity Template;
- compatible Traits;
- required Components/bindings;
- stable ID uniqueness;
- referenced Dialogue;
- imported Dialogue cues/tags и declared ctx methods; unsupported dynamic expressions получают explicit review gate, не исполняются ради validation;
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
Quest/Trader providers появляются в 19/24, dialogue contract provider в 40. Doctor не изобретает универсальный quest/action interpreter. Resource cycle и duplicate authored-instance ID дают resource/field/instance diagnostics.

## Validation

Fixture tests + полный content scan.

## Current / Next

Task45 A-C completed; final reviewed source `3fad54aefbf7c9451eed7d2bd576825b2a071327`.
Nearest existing providers: detached EntityAuthoringPreviewRules/EntityBuildRules,
SmartObjectRules, RefusalQuestValidator and authored Definition/AI contracts.
Next: aggregate native scene/resource diagnostics in one headless CLI without running
scene gameplay or dialogue expressions. Check factory-context prefabs through their declared
inputs instead of reporting missing runtime IDs as authored content errors. Add representative
broken fixtures and integrate the full scan into structural acceptance.
Dialogue ctx methods/cues require a declared read-only contract check; no action interpreter.
Implementation, fixture tests and complete content scan: NOT_RUN.
