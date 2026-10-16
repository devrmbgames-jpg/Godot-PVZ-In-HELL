# Persistence / Night contract

A save is a versioned snapshot of authoritative domain data at a safe Morning boundary. It is not a serialized SceneTree. Night autosave prepares the next Morning; manual save captures the current safe Morning. Simulation resumes only after passive reconstruction and explicit reconciliation.

The supported version has one source: [AutosaveStore.SCHEMA_VERSION](../content/domains/persistence/services/autosave_store.gd). Incompatible older and newer snapshots are rejected without conversion. The owner permits keeping the existing binary storage if ConfigFile cannot preserve the required values; [PVZ-B01](../.agents/tasks/pvz_b01_configfile_save_storage.md) is deferred. Production uses the PVZH1 format described below.

## Owners and entry points

| Owner | Responsibility |
| --- | --- |
| [AutosaveStore](../content/domains/persistence/services/autosave_store.gd) | Synchronous file read/write and byte integrity; no gameplay validation. |
| [SaveDataCodec](../content/domains/persistence/services/save_data_codec.gd) | Closed Component fields and record types; native values and immutable Definition references. |
| [WorldSnapshotService](../content/domains/persistence/services/world_snapshot_service.gd) | Capture, semantic preflight and explicit reconstruction, composing domain snapshot contracts. |
| [S_NightSave](../content/domains/persistence/systems/s_night_save.gd) / [C_Autosave](../content/domains/persistence/components/c_autosave.gd) | Scheduled Night preparation, immutable prepared snapshot, operational retry state and readiness. |
| [NightSaveService](../content/domains/persistence/services/night_save_service.gd) | Explicit startup restore and rejected automatic-slot protection. |
| [GameSessionService](../content/scenes/game_session_service.gd) | Safe manual save, compatible slot selection and one-shot scene handoff. |
| [GameWorld](../content/scenes/game_world.gd) | Passive composition, readiness publication and explicit startup reconciliation. |

Gameplay domains own their persisted fields and records. They do not import the persistence adapter to schedule themselves. Settings, InputMap, device/prompt revisions and texture caches remain process/UI state.

After a supported snapshot overlays physical packages and the ledger, `PackageRegistrationService.reconcile_received()` assigns numbers to existing active unnumbered arrivals before readiness/customer planning. It does not create missing parcels, register declared-LOST cases, replay registration events, or change existing numbers/dates. New numbers use the restored current Morning as registration day; the original received day stays intact. This one-shot domain reconciliation preserves the existing schema and PVZH1 storage; it is not a previous-schema converter. Already committed penalties remain historical facts.

## File, version and errors

`AutosaveStore.DEFAULT_PATH` is `user://autosave.pvzh`. GameSessionService selects separate manual and test-level slots; isolated QA rooms have no slot. Tests must override paths and clean only their own files.

The file consists of a `PVZH1` line, a SHA-256 hexadecimal digest line, then the native binary `var_to_bytes(snapshot)` payload. The envelope marker and snapshot `version` are separate contracts. `read()` checks file presence/opening, size, marker, payload hash and Dictionary root, then decodes with `bytes_to_var` without enabling Object decoding. The codec's supported snapshot graph contains no live Objects. A readable Dictionary is still untrusted: schema, IDs, resource capabilities and link endpoints require `WorldSnapshotService.can_restore()`.

`write(snapshot, path) -> Error` rejects an empty path or an empty/oversized encoded payload, opens `path + ".tmp"`, writes header/hash/payload, calls `FileAccess.flush()`, checks the file error, closes it and returns the result of `DirAccess.rename_absolute()` into the slot. `OK` means this synchronous operation completed. There is no queued-write receipt, readback validation, backup, unique temporary filename or guaranteed power-loss recovery. Do not promise fsync or generic transactional rollback. Failed writes may leave the temporary file.

