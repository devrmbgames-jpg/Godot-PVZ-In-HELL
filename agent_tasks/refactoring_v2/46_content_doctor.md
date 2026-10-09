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

Implementation complete; immutable architecture/style review remains REVIEW_PENDING.
Content Doctor aggregates existing pure compiler/identity/Smart Object/Quest providers,
checks detached native scenes and resources, explicit NPC/address factory inputs, exported
paths/types/ranges, district schedules/place graphs and locomotion/attack animations.
Imported Dialogue Manager cues/tags/links/ctx method arity are inspected without evaluation;
unknown integrations/dynamic expressions retain an explicit REVIEW_REQUIRED gate.
Unused Template declarations share the runtime compiler's extracted identity provider.

CLI: `python -B utils/validate_content_doctor.py`.
Major gate: `python -B utils/validate_project_structure.py --content-doctor`.
Usage and diagnostic contracts: [Content Doctor](../../docs/content_doctor.md).

Current evidence:
- PASS: 75 tests / 432 assertions across Doctor, Entity compiler, native preview and Smart
  Object regressions (`tests/artifacts/refactoring_v2_46_regression.log`).
- PASS: final expanded Doctor fixtures, 18 tests / 89 assertions
  (`tests/artifacts/refactoring_v2_46_final_gut.log`).
- PASS: diagnostic driver, five tests; live errors/Node retention remain blocking and only
  specified shutdown retention may be deferred with preserved console evidence.
- PASS: full integrated structure/content scan, 90 scenes / three dialogues, zero content
  errors or unresolved review gates; native report `.artifacts/content_doctor.json` and
  console `tests/artifacts/content_doctor.log` (final acceptance log retained separately).
- PASS: scoped formatter and incremental/strict architecture/static structure checks.
- PASS: changed-script parser, eight files / zero failures
  (`tests/artifacts/refactoring_v2_46_parser.log`). Immutable review remains pending.

Task42 still OWNER_QA_PENDING; no rendered/editor QA approval has arrived.
Next after review: archive46 and implement48 selected-Entity read-only debugger. Owner
editor QA required by42/48 is not replaced by this detached scan.
