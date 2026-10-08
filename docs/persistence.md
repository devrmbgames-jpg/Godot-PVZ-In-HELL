# Persistence / Night contract

Durable implementation source: Git history; remaining manual acceptance is tracked under `qa_tasks/`.

Refactoring v2 Phase 0 policy (owner decision 2026-10-07): old save-file migration/backward compatibility is not required. The following bullets describe the current runtime; task 19 advances its schema to 3 for an authored quest variant reference. Future incompatible format/path/identity changes bump schema and reject old saves; current-format roundtrip, stable IDs, links and safe failure remain mandatory. Tooling does not delete or overwrite user saves automatically.

- Main startup reads one `user://autosave.pvzh` before simulation. Tests supply an isolated `autosave_path`. Missing, invalid checksum or incompatible schema starts a fresh scene and reports the reason in debug UI.
- Schema **3** includes permanent district people, absent bodies, personal memories, replacement sequence, home-delivery obligations and immutable authored quest variant references. Earlier schemas are deliberately incompatible: startup reports this without migrating or deleting the old file.
- Sleep enters Night with `night_ready=false`. `S_NightSave` runs after phase, wallet/customer settlement and quest outcomes. It clears transient participation, captures the next Morning, writes/flushes a temporary file and atomically renames it into the slot. Failed writes keep Night and retry the same target day; successful writes permit the existing phase System to advance once.
- A successful slot already describes the next Morning. Interruption after file replacement but before the live phase transition therefore resumes that Morning. Progress during the day is committed at Sleep.
- Night first completes delivered home jobs or records failed promises, then clears participation, prepares the next district morning once and captures it. A failed file write retries that prepared morning; bonus operations, promise memory and replacement IDs cannot be generated twice. Physical undelivered boxes are neither marked lost nor moved to storage by this closeout.
- `SaveDataCodec` accepts explicit component fields and record scripts only. Immutable definitions reload by authored resource path; binary variant payloads contain no runtime Objects. Records preserve financial operation IDs, actual customer outcomes separately from declarations, complaints/combat context, late visit IDs, commerce receipts/orders and quest facts.
- Package identity is `package/<package_id>`. Paid pickups use `order/<operation_id>`. Authored entities resolve by scene-relative path; all restored entities retain their Entity ID, with a one-time reindex of the derived World registry. Load validates records before world changes, instantiates missing prefabs, clears all old ownership/storage/cargo bindings, restores component/physical state, then reconstructs Relationships and quest bindings. Disabled entities use World lifecycle APIs.
- NPC identity is `npc/<lifetime sequence>` and survives service visits and temporary absence. `DistrictSnapshotRules` validates unique people/bodies, placement, homes, compatible profiles, personal incidents and delivery-case ownership before mutation. Owned items may reference a disabled living district body. Derived LimboAI players, perception, navigation routes, noises and lighting caches are rebuilt; ongoing attacks, conversations and door/counter reservations do not survive Night. New morning placement retains health, inventory, death and personal memory.
- Preserve physical transforms, fixed-object snapshots, slot/cart membership and package-local ink. Hand/push/cart driving, dialogue/modal/challenge captures, projectiles, transient hazards and body velocities do not cross Night. Persistent hazards retain their lifetime/tick/resolution state, native geometry, source veto and stable-key follow/attribution links; apply owner-loss policy after reset. Fulfilled emitter guards and committed NEVER action IDs/effects are preserved without replay. Incomplete prolonged progress resets, including DECAY/NEVER. Geometry is restored before final disabled state.
- `OrderDeliveryService` creates one authored physical pickup per paid order when a receiving slot is free. Blocked space leaves the order pending. Existing order identity reconciles an interrupted delivery; fulfilled records remain after pickup/consumption. No second charge occurs.

- Morning physical refusal return requires a prior actual refusal, an active registered identity/number and the held parcel at the reachable F return point. Successful commit releases the number and removes the parcel. Actual/declaration, penalties, settlement IDs and complaints remain unchanged.

Checks include the existing save/world snapshot regression, district absent-body/item roundtrip, duplicate-person rejection, actual failed Night write followed by retry, and a connected seven-day district save/reload smoke. Night retry preserves replacement identity and promise memory. Owner rendered/gamepad/layout/full-day/balance acceptance remains under `qa_tasks/`.

## Refactoring v2 identity contract

Phase 1 records the current schema-2 baseline and the target for task 25; it does not claim that runtime migration has happened. `AutosaveStore.SCHEMA_VERSION` is the supported payload version, separate from the `PVZH1` file envelope. The file contains a SHA-256-checked native Variant dictionary without runtime Objects. The supported schema is now 3; earlier schemas and newer versions are rejected without migration. Quest snapshot preflight validates its Definition, stable operation/target IDs, reward/deadline and terminal receipt before live mutation.

