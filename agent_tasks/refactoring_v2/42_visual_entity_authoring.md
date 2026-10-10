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
- отдельная вкладка Entity Authoring для дизайнера, базовый Inspector не меняется;
- Advanced diagnostics для программиста;
- `@tool` preview допускается только для presentation/markers;
- editor preview не запускает ECS simulation/GOAP/gameplay Systems.

- Authoring dock: Template/Profile, instance stable ID, named Home/Workplace bindings; Advanced: resolved recipes/provider provenance и conflict diagnostics.
- UI authored in a separate editable native scene; editor plugin owns installation/selection/undo.
- Control bindings use Unique Name or typed exported references.
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
Owner QA rejected Inspector placement and found stale Level ID display; instance repair
and validation were reported working. Revised implementation/re-review are complete and
requires owner recheck; previous visual acceptance is not PASS.
Baseline: `dc7e9490e59510fefa820793874ae117fbb07d01`.
Project-owned EditorPlugin installs a separate EditorDock once per session via an idempotent
EditorScript. Its native entity_authoring_dock.tscn owns the permanent UI, with Unique Name
bindings and its own resource Inspector. Base Inspector fields/controls are unchanged;
the old EditorInspectorPlugin execution path is removed. IDs use native Undo/Redo.
Dock subscriptions track both selected actor and root property-list changes, fixing root
Level ID display across Repair/Undo/Redo without rebuilding the selected actor's Inspector.
Owner selection contract: Level ID repair is visible only when the non-Entity level root
is explicitly selected. Child objects, Entity prefab roots and an empty selection cannot
repair the parent level, including a direct handler invocation. Child views retain a
read-only Level ID. Empty editor selection no longer falls back to the level root.
Selection fix: `42b0127414f7f7ebb4ecb8176aa1e8f3cae6c46a`; native harness/manual checklist updated.
Current external authored Resource values are copied into a disposable scene snapshot,
retaining original provenance and external Script/scene refs. The task-41 compiler runs
only on detached actors after autoload registration; no ECS registration or ready callback.
Named endpoints, native dependency cycles and whole-level identity use existing providers.
Review checkpoint: `4975105e9eb6da2f1eeabaf8f0a5929a0cf26da3`; targeted re-review PASS.
RV-001: FIXED (`4975105e9eb6da2f1eeabaf8f0a5929a0cf26da3`). Non-Entity edited roots have a read-only
Level ID panel and explicit repair; native root suppression/repair/undo/redo check PASS.
RV-002: FIXED (`4975105e9eb6da2f1eeabaf8f0a5929a0cf26da3`). Per-field sources and embedded diagnostic
sources map back to authored Traits; real native capture/save/reload regression PASS.
Next: owner recheck before archiving42; **OWNER_QA_PENDING**.
The native editor harness now asserts displayed Level/Instance IDs and unchanged base
Inspector selection. No new editor/visual PASS is claimed.

Revised source:226e127409cbb9af7dc8a4bda43e98055189851e; reviewed delta repair:
9920424403941c6e6b816ffa52739968a63a5a52 and final lifetime fix
4fdf9867f50a3bee0718a783e17b26929602420e. Bounded re-review ARCHITECTURE/STYLE PASS;
reviewer VALIDATION NOT_RUN. Native editor/owner acceptance remains pending.
RV-003: FIXED(9920424403941c6e6b816ffa52739968a63a5a52). Null intrinsic recipes now
show missing_recipe diagnostics instead of dereferencing null during selection.
RV-004: FIXED(4fdf9867f50a3bee0718a783e17b26929602420e). Metadata composition changes
reconcile the weak binding/native resource Inspector; creation do/undo explicitly notifies
the actor. Nested resource navigation remains intact when composition identity is unchanged.
Real-controller root notification/selection/null recipe/metadata removal-rebind GUT PASS.
Expired weak compositions also clear detached input after delayed notifications; the
regression releases all strong references and verifies expiry before reconciliation.

## Automated evidence

- Latest selection fix: GUT **PASS18/164**,7.637s; fresh parser **PASS4/0**;
  incremental formatter/lint **PASS4**, staged validation and diff check PASS.
  Logs: tests/artifacts/refactoring_v2_42_level_selection_{gut,parser}.log.
  Native editor/visual recheck remains **OWNER_QA_PENDING**; no new visual PASS claimed.
- Revised UI: fresh parser PASS, seven scripts/zero failures, review delta three/zero and
  final lifetime delta two/zero;
  formatter across the full baseline, strict architecture, structure and staged checks PASS.
  Native-controller/layout/provider GUT PASS17/154,7.142s:
  tests/artifacts/refactoring_v2_42_48_ui_fix_gut.log.
  Content Doctor PASS92 scenes/three dialogues/zero errors and review gates,13.07s.
  The scene's authored resource host is populated by a native Inspector only when installed.
- Native Editor acceptance NOT_RUN: original-project launch conflicts with the
  open editor's LimboAI hot-reload DLL; disposable project boot fails existing GECS
  autoload/UID compilation before the harness. Both stopped; no test markers/PASS.
  Logs: tests/artifacts/refactoring_v2_42_dock_editor{,_isolated}.log.
  Dock operations require owner recheck; earlier headless results below refer to old source.
- Disposable editor project removed after verified path/process/reparse checks:720127926
  bytes. Logs retained; audit:.artifacts/cleanup_qa42_editor_project_20261010.json.

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
Exact local inventory: `.artifacts/cleanup_20261010.json` (ignored). Four generated tracked Python cache files were also removed (81,987 bytes) in8404dec6; source validator tooling88/88 PASS. Cache audit: `.artifacts/cleanup_python_cache_20261010.json`. Total cleanup:870 targets /3,543,064,957 bytes; current acceptance evidence and QA builds retained.
Existing authored resources, menu, project config and GECS worktree edits remain preserved.

## Direct Traits scope overlap

Direct Inspector authoring supersedes this task's Template/dock editing contract; see
[codex_direct_traits_inspector_tz.md](codex_direct_traits_inspector_tz.md). The persistent
Gameplay Traits plugin edits the Entity's direct export, while the retained dock handles
IDs and detached diagnostics only. Stable IDs, pure preview, native scenes and owner QA
requirements remain. This task is not marked complete without owner acceptance.
