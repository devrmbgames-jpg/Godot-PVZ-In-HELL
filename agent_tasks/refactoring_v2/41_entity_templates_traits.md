# Refactoring v2.41 — Entity Templates / Traits runtime composition

Status: **IN_PROGRESS**

Зависимости: [47_game_time_randomness.md](../completed/refactoring_v2/47_game_time_randomness.md), strict domains и authoritative ECS contracts.
Baseline: `857ec02d7703eab840dbf496730be48d29294d99`.

## Goal

One deterministic authoring/compiler path for placed and spawned Entity capabilities,
without a new scheduler, mutable Trait authority or parallel legacy installers.
Scope remains №41. Do not start №42 or expand the migration to unrelated defects.

## Acceptance

- Flat optional `DEF_EntityTemplate`, immutable `EntityTrait`, typed spawn context and
  transient validated build plans; existing native Entity hierarchy remains editable.
- One compile/validate path for scene, code and Trait providers. Duplicate/incompatible
  providers, missing requirements/bindings, foreign endpoints and identity collisions reject
  before registration, ownership transfer, payment or gameplay side effects.
- Every manifest installer is migrated/removed or explicitly classified as an intrinsic
  declarative provider or a runtime transition; no capability repair on a scheduled tick.
- NPC/resident/customer/trader, item/interactable, package/hazard and factory contracts migrate.
  Content variants reuse authored Traits/Profiles without new scripts/global registration.
- Placed/spawned parity, canonical ordering, fresh nested mutable state, failure cleanup,
  registration once and complete initial data/bindings before publication are verified.
- Startup and per-Entity ready barriers cover native callbacks, Observers and first System tick.
  Restore overlays saved state before publication without repeated setup, HP reset or effects.
- Current schema-10 roundtrip and physical ownership are preserved; old-save migration is excluded.
- Formatter, parser/static checks, relevant native GUT/smokes and pinned review/triage complete.
  Parser/runtime/ownership errors remain failures. Memory acceptance follows the owner's
  2026-10-10 decision: sustained post-warmup growth, completed-lifecycle survivors, unbounded
  references/caches and invalid destruction are defects; shutdown retention alone is diagnostic.
  Accepted P0/P1/P2 findings block DONE. Manual/rendered QA requires owner authorization.

## Architectural decisions

- Traits provide configuration/recipes, never ticks or mutable runtime state; Systems consume
  Components independently of their originating Trait. Gameplay `DEF_NpcTrait` remains distinct.
- `EntityRecipeRules` copies mutable Component/record/container graphs with alias preservation;
  immutable Definitions/assets are shared, Component.parent belongs to native registration.
- Scene-owned `EntityAuthoring` selects an optional Template. Factory receives scene/context;
  existing Profile/Definition owns scene selection. Scene→Template→Scene cycles are forbidden.
- Placed preparation uses an explicit World before automatic World.initialize. Whole-set IDs
  and endpoints validate before World.add_entity; compilation does not assign ECS.world early.
- Initial bindings fix up once native IDs exist. RegistrationScope temporarily withholds reactions,
  then publishes complete composition; plans/scopes are transient, with no second registry.
- Saved death/ink/anchor/NEVER-action markers overlay private validated recipes before publication.
  Unknown/duplicate actions, malformed data or changed reset policy reject without live mutation.
- Physics bodies own pose/velocity. Restore establishes physical state before native publication.
  Home address identity persists in schema 10; authored labels reconstruct from its immutable key.

## Current / Next

Implementation and memory comparison are complete; final review/regression/smoke are pending.
Runtime comparison target: `fc58024f827607286afd1d20d009e3bf22495f64`.
Memory criterion: `1097d8421892e86c4c8a6aff9b3fa6af18069dfa` (explicit owner decision).
The RV-001 runtime fix and its tests are unchanged since their full fix SHA below.