| Namespace | Current durable meaning | Target/removal rule |
| --- | --- | --- |
| `package/<package_id>` | Physical shipment key from `C_Package.package_id`; history and visit references retain that package ID | Allocate once; a registration number is reusable display state, never durable identity. |
| `npc/<sequence>` | One actor key shared by `NpcRecord.npc_id`, `C_NpcIdentity.npc_id` and `C_PersistentIdentity.key` | Allocate from persisted district sequence once; absence/reactivation/restore does not create another actor. |
| `order/<delivery_id>` | Physical paid-order identity; `PendingDelivery.delivery_id` corresponds to the producer's operation ID | Receipt, money operation and physical actor have related but distinct contracts; fulfillment/retry cannot charge or spawn twice. |
| operation/settlement/visit/history IDs | `MoneyOperation`, `PurchaseReceipt`, `CustomerVisit`, `PackageRegistrationRecord`, incident/job records preserve producer-owned IDs | Persist producer counters and terminal records; do not reconstruct identity from display names or current day alone. |
| `Entity.id` | Saved String instance ID (`entity_id`); World registry is reindexed after overlay | Distinct from domain key and from numeric GECS `ecs_id`. Registry is derived, never a mutable alias authority. |
| `scene/<relative path>` / `authored_path` | Current placed-actor fallback and restore matching | Remove in 25, before moves; no old-key mapping, guessed identity or NodePath fallback survives that milestone. |
| `runtime/<Entity.id>` | Current fallback for other persistent runtime actors | Spawned actors retain their allocated domain/instance key; never reallocate on load. |
| Definition/content ID and resource path | Shared authored data, including inline `resource.tres::SubresourceId` | Identifies content, not an actor. A subresource suffix is save-visible identity, not incidental formatting. |

Target placed identity is a unique authored local ID scoped by an explicit world/level content ID, with canonical actor key `placed/<world-content-id>/<local-id>`. IDs are authored tokens; validation rejects empty/invalid tokens and duplicate world-scoped keys before registration. Duplicating an imported subscene preserves its recipe but must receive an explicitly repaired instance ID before registration. Renaming/reparenting a node changes only diagnostic paths. A runtime resolver derives actor lookup from registered identity; it does not maintain mutable identity aliases. Definition/content IDs, actor instance keys, GECS numeric IDs and operation IDs remain separate namespaces.

The authoritative field table distinguishes record-owned identity/history/placement from body-owned health/inventory/action and relationship-owned live bindings. NpcRecord and C_NpcIdentity mirrors reference one actor; a retained dormant physical root is that actor's body, not another NPC. ACTIVE/DORMANT implementation belongs to 45; the baseline proves the present enabled/STREET versus disabled/OUTSIDE equivalent without introducing a new LOD mode.

## Snapshot and restore target

Night autosave is a prepared-Morning boundary: finish evening outcomes → reset transient sessions → prepare next Morning once → drain owned pending structural/outcome work at the declared flush points → capture one immutable authoritative snapshot → validate → write/replace. Write retry reuses that snapshot and does not repeat outcomes, preparation, replacement allocation or random decisions. The current implementation already guards evening/preparation with `started_night`, but recaptures on retry; immutable retention and explicit quiescence remain task-25 work. Do not expand the checkpoint to arbitrary mid-action/mid-combat state for LOD. Existing manual save is restricted to a safe Morning by `GameSessionService.save_reason`; its slot/UI boundary is preserved, not expanded by this contract.

Restore target order:

1. Decode, check schema, validate all IDs, resource/subresource paths, recipes and required link endpoints without gameplay effects or live mutation.
2. Construct a fresh startup World/Entities with authored defaults and validated composition. Construction/setup/Observers remain passive until ready.
3. Overlay saved authoritative state after defaults, so recipes cannot reset health/inventory/history.
4. Reconstruct durable owned/stored/cargo and other supported links after all endpoints exist. Reject missing required endpoints; optional loss requires an explicit policy/reason.
5. Rebuild derived caches, participation and presentation; publish ready, then begin simulation.

Failed preflight leaves the live World and file intact. An unexpected construction failure discards the unfinished startup World and publishes no gameplay effects; this is not a promise of generic transaction rollback. Current restore can reuse authored/runtime actors and validate before mutation; the fresh startup/composition gate and removal of path matching are implementation work in 25/41/42. WorldSnapshot.valid alone is not proof of prefab capability safety; can_restore also checks prefab/role contracts. Store read alone verifies bytes/checksum, not semantic validity or schema support.

## Save-visible path inventory and change gate

The machine-readable [save-visible inventory](../tests/fixtures/refactoring_v2/save_visible_paths.json) lists all 31 current Component scripts with exact persisted fields, all 14 allowed record scripts, and 46 paths observed in the [captured current-format fixture](../tests/fixtures/refactoring_v2/current_snapshot.variant). These are actual codec envelopes and snapshot values. Task 28 uses this inventory plus the following exhaustive path-bearing surfaces for its source→target map:

