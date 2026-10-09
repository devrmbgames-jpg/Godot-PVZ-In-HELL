# Refactoring v2.42 — visual Entity authoring в Godot Editor

Status: **IN_PROGRESS**

Зависимости: [41_entity_templates_traits.md](../completed/refactoring_v2/41_entity_templates_traits.md).

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
- factory принимает existing Definition/level-selected PackedScene и читает Template из instance, без default_scene в Template;
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

Authored identity использует read-only stable ID + explicit create/repair command; resource ID и instance ID показаны отдельно. Inspector показывает источник scene-owned vs Template-owned fields и не предлагает два editable providers одного параметра. Два NPC/Trader/combat variants и новый level с reused assets имеют documented create/duplicate/configure/validate workflow с количеством ручных мест; runtime preview не запускает gameplay. Scene→Template→Scene dependency fixture FAIL.

## Validation

Editor/tool tests где возможно + owner visual QA.

## Current / Next

Active Goal authorizes tasks 42–66 in dependency order. Task 41 is DONE.
Implementation is complete; **REVIEW_PENDING** against a committed immutable checkpoint.
Baseline: `dc7e9490e59510fefa820793874ae117fbb07d01`.
Project-owned Inspector installs once per editor session using an idempotent EditorScript;
addons and project plugin settings are unchanged. Simple mode opens the single authoring
Resource; Advanced explains providers/fields/Relationships. IDs use native Undo/Redo.
Current external authored Resource values are copied into a disposable scene snapshot,
retaining original provenance and external Script/scene refs. The task-41 compiler runs
only on detached actors after autoload registration; no ECS registration or ready callback.
Named endpoints, native dependency cycles and whole-level identity use existing providers.
Review checkpoint: `1b194028c3c67811aa3a62fb45fed1cbc66fa29a`; two P2 findings accepted.
RV-001: FIXED in pending repair checkpoint. Non-Entity edited roots now have a read-only
Level ID panel and explicit repair; native root suppression/repair/undo/redo check PASS.
RV-002: FIXED in pending repair checkpoint. Per-field sources and embedded diagnostic
sources map back to authored Traits; real native capture/save/reload regression PASS.
Next: bounded re-review of these fixes, archive 42 and continue 43.

## Automated evidence

- Formatter/lint: **PASS**, 8 changed/new scripts; parser **PASS**, 8 checked / 0 failed.
- GUT: **PASS**, 10/10 tests, 66 assertions; includes native physical actor structure,
  duplicate/missing level identity, binding/requirement/provider conflicts, native asset
  cycle rejection, unsaved external Template capture without overwriting its asset,
  and original per-field Trait provenance after native snapshot serialization/reload.
- Actual detached preview: **PASS**, main level 57 actors and reused fixture 4 actors.
- Strict architecture/structure/domain: **PASS**; tooling/dependency fixtures 32/32 **PASS**.
- Review-fix parser: **PASS**, 4 checked / 0 failed; incremental formatter/static gates PASS.
- Native headless editor operations: install/idempotence/ID/undo/redo markers **PASS**;
  non-Entity level root handling/read-only suppression and Level ID undo/redo **PASS**.
  Project settings SHA-256 unchanged. Full custom-editor process is **NOT_CLEAN** on shutdown:
  its 44 detached-node path errors and five RID categories are byte-category/count equal
  to the same harness with `-- --baseline` (no installation); no pre-marker errors.
  This inherited harness shutdown diagnostic is not reported as a clean editor/visual PASS.
  Raw logs: `tests/artifacts/refactoring_v2_42_review_editor{,_baseline}.log`.
  The opened-level repair harness matches its opened-level baseline (including 14 textures).
  Focused regression/parser: `tests/artifacts/refactoring_v2_42_review_{gut,parser}.log`.
- Workflow: [Entity authoring](../../docs/entity_authoring.md); subjective Inspector/visual
  checks remain [owner QA](../../qa_tasks/refactoring_v2.md), with no rendered test run.

Cleanup completed 2026-10-10: 848 unreferenced logs, four reproducible snapshot archives,
six temporary indexes/path lists and eight superseded Windows QA builds removed;
3,542,982,970 bytes released. Both launcher-selected builds, tracked fixtures/resources,
referenced acceptance evidence and memory/shutdown diagnostics retained.
Exact local inventory: `.artifacts/cleanup_20261010.json` (ignored).
Existing authored resources, menu, project config and GECS worktree edits remain preserved.
