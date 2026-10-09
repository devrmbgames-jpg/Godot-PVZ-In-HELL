# Refactoring v2.31 — vertical domains: world gameplay

Status: **DONE**

Зависимости: [30_domain_interaction_combat_motion.md](30_domain_interaction_combat_motion.md), соответствующие execution-refactor задачи завершены в 27.

## Goal

Перенести оставшиеся крупные gameplay owners в vertical domains.

## Scope

Как минимум:

```text
content/domains/packages/
content/domains/commerce/
content/domains/quests/
content/domains/challenges/
content/domains/hazards/
content/domains/time/
content/domains/persistence/
content/domains/inventory/
content/domains/needs/
```

Inventory может быть объединён с commerce только если ownership действительно единый; не объединять домены ради уменьшения числа папок.

Baseline разделяет inventory и commerce по state/transaction ownership; Hunger — needs, population/schedule уже перемещены в npc задачей 29. Отступление требует concrete inventory evidence и обновления dependency map в этом task, не wholesale redesign roadmap.

## Acceptance

Migration map этих domain закрыт; старые wrappers/aliases удалены; resource paths и save-visible contracts сохранены или мигрированы явно.

## Validation

Профильные tests + save/restore smoke при затрагивании persistence + structure validator.

## Result

All **489 task-31 map entries** moved to their complete owners, including native script/resource UIDs and GameSessionService global composition. All incoming static paths, six dynamic constructors, tests/tooling discovery and current-format save paths were updated; no mapped legacy source or missing target remains.

Resolved all nine task-31 dependency exemptions before the move. E_ReceivingZoneBody owns receiving/truck authoring; the existing E_ReceivingZone preserves its inherited exports and sign presentation. Terminal native requests, Commerce panel-open and Night panel-cleanup requests are handled by actual global composition. Time asks the configured Night workflow through a typed requirement instead of importing C_Autosave; S_NightSave owns its higher loot scheduling dependency. Existing authored scene names, exports, components and physical ownership are preserved.

Current save schema **7** rejects incompatible old saves without migration or overwrite. Native golden capture/roundtrip and manifest paths updated. Pure Shared GameplayResourcePaths classifies approved entity/definition roles; duplicate persistence classifiers and obsolete loot/quest/debug prefixes removed. Its temporary legacy definition support expires in task 32. The gaze fixture configures its actual authored C_CustomerAgent.

Cold-load diagnostics exposed a real PhysicalSlotService → ItemAccessService → DEF_WornItemAccess → PhysicalSlotService dependency: matching ID/tags belongs pure ItemAccessRules. Moved that operation and all callers, removed the former method, updated exact public permissions/map and preserved native UID. Both isolated fixture loading and actual hazards shutdown are now clean; no diagnostic waiver or compatibility wrapper was added.

## Validation

Executed 2026-10-09:

- Complete mapped owner coverage: **489/489**, zero missing targets/parallel legacy sources; native UID map PASS.
- Godot final changed-file parser: **275 files PASS**, zero errors/warnings (`refactoring_v2_31_final_parser.log`).
- Final GUT owner profile, including native save baseline and affected access/physical slots/grab: **485/485 tests, 4173 assertions**, zero runtime errors/warnings (`refactoring_v2_31_final_gut.log`). Actual updated native golden capture/roundtrip also passed separately **3/3, 274 assertions**.
- Strict architecture, transition domain/dependency/map, project structure, preflight and persistence baseline validators: PASS. Domain tooling fixtures **31/31**, persistence fixtures **5/5**.
- Actual headless main write/fresh restore: **PASS** (`vertical_slice-20261009-064040167.log`).
- Actual hazards smoke and shutdown: **PASS** (`hazards-20261009-063815819.log`).
- Actual safe loot write/fresh restore: **PASS** (`safe_loot_placement-write-20261009-064049309.log`, `safe_loot_placement-restore-20261009-064058440.log`).

No rendered gameplay or subjective visual QA. No old-save migration. Unrelated AGENTS.md/addons/gecs changes preserved.

## Current / Next

**DONE — PASS.** Continue [32 — Shared core and horizontal-root removal](32_domain_shared_core.md), then strict dependency rerun without migration baseline. Only three Shared-to-domain task-32 exemptions remain. Continue Phase 2C in README dependency order; final authorized stop remains PASS 49, before Phase 3.