| Serialized surface | Current resolver/guard | Migration obligation |
| --- | --- | --- |
| `entities[].components[].type` | Exact Script membership in SaveDataCodec's component whitelist | Map every listed script and its field contract; moving a type path is incompatible. |
| Nested record `type` envelopes | Exact Script membership in the record whitelist | Map all 14 scripts, including records inside C-owned arrays/aggregates. |
| Nested `definition` envelopes | Prefix `res://content/definitions/`, ResourceLoader existence, GameDefinition type and property type checks | Includes inline `::` IDs; update prefixes for domain definitions before moves. Preserve dependent authored asset references too. |
| `entities[].scene` | Non-authored prefab requires `res://content/entities/` and a PackedScene | Update domain-prefab guards together with construction validation. |
| `entities[].authored_path` and `scene/…` key | Current NodePath match must resolve uniquely inside root | Removed by stable-ID task 25; paths become diagnostic only. |
| ReceivingBatch.package_scenes | PackedStringArray of selected prefab paths; current codec checks the field type, not each resource | Task 25 closes resource/capability preflight; task 28 maps these saved choices, not just scene_file_path. |
| PendingLootDrop.scene_path / opening_hazard_path | LootSnapshotRules prefixes `res://content/entities/` / `res://content/entities/hazards/`, canonical path and PackedScene checks | Preserve selected scene and optional opening effect; update guards with domain moves. |
| Optional top-level `level_scene` in manual slot | GameSessionService's explicit MAIN_LEVEL / TEST_LEVEL selection and equality checks | Include entry scenes in the map; no arbitrary scene selected by untrusted data. |

Relationship endpoint keys, hazard stable-key references, completed-action IDs, ink/anchor data and physical poses contain identity/native values rather than resource paths. Definition-internal scene/schedule/profile/loot/Dialogue references remain authored resource dependencies loaded through the canonical Definition; they are mapped in the resource graph, not copied into another save authority. Binary user-slot location is storage configuration, not actor identity.

Persistence owns the envelope/schema/codec and composes domain snapshot contracts; each domain owns the serialized fields it exposes. Every step that changes persisted identity, type/resource path, field shape or interpretation increments the supported schema, updates all guards/fixtures and proves incompatible/invalid/newer rejection before live mutation with the file preserved. Ownership-only changes retain schema only when serialized identity/path/shape/meaning truly stays identical. No converter, previous-version roundtrip or identity alias is required. Automatically deleting or overwriting an incompatible user file is forbidden, including a later Night autosave after rejected startup. Task 25 must protect that rejected slot until an explicit reset/replacement or another slot is selected; choosing how to present that action remains its implementation responsibility. Replace this current-format fixture when the format changes; do not keep schema-2 compatibility solely for the test.

## Phase 1 baseline debt and evidence

| Debt | Implementation owner | Removal/acceptance gate |
| --- | --- | --- |
| Hidden service steps and System forwarding | Explicit per-symbol tasks in architecture_baseline.json | Empty baseline in 26, strict execution PASS in 27. |
| Horizontal type paths, prefix guards and authored asset dependencies | 25 stable-ID/resource preflight, 28 migration map, 29–32 whole-owner moves | No path aliases; 32/33 strict layout/dependency acceptance and current-format roundtrip. |
| `scene/` matching, retry recapture, no explicit pending-work drain, raw receiving scene strings | 25 | Safe current-format reconstruction and version rejection before moves; rechecked in 49. |
| Rejected startup preserves the incompatible file immediately, but later Night write can overwrite the same path | 25 | Protect rejected slot across subsequent autosave; test startup rejection followed by Night without byte changes. Phase 1 fixture proves immediate preservation only. |
| CharacterBody cart may be skipped by capture without a persisted capability | 25 and cart owner 21 | Inventory all durable link endpoints; no unresolved cargo target. The fixture explicitly adds C_PersistentIdentity to its cart and does not claim the default scene is already fixed. |
| Procedural installers/startup effects and participation authority | 41/42/45 | Core composition/LOD acceptance 49; retained-body fixture updated, no duplicate actors. |

The isolated GUT fixture uses `user://gut_refactoring_v2_phase1.pvzh`, cleans only that slot and never opens the default user autosave. It loads the committed native Variant fixture, proves binary codec/store roundtrip, retained ACTIVE/DORMANT-equivalent physical bodies and durable owned/stored/cargo links, and exercises all 31 Component and 14 record script paths through the real codec. Separate tests reject duplicate/unresolved IDs and unsupported schemas before mutation and preserve the incompatible isolated file. Default-record codec coverage does not claim every gameplay outcome combination is tested.

Static gate: `python utils/validate_persistence_baseline.py`; tool fixtures: `python -m unittest discover -s tests/tools -p test_validate_persistence_baseline.py`. Engine gate: headless GUT `-gtest=res://tests/gut/test_refactoring_v2_persistence_baseline.gd -gexit`. Updating the golden fixture is explicit: set `PVZH_UPDATE_BASELINE=1` for that suite, then inspect/regenerate the serialized-path inventory and run again with the variable unset. Normal runs never rewrite authored fixtures or user saves.