[Composition manifest](../../utils/entity_composition_manifest.json): **72/72 resolved**,
**73 scene intrinsic sources**, verified in committed HEAD and the current worktree.
[Domain contracts](../../utils/domain_contracts.json) and
[migration map](../../utils/domain_migration_map.json) retain the declared ownership.
Pre-existing config, authored definitions, manifests and addon worktree edits remain preserved.

Next: collect the memory/lifetime checkpoint review, run final native GUT and headless smoke.
Repeated equivalent lifecycles are stable; RV-003 is rejected as a memory-leak claim below.
The independently inherited compile-only shutdown diagnostic is owned by
[cold snapshot resource retention](../cold_snapshot_resource_retention.md).
The owner explicitly changed the former shutdown-only blocker on 2026-10-10; warnings remain
visible and parser/runtime/ownership errors still block. No global warning suppression added.
Audit found an independent baseline HazardLifecycle use-after-free, repaired separately in
`1e86867a7ad38a6dfcfbddd212c9d2705e88f129`.
No №42 or Phase-3 work is authorized by the current request.

## Review findings

All available reviews are **COLLECTED / TRIAGED**; no REVIEW_PENDING remains.
Exactly one reviewer, `/root/review_task41_checkpoint`, was reused after it finished.
An older unrecoverable result remains **NOT_RUN (result unavailable)**; no PASS was fabricated.

Current immutable review evidence:

- Original replacement: BASE `857ec02d7703eab840dbf496730be48d29294d99`,
  TARGET `da636b0c5c46cd82260e58db1a508ca00f531fb8`; one R1, accepted as RV-001.
- Fix review: BASE `a95d10e7d01dbb513788289f6771d41dbefb58d8`,
  TARGET `bed9908d38a709f8f565a7a3ced60f78e1980ac2`;
  **FIX VERIFIED / ARCHITECTURE PASS**, bounded to RV-001.
- Latest additional review: BASE `857ec02d7703eab840dbf496730be48d29294d99`,
  TARGET `3a7566318350d4091226cf962e8a6321dd609d60`;
  **NO_FINDING**, ARCHITECTURE/VALIDATION **NOT_RUN**; not full task acceptance.
- Reviewer STYLE PASS is static assessment only; native checks below were run by Main.
  GECS at both snapshots: `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`.

**RV-001 | P1 | FIXED | Main / №41**

Source `da636b0c5c46cd82260e58db1a508ca00f531fb8`:
WorldSnapshotService._overlay_saved_markers / PersistentInteractionState.recipe_for.
Invalid saved completed_actions reached materialization/assertions before rejection.
Container/element types, uniqueness and final authored NEVER policy now validate first.
Unknown/renamed IDs, malformed values, duplicates and changed policy are one deduplicated defect.
Fix: `bed9908d38a709f8f565a7a3ced60f78e1980ac2`; fresh and placed rejection covered,
61/61 native tests, parser 4/4 and bounded independent fix review verified.

**RV-002 | P2 | FIXED | Main / task metadata**

Source `a95d10e7d01dbb513788289f6771d41dbefb58d8`:
agent_tasks/parallel_review_pilot.md had an unsupported status/missing Task state sections.
Fix: `bed9908d38a709f8f565a7a3ced60f78e1980ac2`; structure validation PASS.
Origin/verification are Main's structure gate, not reviewer R1 or independent review.

**RV-003 | P2 | REJECTED (shutdown-only leak inference) | Main / №41**