`MAX_BYTES` is 64 MiB. **The existing writer limits payload bytes, while the reader limits the whole file.** A payload near the limit can therefore be written and subsequently rejected because of the header overhead. A unified whole-file limit remains deferred with B01; callers must not treat the current checks as identical.

`read()` returns `{}` for missing, unreadable, corrupt or non-Dictionary data. Startup distinguishes a missing slot from a rejected existing file using `FileAccess.file_exists()`. Store read alone neither checks the supported schema nor makes the data safe to apply. Manual and Night capture run semantic preflight before writing.

Changes to persisted identity, type/resource paths, field shape or interpretation bump the supported schema and update guards and current-format fixtures together. Ownership changes can retain the version only when serialized identity, paths, shape and meaning stay identical. No legacy converter or identity aliases are required. Unsupported files are preserved.

Schema 21 retains the frozen catalog quantity/packing on `C_PackageContents` and `ReceivingBatch` introduced in schema 20, and adds `ordered_quantity` and `packing_profile` to the immutable `PackageRegistrationRecord` arrival projection. Archive views derive full mass, handling tags and hazards from those definitions after the physical body has left or its contents have been consumed. Preflight validates capacity, native scene, live/archive agreement and diagnostic ID mass/hazard before changing the World. Fresh compilation receives the saved composition before publication; fresh and reused bodies restore full or empty mass. Unsupported earlier schemas are rejected and protected from automatic replacement, following the owner's decision to preserve the old file. PVZH1 storage is unchanged; there is no conversion of earlier inconsistent boxes.

Schema 22 adds persisted `C_Strength` to native NPCs through `ET_NpcParcelHolder`. Fresh and retained district bodies restore the saved positive Strength rather than the authored default. Schema21 NPC records without that component are unsupported: startup rejects them before mutation and preserves the original file. The PVZH1 envelope is unchanged.

Schema 23 persists `C_CustomerFlow.parcel_incident_sequence` and typed pair incidents. The chosen outcome and active-gameplay deadline commit before physical effects; capture refuses an in-progress reaction. Semantic preflight rejects malformed sequences, duplicate pairs/deadlines and impossible held endpoints before mutation. Accepted restore retires previous stolen grips and rebuilds only committed NPC ownership through the common grab owner while observers are suspended; it never repeats RNG, speech, impulses or damage. Unsupported schema22 and earlier files are rejected and preserved, without conversion or PVZH1 changes.

## Refactoring v2 identity contract

This heading retains incoming historical links; the rules below describe the implemented runtime.

| Namespace | Durable meaning |
| --- | --- |
| `placed/<world-content-id>/<local-id>` / `authored_id` | Explicit immutable level/instance identity compiled as `C_AuthoredIdentity`; no NodePath fallback. |
| `package/<package_id>` | Physical shipment key from `C_Package`; reusable registration numbers are display/allocation state. |
| `npc/<sequence>` | One lifetime actor shared by the district record, NPC identity and persistent actor key, including temporary absence. |
| `order/<delivery_id>` | Physical paid-order actor; retry reconciles the existing delivery rather than charging/spawning again. |
| Operation, settlement, visit and history IDs | Producer-owned counters and terminal records, distinct from actor identity and display names. |
| `Entity.id` / `runtime/<Entity.id>` | Saved string instance ID and fallback actor key; distinct from numeric GECS `ecs_id` and engine instance IDs. The World registry is rebuilt. |
| Definition path, including `resource.tres::SubresourceId` | Immutable authored content identity, not actor identity. Inline subresource suffixes are save-visible. |

[ActorIdentityRules](../content/shared/rules/actor_identity_rules.gd) reads owner-provided identity through `C_ActorIdentityReference`, then compiled placed identity, then runtime identity. It does not copy IDs into a mutable alias map. Authored world/local tokens must be valid and unique before registration. Duplicated placed subscenes need a distinct authored instance ID. Node rename/reparent does not change identity; children of ownerless spawned prefab roots are runtime children.

