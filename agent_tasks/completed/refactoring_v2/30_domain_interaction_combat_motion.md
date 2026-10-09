# Refactoring v2.30 — vertical domains: Interaction, Combat и Motion

Status: **DONE**

Зависимости: [29_domain_npc_customers.md](29_domain_npc_customers.md), соответствующие execution-refactor задачи завершены в 27.

## Goal

Собрать interaction/combat/motion ownership вертикально после исправления scheduling boundaries.

## Scope

```text
content/domains/interaction/
content/domains/combat/
content/domains/motion/
```

Physics engine-bound solvers остаются solver/glue, но получают понятного domain owner либо shared owner.

## Acceptance

- interaction/combat/motion не зависят от старых horizontal paths;
- Systems/Observers/Services находятся рядом со своими domain contracts;
- cross-domain взаимодействие идёт через typed contract/API, а не file-location coupling;
- no compatibility wrappers после завершения.

## Validation

Grab/input/combat/motion parser + профильные GUT + structure validator.

## Result

**DONE — PASS**, 2026-10-09. All 486 mapped Interaction/Combat/Motion files moved together (302 interaction, 134 combat, 50 motion), including scripts/.gd.uid, 29 scenes, 10 resources and 3 role/archive documents. All incoming production/test/tooling/document paths updated. Native UID identities and stable migration-source provenance preserved; zero stale runtime references and zero task-30 exemptions. Temporary source paths in validator Python fixtures remain intentional fixture data.

CombatQueries and CartCargoQueries own authoritative binding reads. GrabQueries/GrabReachQueries own base state and targeting reach reads; GrabHoldCache owns derived slot pointer writes and clears Carry modifiers. GrabReleaseService owns release and idempotent physical/input/cache cleanup; acquisition/lifecycle application remain GrabService. MarkerSessionCleanup owns transient stroke/session release independently of Package ink/physical prefab behavior. Existing public rights followed moved operations; package ink requests the actual marker cleanup owner. All old APIs removed; no forwarding wrappers or duplicate authority. Godot physics retains transform/velocity ownership, live Relationships retain ownership/selection.

Schema 6 versions migrated script/Definition/prefab paths. Closed guards admit only migrated domain roles and remaining unmoved roots. Native engine golden and save-visible codec inventory updated; incompatible versions reject without conversion or automatic slot overwrite.

Headless parser recompile now retains existing Resource instances: prior selected scene/Definition preloads may already instantiate Component scripts, making default reload fail Already in use. Native reload(true) recompiles while preserving instances in this parser process. An invalid-syntax engine negative check still fails with exit 1; the temporary invalid fixture was removed after its check.

## Validation

- Decomposition changed-script parser **139 files PASS** and targeted Grab/slots/Combat/native attack/lifetime GUT **172/172, 1095 assertions**, zero diagnostics. Initial multiline extraction defect fixed before acceptance; seven verified obsolete baseline cuts removed separately afterwards.
- Final full changed-script parser **334 files PASS**, zero errors/warnings (`refactoring_v2_30_moved_final_parser.log`). Initial preload-instance reload errors resolved by the parser tooling change, with explicit invalid-syntax negative proof (`refactoring_v2_30_parser_negative.log`, expected exit 1).
- Final profile plus Customer/NPC integration, native intent and committed current-save golden: **259/259 tests, 1934 assertions**, 15 scripts, zero runtime diagnostics (`refactoring_v2_30_moved_gut.log`).
- Native schema-6 golden generation/save-load/rejection **3/3, 274 assertions**, zero diagnostics (`refactoring_v2_30_moved_baseline_gut.log`); committed fixture reloaded in the final profile.
- Domain fixtures **31/31 PASS**. Map, transition structure/dependencies, project structure, persistence baseline, preflight and architecture `--strict`: **PASS**. Strict domain gates remain pending tasks 31–32; 12 exact later-task exceptions remain.
- Actual main-level connected vertical slice/Night save/fresh-process restore **PASS** (`vertical_slice-20261009-054122540.log`).
- Native headless import preserves known addon shutdown leak diagnostics; not claimed as a clean runtime gate. No rendered gameplay, subjective visual QA or old-save migration performed.

## Current / Next

Continue [31 — remaining world/economy/package owners](31_domain_world_economy_packages.md) in dependency order, then 32 and Phase 2C acceptance gates. Final authorized stop is PASS 49; do not start Phase 3.
