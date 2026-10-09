# Refactoring v2.25 — Persistence и remaining services

Status: **DONE**

Зависимости: [24_economy_inventory_commerce.md](24_economy_inventory_commerce.md); задачи 10–23 завершены по последовательному execution chain.

## Goal

Закрыть весь service inventory: отдельно проверить persistence/input/UI/debug и все файлы, не попавшие в доменные задачи.

## Persistence

Codec/snapshot/store/validation helpers обычно остаются вне ECS scheduling. Old-schema converters вне scope по решению владельца.
Отделить serialization от gameplay authority.
Не менять save schema только ради архитектурной чистоты без отдельной необходимости.

This milestone implements the explicit stable authored actor identity specified in 04, before path moves 28–32. Assign world/level-scoped local instance IDs to every persistent placed Entity; generated domain IDs remain persisted sequences. Remove scene/<relative path> fallback and NodePath-based restore matching with all callers/scenes/fixtures; diagnostic scene paths are not identity. Bump incompatible schema, reject old saves; test that renaming/reparenting an authored node retains identity and links. No legacy-key alias. Phase 1.04 defines the contract; it does not perform this runtime migration.

Complete safe snapshot/reconstruction contract из 04: Night prepared-Morning quiescence, no pending structural/outcome work at capture, no repeated preparation on write retry, immutable snapshot before I/O. Validation includes all prefab/recipe/ID/link checks before live replacement; new-template startup suppresses gameplay effects until restore/fixup. Missing required endpoint rejects; explicitly optional endpoint may be dropped with a reason, never guessed. Invalid save leaves prior valid state/file intact; unexpected startup construction failure abandons incomplete world rather than simulating partial restore. No old-save converters or aliases.

Protect an incompatible rejected user slot from later automatic writes as well as immediate startup mutation. Rejected startup followed by Night must preserve the file byte-for-byte until explicit reset/replacement or another slot is selected. Current NightSaveService has no rejected-slot protection; 04 documents this baseline debt, not completed safety.

Persistence owns storage/codec/composition of snapshot adapters; domains own state and expose schema contracts. Domain→Persistence imports/autosave calls migrate to global composition bindings, keeping the import graph acyclic. UI/BT/navigation/perception/reservation queues are reconstructed/reset under Night policy, not serialized as live Objects. Actual current-format roundtrip includes dormant registered bodies and per-field NPC aggregate metadata.

## Remaining services

Для каждого ещё не закрытого inventory item выполнить назначенный KEEP/MOVE/SPLIT/RENAME/DELETE.
Проверить naming: класс с ролью Geometry/Rules/Solver/Presentation не обязан называться Service.

## Acceptance

100% строк service inventory имеют финальный статус **DONE/KEPT_WITH_REASON**.
Нет «временно оставленных» hidden schedulers.

## Validation

Persistence/save regression tests для затронутых файлов; parser; structural validator.

## Current / Next

DONE 2026-10-08. Acceptance PASS: 136/136 original inventory rows are final (38 DONE, 98 KEPT_WITH_REASON), hidden scheduling findings and migration baseline are empty. No old-save migration/converter/alias was introduced. Continue [26 — execution graph cleanup](26_execution_graph_cleanup.md), including the concrete freed-Callable lifetime audit recorded there; do not skip checkpoint 27 or start vertical relocation before 28.

## Implementation