| Authority | Saved or reconstructed state |
| --- | --- |
| Domain Components and records | Explicit `SAVE_FIELDS`, health, inventory/action state, operation histories/counters, district roster, placement/death, memories, obligations, quest facts and immutable variant references. |
| Physical body | Supported pose and native physical state/geometry through the explicit snapshot synchronization boundary. A retained dormant root remains the same actor's body. |
| Relationships | Durable owned/stored/cargo links serialize stable endpoint keys and local pose; required endpoints must exist before binding. Disabled living district bodies can own items. |
| Derived state | World lookup, participation, LimboAI/Blackboard, perception/navigation, monitor membership and presentation caches are rebuilt from authoritative owners. |

Capture includes persistent disabled Entities and supported raw physical actors. Raw-body identities and recipe bindings are explicit snapshot data, not scene paths inferred as actor identity. Physical transform/velocity authority remains with Godot bodies outside the synchronization boundary.

Night retains health, inventory, death, personal memory, fixed-object poses, slot/cart membership, package-local ink and supported persistent hazards. Persistent hazards preserve lifetime/tick/resolution state, geometry, source veto and stable-key attribution/follow links; reset applies their owner-loss policy. Fulfilled emitter guards and committed NEVER action IDs/effects remain without replay. Incomplete prolonged progress resets, including DECAY/NEVER. Hand/push/cart driving, ongoing attacks, conversations, reservations, modal/challenge captures, projectiles, transient hazards and body velocities do not cross Night.

District roster state and body state retain their separate writers. Explicit startup/restore reconciliation preserves an already planned current day/phase, including completed goals and saved dormant placement; it assigns missing plans. Real calendar transitions and explicit retry requests keep their ordinary planning behavior.

## Safe manual save

`GameSessionService.save_reason(root, menu_owner)` requires the active World's level root, an approved main/test entry scene and Morning. Living Customer agents, armed/active challenges, higher-priority interaction captures and held/prolonged/push/cart-driving Relationships reject the save. Only the requesting menu's own modal owner can be excluded from the capture check.

`save_game(root, menu_owner, path_override)` returns `GameSaveResult` synchronously. It captures the current Morning, adds the approved `level_scene`, runs `can_restore()`, then writes to the selected manual slot or explicit override. Inspect `success` and `message`; a gameplay/preflight rejection does not write the slot. This API does not extend saving to arbitrary combat/action states.

## Clock, Night preparation and commit

[main_level.gd](../content/scenes/main_level.gd) processes `Clock` with raw callback seconds, then `Input` and `Interaction` with gameplay tick seconds, `Physics` with raw seconds, `GamePlay` with gameplay seconds, and `Storage` with raw seconds. Night freezes gameplay ticks while operational storage retries continue. See [Game Time](game_time.md) for clock domains.

Only `S_DayPhase` publishes committed `DayPhaseChanged` facts. `O_WalletDay` reacts to those facts through the explicit idempotent wallet operation. Customers use `CustomerPlanningRequest.Kind.RECONCILE_SESSION` for bootstrap, with a typed completion receipt and terminal `RECONCILED` notification; reconciliation does not fabricate a calendar transition. Startup/restore explicitly synchronizes the wallet after passive reconstruction. A prepared snapshot can lack the next Morning's daily row; readiness ensures that row once, without repeating completed-day settlement.

`S_NightSave` runs in `Storage`, with dependencies after `S_DayPhase`, `S_CustomerFlow`, `S_RefusalQuest` and `S_LootDrops`. Its queued step captures a WeakRef, exact calendar/autosave Components, Night day and workflow revision. A stale entity, replacement Component, revision, World membership or phase rejects the queued context.

