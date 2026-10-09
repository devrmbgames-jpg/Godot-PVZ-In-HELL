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

Checkpoint `3292e5a171f33626577730ebd45a5720b15d5a55` implemented Content Doctor;
immutable review found two completeness bugs. Main reproduced both in detached native
fixtures (18/20 passed, two expected diagnostic assertions failed; no runtime errors).
Task remains IN_PROGRESS pending the targeted repair review.

Doctor aggregates existing compiler/identity/Smart Object/Quest providers, checks detached
native scenes/resources and explicit NPC/address factory inputs. Imported Dialogue cues,
tags, links and declared ctx method arity are inspected without evaluation; unsupported
expressions/integrations retain an explicit REVIEW_REQUIRED gate. Unused Template
identity declarations share the same runtime compiler provider.

CLI: `python -B utils/validate_content_doctor.py`.
Major gate: `python -B utils/validate_project_structure.py --content-doctor`.
Usage: [Content Doctor](../../docs/content_doctor.md).

## Review / Triage

Source: `3292e5a171f33626577730ebd45a5720b15d5a55`, baseline
`8f495ccb1f37f3a889a37a460b2a0036aff0149a`; STYLE PASS, ARCHITECTURE FAIL.
Reviewer validation NOT_RUN; main executed actual repro and repair checks.

- RV-001 / P1: missing or incorrectly typed district anchors escaped the scan, while
  strict runtime arrivals reject them. ACCEPTED, implemented repair: owning detached
  levels resolve every declared anchor as Node3D; coordinate-only places remain valid.
  Native HOME/PORTAL fixture demonstrates missing/type failures and valid retry.
- RV-002 / P1: placed NPC attack clips were skipped although prefab checks passed.
  ACCEPTED, implemented repair: one scene compilation path aggregates owning identity,
  NPC construction and Entity compiler providers for placed/factory actors; animation
  checks consume each actual compiled C_NpcCombat. Native valid prefab / overridden
  placed melee+ranged clip fixture demonstrates the difference without tree entry.

Repair evidence:
- PASS: Doctor/compiler/native-preview regressions, 63 tests / 374 assertions
  (`tests/artifacts/refactoring_v2_46_review_fix.log`).
- PASS: changed-script parser, two files / zero failures
  (`tests/artifacts/refactoring_v2_46_repair_parser.log`).
- PASS: integrated structure/full content scan, 90 scenes / three dialogues, zero errors
  and zero review gates, 12.15 seconds (`tests/artifacts/refactoring_v2_46_repair_acceptance.log`).
- PASS: scoped formatter, incremental and strict architecture; exact diagnostic contracts.
- PASS at checkpoint: five driver regression tests distinguish known shutdown retention
  from live/unknown errors and actual retained Nodes; console logs remain preserved.

Next: immutable repair commit, targeted re-review and triage closure before archiving46.
Task42 still OWNER_QA_PENDING; no rendered/editor QA approval has arrived. After46,
implement48 read-only selected-Entity view; owner editor QA is a separate required gate.