- S_NightSave owns actual retry seconds, one Night reset/preparation request, bounded structural/outcome drain, immutable value capture and readiness. NightSaveService.process was deleted. I/O retry writes the retained C_Autosave snapshot even after live debt changes; no repeated random/preparation decisions. Rejected current/old/corrupt slots remain byte-identical through subsequent Night and selected-manual handoff. Another path or explicit New Game permits replacement.
- Entry scenes have explicit persistent_world_id and per-instance persistent_local_id metadata, including nested physical/belt slots. PlacedIdentityRules validates all tokens before registration, compiles immutable C_AuthoredIdentity and derives lookup by actor identity. ActorIdentityRules preserves generated domain IDs; authored_id is an immutable recipe-origin reference. NodePath matching and scene/path identity fallback were removed with all callers/fixtures. Runtime children of ownerless prefab roots are not mistaken for placed actors.
- Schema 3 → 4 is intentionally incompatible. The actual current-format golden fixture and path/field manifest were regenerated, inspected and tested normally afterward. Old/newer/invalid schemas reject before live mutation or overwrite; no legacy roundtrip.
- Complete can_restore preflight precedes live mutation and validates roles/IDs/links/native poses/receiving recipes. Passive GameWorld startup constructs defaults without gameplay Observer dispatch, then overlays data, resolves links, rebuilds caches/participation/recipe geometry/monitor membership and publishes readiness. Unexpected validated-startup construction failure abandons the incomplete level. Actual effect-spy proves defaults never reacted and fresh gameplay reacts after readiness.
- Delivery and fresh snapshot packages use one explicit unregistered recipe operation. PackageConditionService/O_PackageConditionSetup retain reactive default ownership and rebuild unsaved impact/liquid settings without resetting saved damaged HP. Hazards rebuild geometry without spawn/damage replay. SnapshotRestoreBoundary's sole pinned GECS adapter silently reseeds monitor membership because v8 exposes no public silent reseed API; addon source remains untouched.
- Domain Components own their SAVE_FIELDS contracts; codec composes them. Shared actor-key/link contracts remove cyclic snapshot-helper imports. Domain gameplay owners import no persistence adapter/autosave API; Night scheduling belongs to persistence composition. MetaPresentation moved to global presentation with preserved UID. Remaining settings/InputMap/prompt/UI/debug/codec helpers retain explicit operation or derived-cache roles; every inventory row is closed.
- All direct/inherited snapshot fixtures migrated to explicit authoring IDs. Script-constructed physical fixture actors are authored explicitly instead of pretending an ownerless body without a prefab can reconstruct in a new world. The old-body fabricated scene-path test was replaced by a current-format CharacterBody motion-reset test.

## Validation evidence

All final runtime/parser regression logs are clean: no relevant errors, warnings or resource leaks. No rendered gameplay or subjective visual QA ran.

- Godot changed-script parser: **73 files, 0 failures PASS**.
- Architecture validator: **PASS, 0 lexical findings, empty baseline**. Project structure, persistence baseline and refactoring preflight validators: **PASS**. Persistence validator tool fixtures: **5/5 PASS**; git diff --check PASS.
- Persistence/startup/session/runtime/current-format baseline GUT: **54/54, 758 assertions PASS**, `tests/artifacts/refactoring_v2_25_persistence_gut.log`.
- District/population/lifecycle/delivery-completion/save-data/settings/console/debug GUT: **82/82, 799 assertions PASS**, `tests/artifacts/refactoring_v2_25_remaining_gut.log`.
- Actual MorningTruck/TruckShiftGate/package-contents/safe-loot/furniture/receiving-limits GUT: **111/111, 1046 assertions PASS**, `tests/artifacts/refactoring_v2_25_recipes_gut.log`.
- CharacterBody/player-interaction-events/breakable-door GUT: **20/20, 158 assertions PASS**, `tests/artifacts/refactoring_v2_25_physics_fixtures_gut.log`.
- Actual two-process scheduled Night save/startup restore: **write/restore PASS**, `night_persistence-write-20261008-153909135.log`, `night_persistence-restore-20261008-153918236.log`. Restored debt/hunger/inventory/prepared district and a physical link after actor rename.
- Actual current-format loot pending write/restore: **write/restore PASS**, `safe_loot_placement-write-20261008-153926379.log`, `safe_loot_placement-restore-20261008-153934477.log`.

Headless editor import still reports the previously documented third-party shutdown noise (6 ObjectDB/3 resources); it is not claimed as the parser/clean runtime gate. Relevant GUT/smoke/parser logs pass without that noise. Intermediate fixture/preflight failures were corrected and their full surfaces rerun cleanly; no error suppression or broad ignore was added.