1. Refuse a protected `rejected_path` before evening outcomes/reset/preparation.
2. Complete delivered home jobs or record failed promises, then reset transient participation. Physical undelivered boxes are not marked lost or moved into storage by this closeout.
3. Request next-Morning district preparation once and retain its typed receipt. Drain pending command buffers with the bounded `CommandBufferBarrier`, including wallet/outcome reactions, before capture. Pending/failed preparation or a failed drain keeps Night unready.
4. Capture and preflight the prepared Morning once; retain a detached deep copy in `C_Autosave.prepared_snapshot`.
5. Write that same value graph. I/O failure schedules another attempt after `max(MIN_RETRY_SECONDS, retry_seconds)` raw seconds. It does not repeat successful preparation, capture, random choices, replacement IDs or payments.
6. Only successful write sets `last_saved_morning` and `night_ready`. `S_DayPhase` can then advance once. The committed slot already describes the next Morning, including interruption before the live transition.

An empty save path still settles/reset/prepares but performs no I/O; it sets `last_prepared_morning` and readiness, not `last_saved_morning`. This is the isolated test-room contract.

## Preflight, passive restore and rejected slots

Startup reads a candidate before simulation. `GameSessionService.saved_game()` scans manual/automatic slots by modification time and selects the newest compatible candidate for the approved level; a newer invalid file does not hide an older valid one. The scene handoff is a detached snapshot, not retained Entity references.

1. Check supported version, IDs, closed typed codec, native resource/subresource paths, prefab/role capabilities, recipes and required link endpoints before live mutation. `WorldSnapshotService.valid()` alone is insufficient.
2. Construct startup composition passively with authored defaults, or enter the explicit replacement boundary for an existing World. The boundary invalidates old queued work and suppresses gameplay Observer dispatch.
3. Overlay authoritative saved fields, reconstruct missing actors/recipes, clear old ownership/storage/cargo bindings and rebuild durable links after endpoints exist. Restore native geometry and pose before final enabled/disabled state.
4. Rebuild quest bindings, district participation/body-derived tuning/brain state and raw physical state. Seed monitor membership without synthetic gameplay MATCH facts; the project adapter uses the pinned GECS integration surface without editing the addon.
5. Publish Entity readiness and reconcile district, Customers and wallet explicitly, then drain pending work. Startup passes `defer_reconciliation=true` to restore and performs this at `GameWorld.finish_startup()`; in-place restore performs it before returning. Simulation is gated by composition readiness.

Failed preflight leaves the live World and slot intact. An unexpected reconstruction failure is not a general rollback guarantee: startup marks `construction_failed` and must abandon the incomplete level. It must not resume partially reconstructed gameplay.

`NightSaveService.restore_startup()` records `C_Autosave.rejected_path` for an existing unreadable, unsupported or semantically invalid automatic slot. Later Night attempts on that same path return `ERR_UNAUTHORIZED` before reset/preparation and leave its bytes intact. Loading a compatible manual slot does not authorize overwriting a rejected automatic slot. Explicit New Game or choosing another path permits later replacement; New Game does not immediately delete files. Missing files start fresh without a protected rejected slot. Status/rejection reasons use the existing startup/save UI surfaces.

## Save-visible paths and checks

The [codec/path inventory](../tests/fixtures/refactoring_v2/save_visible_paths.json) and [captured current-format fixture](../tests/fixtures/refactoring_v2/current_snapshot.variant) are executable evidence, not independent schema authorities. Their actual counts are validated by tooling rather than duplicated in prose.

| Serialized surface | Current guard |
| --- | --- |
| Component and nested record `type` | Exact SaveDataCodec script whitelist and field contract. |
| Definition envelopes, including `::` suffixes | [GameplayResourcePaths](../content/shared/rules/gameplay_resource_paths.gd) approved domain/shared Definition roots, existence, GameDefinition and property type checks. |
| Non-authored entity `scene` | Approved domain/shared entity roots, PackedScene and role/capability preflight. |
| Placed key / `authored_id` | Unique immutable world/local ID in the level; no NodePath alias. |
| Receiving package choices and pending loot scene/hazard paths | Domain snapshot rules validate retained scene choices, paired IDs and reconstruction capabilities. |
| Optional manual `level_scene` | GameSessionService's explicit main/test entry-scene selection and equality checks. |

