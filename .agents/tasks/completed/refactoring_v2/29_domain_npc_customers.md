# Refactoring v2.29 — vertical domains: NPC и Customers

Status: **DONE**

Зависимости: [33_domain_dependency_validation.md](33_domain_dependency_validation.md), NPC/Customer execution refactor завершён в 27.

## Goal

Перенести NPC и Customer ownership из horizontal role roots в vertical domains без изменения runtime behavior.

## Scope

Целевые owners:

```text
content/domains/npc/
content/domains/customers/
```

Перенести Components, Relationships, Systems, Observers, Services, Rules/Solvers, Definitions, Entities, AI/dialogue adapters and scenes/resources. Population/schedule/config belongs npc; no district root. Customer-specific trees/adapters import npc contracts, base npc never customer implementation/classes. Cross-owner Dialogue ctx and panel/resource creation move to global UI/glue; domain conversation begin/end/eligibility remain narrow APIs, no domain→UI import. Update E_DistrictNpc→E_Customer hierarchy/callers where it creates implementation cycle; no forwarding superclass. Reciprocal public leaf data references alone do not require another abstraction.

## Rules

- move ownership, not only files;
- обновить все res:// paths, scene ext_resources, tests и docs;
- не оставлять forwarding wrappers в старых roots;
- truly shared code переносить только в `content/shared/`, с явной причиной;
- UI остаётся Godot glue и не превращается в ECS.

## Acceptance

NPC/Customer gameplay код не разделён между старым horizontal root и новым domain без документированного shared contract.
Domain validator PASS.

## Validation

Parser changed scripts + NPC/Customer regression suites + structure validator.

## Result

**DONE — PASS**, 2026-10-09. All 506 mapped files moved: npc 266, customers 234 and global dialogue contexts 6. Scripts, .gd.uid files, scenes, Definitions, behavior trees, dialogue and authoring documentation moved together; all incoming production/test/tool/document references updated. Native script/scene/resource UIDs and original migration-source provenance preserved. NavigationMesh resources belong npc/authoring/navigation, not Definitions. No NPC/Customer owner remains split across old and new paths; zero stale runtime path references and zero task-29 dependency exemptions.

Native E_NpcCharacter is the common physical base; District and Customer actors compose their own recipes. Generic NPC trees have no Customer implementation. Existing full role tree belongs Customers. Native lifecycle/role/brain signals and typed facts permit higher Customer composition, including dormant bodies and passive restore, without native NPC importing Customer cleanup. Global SceneTree composition installs bindings; global UI owns panel/context construction. Domains retain conversation eligibility/begin/end and authoritative Component/Relationship state.

Read/query contracts are separated from mutation owners. CustomerVisitLifecycle owns visit closure/complaint/followup, CustomerParcelAssignment owns parcel binding, CustomerRoleInterruptionService owns composed suspension, HomeMeetingBindings owns live release. Package facts route registration/content outcomes to Customer owners. Combat execution cleanup is separated from attack selection/effects under its mapped task-30 owner. Old APIs were removed and existing public permissions transferred; no compatibility wrappers or duplicate mutable authority.

Current save schema is 5 because persisted NPC/Customer paths changed. Closed Definition/entity-scene guards admit the migrated owner roots; save-visible inventory and native engine-generated golden updated. Incompatible schemas reject without migration or slot overwrite. Remaining unmoved owners keep their mapped paths until tasks 30–32.

## Validation

- Final changed-script Godot parser: **389 files PASS**, zero errors/warnings (`refactoring_v2_29_moved_final_parser.log`). A stale NavigationMesh UID cache diagnostic in the first run was resolved by native headless editor reimport; final parser clean. Editor import itself retains known addon shutdown leak diagnostics and is not claimed as a clean runtime gate.
- Full NPC/Customer profile plus delivery, queued lifetime, retained-disabled and persistence surfaces: **705/705 tests, 5742 assertions**, 37 scripts; zero runtime errors/warnings (`refactoring_v2_29_moved_gut.log`).
- Native current-format golden generation/roundtrip/rejection: **3/3 tests, 274 assertions** (`refactoring_v2_29_moved_baseline_gut.log`); committed golden reloaded in the full profile.
- Actual LimboAI resources: **9 trees, 124 leaves PASS** (`refactoring_v2_29_moved_trees.log`).
- Domain validator fixtures **31/31 PASS**; persistence validator fixtures **5/5 PASS**.
- Migration map, transition domain structure/dependencies, project structure, persistence baseline, refactoring preflight and architecture `--strict`: **PASS**. Strict domain gates remain required after all owners/shared move in 32.
- Actual main-level vertical slice, connected gameplay commits and Night save/fresh-process restore: **PASS** (`vertical_slice-20261009-052559630.log`).
- No rendered gameplay or subjective visual QA performed; no old-save migration.

## Current / Next

Continue [30 — Interaction/Combat/Motion](30_domain_interaction_combat_motion.md) immediately in dependency order. Final authorized stop remains PASS 49; do not start Phase 3.