Source `fc58024f827607286afd1d20d009e3bf22495f64`: native district snapshot shutdown.
Identical baseline leaf test, settings, GECS and Godot pass 10/10 / 87 assertions on both,
but baseline exits cleanly and target retains **670 Objects / 507 resources**, Jolt/render/font
RIDs and Variant pages. This failed the former zero-shutdown-diagnostics gate; the raw evidence
remains intact. Retention alone does not establish a runtime leak under the new owner criterion.
It already reproduces at first implementation checkpoint
`f7e756fab3387dfa1f590c4d0ff047fec3ba9f57`: 10/10 / 87, **412 Objects / 272 resources**.
Historical class cache includes that snapshot's CustomerActionRecipe; no parser errors remain.
Shutdown output changed with №41, but repeated lifecycles do not show a memory leak:
13 scenarios, 12 warmup + 60 measured cycles each; World restart also 40 + 100.
Both snapshots keep Objects/Resources/Nodes constant and orphans at zero. MEMORY_STATIC settles
to a plateau (inspection oscillates within 336 bytes); RSS/Private Bytes plateau.
This includes Entity/proxy/inspection in one live World.
No retaining owner or runtime-growth regression is claimed from shutdown counts.
Evidence: [trend CSV](../../tests/fixtures/memory_lifecycle_baseline.csv) and
[source/conditions](../../tests/fixtures/memory_lifecycle_evidence.json). No fake fix SHA assigned.

## Validation

Recorded evidence is scoped; historical passes are not a fresh whole-task acceptance:

- Full native suite: **98 scripts / 1415/1415 / 11960 assertions**, zero diagnostics.
  Log: `tests/artifacts/refactoring_v2_41_complete_after_callers_gut.log`.
- RV-001: **3 scripts / 61/61 / 657 assertions**, zero diagnostics; final parser **4/4**.
  Logs: `tests/artifacts/refactoring_v2_41_rv001_gut.log`,
  `tests/artifacts/refactoring_v2_41_rv001_final_parser.log`.
- Previously run actual main, Night two-process roundtrip, receiving_scan and relevant factory
  smokes passed; this diagnostic batch did not rerun them or launch rendered gameplay.
- Same-engine baseline/current comparison: controls parse **1/1 clean on both**; compile-only
  snapshot probes parse successfully but **FAIL** at shutdown (280/236 baseline, 294/247 target).
  Identical save-data GUT is **6/6 / 40 assertions PASS** with zero diagnostics on both.
- Same baseline district leaf is **10/10 / 87**, clean baseline versus RV-003 target FAIL.
  Leaf and probe SHA-256, full source SHAs, engine/settings/GECS identity and exact commands:
  [durable comparison evidence](../../tests/fixtures/cold_snapshot_retention_evidence.json).
- Raw machine results/logs: `tests/artifacts/refactoring_v2_41_compare_same_probes.json`,
  `tests/artifacts/refactoring_v2_41_compare_same_district.json`,
  `tests/artifacts/refactoring_v2_41_compare_{baseline,current}_district_gut.log`,
  `tests/artifacts/refactoring_v2_41_first_checkpoint_district_gut.log`.
- Other historical bounded runs failed the old shutdown-only gate: Customer 20/20 / 201, 749/530;
  address 49/49 / 777 assertions, 683/508. Their common root cause is not proven.
  Logs: `...remaining_customer_callers_gut.log`, `...address_persistence_gut.log`.
- Current growth checks: same Godot 4.7.1/GECS/settings and byte-identical normalized GUT scenarios.
  5184 assertions per snapshot in main ten-scenario run; supplements exercise persistent Entity,
  proxy and inspection plus 100 World cycles. All functional checks and native diagnostics clean.
  Host RSS/Private Bytes sampled through a quiescent handshake; assertion bookkeeping bounded.
- [Lifetime audit](../../tests/fixtures/memory_lifecycle_audit.json): 921 project-owned scripts
  scanned, 85 production free/queue_free sites, no reference/unreference calls. Significant
  caches, WeakRef containers, Callables and seven priority owners reviewed; one baseline UAF fixed.
- Final changed parser **3/3** and final probe parser **1/1**, zero diagnostics; formatter,
  agent, strict architecture/structure and three trend-analysis Python fixtures PASS.
  Final whole-native GUT, smoke and pinned checkpoint review remain pending.

## Owner QA / blockers

Shutdown retention alone no longer blocks DONE under the owner's explicit criterion change.
Complete final review/regression/smoke before archive. Independent shutdown investigation remains
separate; no engine/addon upgrade, warning suppression or load-order workaround adopted.
No rendered/manual QA is claimed. Tests establish stability on listed lifecycles, not every path.