Definition-internal scene/schedule/profile/loot/Dialogue dependencies remain authored resources. Moving a native resource or inline ID requires checking this graph as well as snapshot envelopes. Slot paths are storage configuration, not actor identity.

Relevant checks:

- `python utils/validate_persistence_baseline.py` and `python -m unittest discover -s tests/tools -p test_validate_persistence_baseline.py` validate the fixture/inventory contract.
- [test_refactoring_v2_persistence_baseline.gd](../tests/gut/test_refactoring_v2_persistence_baseline.gd) proves current codec/store roundtrip, nondefault clock/decision state, dormant bodies and durable owned/stored/cargo links in an isolated slot. Default record coverage does not prove every gameplay combination.
- [test_world_snapshot.gd](../tests/gut/test_world_snapshot.gd), [test_startup_restore.gd](../tests/gut/test_startup_restore.gd) and [test_district_lifecycle.gd](../tests/gut/test_district_lifecycle.gd) cover rejection before mutation, passive readiness, Night retries, rejected-slot protection and planned dormant-state preservation.
- `utils/run_smoke.ps1 -Name night_persistence` writes and restores in separate headless processes. Headless checks do not establish visual/gamepad/gameplay feel acceptance.

Normal tests never rewrite the golden fixture or default user slots. To deliberately update the captured fixture, set `PVZH_UPDATE_BASELINE=1` only for the baseline suite, inspect the result and update the inventory, then rerun with the variable unset. Implementation history belongs in Git and archived task records, not migration TODOs in this contract.

## Executable examples

These are test bodies for the isolated [WorldSnapshot GUT fixture](../tests/gut/test_world_snapshot.gd): it supplies `_root`, `_session`, `_attach_native_catalog()` and `_night_step()`. They are not methods to paste into a live level. An extending fixture must remove only these two example slots and their `.tmp` files in teardown, then await `super.after_each()`.

Safe Morning save, schema/preflight and restore through the current APIs:

```gdscript
func test_doc_safe_morning_roundtrip() -> void:
	_attach_native_catalog()
	var path: String = "user://pvz_doc_roundtrip.pvzh"
	var saved: GameSaveResult = GameSessionService.save_game(_root, null, path)
	assert_true(saved.success, saved.message)
	var snapshot: Dictionary = AutosaveStore.read(path)
	assert_eq(snapshot.get("version"), AutosaveStore.SCHEMA_VERSION)
	assert_true(WorldSnapshotService.can_restore(snapshot, _root))
	assert_true(WorldSnapshotService.restore(snapshot, _root))
```

Unsupported isolated slot remains byte-identical after a real Night storage step. Direct phase assignment below is fixture setup, not the gameplay transition API:

```gdscript
func test_doc_rejected_slot_survives_next_night() -> void:
	var path: String = "user://pvz_doc_rejected.pvzh"
	var snapshot: Dictionary = WorldSnapshotService.capture(_root, 1)
	snapshot.version = AutosaveStore.SCHEMA_VERSION + 1
	assert_eq(AutosaveStore.write(snapshot, path), OK)
	var retained: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var state: C_Autosave = _session.get_component(C_Autosave) as C_Autosave
	state.path = path
	assert_false(NightSaveService.restore_startup(_root, state))
	assert_eq(state.rejected_path, path)
	DayPhaseQueries.current().phase = C_DayCycle.Phase.NIGHT
	_night_step(0.1)
	assert_eq(state.last_error, ERR_UNAUTHORIZED)
	assert_eq(state.started_night, 0)
	assert_eq(FileAccess.get_file_as_bytes(path), retained)
```
