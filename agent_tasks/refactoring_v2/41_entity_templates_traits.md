# Refactoring v2.41 — Entity Templates / Traits runtime composition

Status: **IN_PROGRESS**

Зависимости: [47_game_time_randomness.md](../completed/refactoring_v2/47_game_time_randomness.md), strict domains и authoritative ECS contracts.

## Goal

Добавить authoring/compiler слой, позволяющий собирать Entity capabilities из Traits без нового runtime scheduler.

## Minimal contracts

Достаточно следующих ролей; отдельная public class для каждой не обязательна:
- `EntityTrait`;
- `DEF_EntityTemplate`;
- `EntityBuildPlan`;
- typed SpawnContext contract;
- compile/validate operation;
- существующая factory boundary с Template support.

Flat Templates, без inheritance/override framework. BuildPlan — transient validated recipes, не второй cache/runtime registry. New Trait script нужен для новой capability; content variants используют existing Trait/Profile. Arbitrary install hooks и mutable shared state запрещены. Explicit conflict policy сохраняет scene-owned engine components. Factory получает PackedScene/context и читает Template из scene instance; Template не хранит default_scene/back-reference. Existing Profile/Definition scene selector имеет одного owner, циклические Scene→Template→Scene Resources запрещены.

## Invariants

- Trait immutable/config only;
- Trait не тикает;
- Trait не хранит mutable runtime state;
- runtime Components создаются отдельными экземплярами;
- Systems не знают, каким Trait создан Component;
- Trait может require/provide capability и initial Relationship binding;
- same template + definitions + spawn context → deterministic composition;
- current `DEF_NpcTrait` gameplay quirks не смешивать с authoring `ET_*`.

Placed и spawned composition реализуются в этой задаче через один compile/validate path. GECS `_initialize` получает подготовленные fresh recipes; ready barrier и endpoint fixup предотвращают реакцию consumers на частичную композицию. Не ждать 42 для placed runtime support: 42 добавляет Inspector/preview tooling.

Project-owned World/bootstrap preparation выполняется до automatic World.initialize: explicit World build context, all placed recipes, duplicate stable/Entity IDs и endpoints проверяются **до** World.add_entity (его collision policy заменяет existing Entity). Не присваивать ECS.world ради compilation: setter немедленно вызывает deferred System.setup. Сохранить pinned registration once; затем обычное связывание ECS.world, setup только passive bindings, startup domain spawns/restore, endpoint fixup и ready до первого main_level tick. World startup gate и per-Entity composition-ready запрещают gameplay reactions до завершения reconstruction. Addons не изменяются; startup hook не regular scheduler. Factory использует тот же pre-registration gate. Fixtures доказывают отсутствие ID replacement и gameplay side effects при failed build/restore.

Scene/template/profile/instance ownership и explicit override/conflict policy заданы section 10 target proposal. Nested mutable state между двумя spawn instances изолирован; Definitions shared immutable. Restore применяет saved state поверх defaults до ready и не повторяет side effects. Требуются validation/diagnostic providers вместе с capability.

Composition manifest covers every existing procedural capability installer from inventory/migration map, including NPC/customer/trader, items/interactables and package/hazard factories. Representative examples are tests, not the migration scope limit. Native declarative scene Components/pure define_components recipes remain deliberate providers of intrinsic data/engine glue, validated by the same preparation path with an optional Template; no empty Template asset is mandatory. Reusable gameplay capability wiring migrates to Traits; old on_ready/factory/install branches for that capability disappear. Each Component/Relationship is contributed once; passing a compiled recipe plus old define_components output to GECS as duplicate overrides is forbidden. Provenance fixtures cover scene+code+Trait provider conflicts and no repeated Component-added reaction.

## Acceptance

Собрать representative templates для существующих capabilities: physical NPC, resident/customer, existing Trader и physical interactable object. C_Trader/DEF_TraderProfile уже существуют; здесь capability wiring, а не новая trade mechanic. Variant не требует ET script или global registration edit.
Compile-time validation ловит duplicate/incompatible providers и missing requirements.
Manifest is 100% closed: each installer removed/migrated or retained as a documented declarative intrinsic provider with no duplicate setup path. Package/item/hazard family fixtures join NPC/interactable parity tests; remaining scene-only recipes are part of the target pipeline, not a legacy fallback.

Positive/negative fixtures доказывают placed↔spawned parity, ordering-independent deterministic recipes, duplicate provider, missing binding, two-instance nested mutation isolation, failed-registration cleanup и load без повторного setup/HP reset. Cleanup не обещает отменить уже опубликованные wallet/dialogue/outcomes: таких effects до ready быть не должно. `World.add_entity` не вызывается дважды для placed scene. Setup, synchronous Observer callbacks и Entity.on_ready входят в startup ordering fixture.

## Validation

Template compiler tests + parser + representative spawn smoke.

## Current / Next

Started 2026-10-09 after task 47 **DONE — PASS**, commit `857ec02d`. Phase 2B strict domains remain
complete; schema 9 clock/RNG foundation is the input contract. No task-41 acceptance claimed.

Pinned lifecycle inspected: World.initialize registers Systems/Observers before placed Entities;
World.add_entity performs ID-collision replacement before Entity._initialize; Entity initialization
appends define_components and shallow-copies Component properties, then calls on_ready synchronously.
Compilation must therefore prepare/validate the whole placed set with an explicit World context before
super._ready, and factory registration must use the same pre-registration gate. Assigning ECS.world
early would finalize System.setup and expose partial state, so it is excluded from compilation.

Provider discovery includes every project-owned function that registers Entities, writes Components/
Relationships/recipes or supplies define_components/on_ready. Runtime transactions will be explicitly
distinguished from initial capability providers; no installer-name-only or representative-only scope.
Direct owners inspected: NPC brain/quirks/population/customer action wiring, package condition/content/
receiving recipe, physical slot on_ready, native character glue and existing main/GameWorld startup.

First implementation batch: `EntityRecipeRules` makes fresh Component/record/container graphs,
preserves non-export initial fields and intra-aggregate aliasing, shares immutable GameDefinitions/assets
and keeps scene Node identity bindings. Packed containers are explicitly copied; Component.parent is
left for GECS registration. ReceivingPackageFactory now uses this helper for carry recipes. There is
no mutable runtime registry and no new scheduler. Native UID/map and narrow construction-query rights
are included. This helper will be consumed by the common compiler, not an alternate registration path.

Pure flat compiler contracts are implemented: optional scene-owned DEF_EntityTemplate,
EntityTrait, typed EntitySpawnContext, initial binding intents and transient EntityBuildPlan. Scene,
code and Trait providers carry provenance; duplicates never select a last writer. Required scene
root/nodes/Components and named endpoints are validated. Component order is canonical by Script path;
Trait order cannot change the resulting provider/configuration set. Initial binding data stays fresh
and uninstalled during compilation; repeated Relationship/Entity pairs fail while distinct targets
remain valid.

EntityAuthoring is an optional scene-owned Resource stored under Entity metadata `entity_composition`.
It owns Template/immutable Definitions/local NodePath bindings, with no default-scene selector or
mutable runtime state. Native/project Entity hierarchy is preserved. EntityCompositionService reads
this configuration, captures explicit contexts, invokes the one pure compiler and hands fresh recipes
to pinned initialization. Its construction marker makes retained code providers contribute once,
without forwarding through a second Entity base. Native integration fixtures prove complete data at
passive Entity.on_ready, no duplicate Component-added reactions and no repeated preparation/reset.

GameWorld now discovers the exact pinned placed set and compiles every scene/intrinsic/optional
Template provider BEFORE super._ready/automatic World.initialize. Whole-set validation rejects duplicate
instance/Entity/stable IDs, existing registry collisions, preinstalled Components, captured identity
mismatch and endpoints outside the actual prepared set. One rejection aborts every plan before native
registration; no neighbour assigns IDs or calls Entity.on_ready. Normal ECS.world binding remains after
all placed registrations; System.setup is not invoked early. Initial binding intents are fixed up after
both endpoints have their native numeric IDs. Transient plans are cleared after this boundary.

PlacedIdentityRules creates a private identity recipe per authored actor instead of mutating a shared
prefab Resource. Invalid metadata leaves every input unchanged. Repeated validation reads existing
registered identity; changed metadata rejects before mutating its immutable contract. E_Package now
allocates opaque instance ID at runtime tree entry; recipe reads/preview no longer mutate package_id.
Main-level startup exposes structured composition reason/instance/provider diagnostics.

Current bounded validation (not task acceptance):
- whole-placed/common-service changed parser **7 files PASS**, compiler/authoring batch **19 files PASS**;
- focused GUT **65/65 PASS / 723 assertions**, including actual GameWorld registration once, deferred
  System.setup, zero registrations on provider/Entity-ID conflicts, later-endpoint fixup, native recipe
  preparation, isolation and direct GameSession/persistent-runtime/schema-9 golden regression surfaces;
- actual main headless vertical slice PASS; Night write and restore in TWO fresh processes PASS,
  preserving durable clock/seed, debt/inventory/stable physical links and prepared population;
- all three current runtime logs contain zero errors/warnings;
- structure, strict dependency/architecture, refactoring preflight and persistence baseline PASS.

Logs: `tests/artifacts/refactoring_v2_41_placed_bootstrap_parser.log`,
`tests/artifacts/refactoring_v2_41_placed_bootstrap_gut.log`,
`tests/artifacts/refactoring_v2_41_authoring_service_parser.log`,
`tests/artifacts/vertical_slice-20261009-095206666.log`,
`tests/artifacts/night_persistence-write-20261009-100335594.log`,
`tests/artifacts/night_persistence-restore-20261009-100344738.log`.
Editor import returned to the existing 6 ObjectDB/3-resource shutdown baseline with scene-owned
EntityAuthoring; new hierarchy-induced editor retention was removed. No new addon exception added.

Runtime factory batches now use the same compiler/identity gate for virtual Inventory/Commerce items,
physical stack drop/death release, ordered pickups/furniture, purchased furniture, receiving packages,
projectiles, hazards and temporary physics-grab proxies. No ownership removal, paid-order fulfillment
or reservation is committed on construction rejection. Furniture captures a validated transient plan
BEFORE Wallet apply; the synchronous aggregate-only payment contract preserves that plan until one
native commit. Existing stable/Entity ID collisions preserve the registered actor. PreparedFurniture
holds only this short-lived transaction context/plan, not runtime state or a persistent cache.

Factory-supplied data-only initial Relationship intents join Trait intents in the pure compiler:
required/foreign/duplicate endpoint checks share one provider set and report context provenance.
Projectile velocity/damage/attribution are complete before native entity_added; source and hazard-follow
bindings are fixed up through the accepted build plan. HazardFollowService retains only its passive
loss subscription for initial construction; runtime replacement remains its distinct operation.

Additional executed bounded validation (not task-41 acceptance):
- virtual item parser **4 files PASS**, GUT **51/51 PASS / 493 assertions**;
- physical Inventory/Commerce/Delivery/Furniture parser **7 changed files PASS**, GUT **120/120 PASS /
  1150 assertions**, including zero Wallet/receipt effects on stable-key rejection and both pickup /
  furniture delivery Entity-ID collisions without native replacement;
- projectile/hazard/proxy/receiving parser **9 files PASS**, GUT **202/202 PASS / 1271 assertions**,
  including factory/Trait binding conflicts, missing context endpoints, fresh binding data, complete
  projectile launch data and existing actual package/hazard/physical-grab/receiving regressions;
- structure, strict dependencies and strict architecture PASS after both factory batches;
- all three GUT runtime logs and both changed-file parser logs contain zero errors/warnings.
Logs: `tests/artifacts/refactoring_v2_41_virtual_factories_gut.log`,
`tests/artifacts/refactoring_v2_41_physical_changed_parser.log`,
`tests/artifacts/refactoring_v2_41_physical_factories_gut.log`,
`tests/artifacts/refactoring_v2_41_effect_factories_parser.log`,
`tests/artifacts/refactoring_v2_41_effect_factories_gut.log`.
Two UNCHANGED inherited GUT scripts (trader_purchase/furniture_arrival) produce identical cold parser
shutdown retention on the prior committed owner sources: 391 ObjectDB / 281 resources / 3 textures /
3 fonts. The controlled probe restored every exact current source; log
`refactoring_v2_41_inherited_parser_baseline_probe.log`. No parser diagnostic exemption added and no
broad parser PASS claimed for those cold probes; actual native GUT execution of these inherited
regressions passed cleanly. Changed test_trader_furniture parser passed cleanly.

The next discrete factory batch covers loot placement, package debris, depletion Entity spawns,
debug meat/package spawns, runtime inspection slots and quest bindings. Offer and passive quest
reconstruction use one initial-binding constructor. Offered records are appended only after accepted
construction; passive reconstruction does not append duplicates. Loot failure preserves the existing
registry actor and does not reserve geometry/publish a placed result. Source removal/debris facts and
quest offer completion follow successful native registration.
Executed: production parser **7 files PASS**; actual GUT **87/87 PASS / 953 assertions**, including
new loot collision and existing save/quest/inspection/debug/depletion surfaces; strict structure,
dependencies and architecture PASS. Logs `refactoring_v2_41_discrete_factories_parser.log` /
`refactoring_v2_41_discrete_factories_gut.log`. Actual main vertical slice
`vertical_slice-20261009-103258652.log` PASS; actual two-process loot write/restore
`safe_loot_placement-write-20261009-103351867.log` /
`safe_loot_placement-restore-20261009-103400997.log` PASS. All runtime logs have zero errors/warnings.
The initial mistyped smoke selector safe_loot matched no scene; only the actual safe_loot_placement
write/restore execution above establishes this gate.

Pure compiler field configuration now provides the explicit merge policy required by the proposal:
Trait.configuration_for returns exact Component Script/field declarations; original scene/code data
providers stay intact, and one Trait can configure each public field. Competing Trait field writers
fail even if values agree; no last-writer override. Missing providers/private/native runtime fields,
wrong scalar/custom Script Definition types and incompatible typed Array/Dictionary contracts reject
before assignment. Field provenance is transient; finalized mutable records/containers are isolated
per build while Definitions remain shared immutable. No live install hook added. This capability is
not yet substituted for the remaining procedural Profile/default installers.
Executed: field compiler parser **4 files PASS**, focused native GUT **45/45 PASS / 279 assertions**;
structure/dependencies/architecture PASS. Logs `refactoring_v2_41_initial_fields_parser.log` /
`refactoring_v2_41_initial_fields_gut.log`. Variant container methods are validated by pinned native
Godot compilation and exercised by positive/isolation/negative fixtures, not assumed from old docs.

Validated plans now capture their exact actor/World/instance ID. Batch/native registration rejects a
plan consumed by another instance/context before assigning IDs, preparing recipes or native callbacks.
Pure preview still permits no World; runtime registration_plan reports missing_world explicitly.
Executed parser **5 files PASS**, GUT **82/82 PASS / 635 assertions**, including actual furniture
transactions and passive quest reconstruction; strict structure/dependency/architecture PASS. Logs
`refactoring_v2_41_plan_identity_parser.log` / `refactoring_v2_41_plan_identity_gut.log`.

First concrete Profile Trait is implemented and now ACTIVE in the production package base scene.
The native-saved flat def_entity_package Template provides contents/liquid state and exact Health /
impact/condition defaults from the existing E_Package.package_definition export (one tuning owner).
The old code contents branch, O_PackageConditionSetup and PackageConditionService have been removed,
along with their exact scene/map/contract references. Production placed preparation, delivery/debug
factories and detached snapshot reconstruction now use the common compiler. 22 package fixture /
smoke sources use a shared test boundary that supplies instance IDs before pure compilation.
The old-provider conflict fixture is replaced by an authored duplicate-provider regression.
Native full import retains only the known 6 ObjectDB / 3 resources editor shutdown baseline
(`refactoring_v2_41_package_activation_import.log`); new test/helper UIDs are engine-generated.
Package native registration and failed-template restore regressions PASS in native GUT; publication
already sees Profile defaults and saved damaged HP/inventory quantity before entity_added callbacks.

Concrete Profile tests exposed DEF_ImpactProfile's intentional Resource base: it was incorrectly
cloned while GameDefinition subclasses were shared. EntityRecipeRules now treats canonical DEF_*
Scripts under domains/shared definitions (including their subclasses) as immutable tuning regardless
of that base, without domain imports/type registry or changes to Definition inheritance. Mutable
Resource/RefCounted runtime records still copy independently. Explicit same-reference regression added.
Executed corrected package/Definition parser **4 files PASS**, GUT **39/39 PASS / 229 assertions**,
strict structure/dependency/architecture PASS. Logs `refactoring_v2_41_package_trait_parser.log` /
`refactoring_v2_41_package_trait_gut.log`. Native UID/Template generation used pinned ResourceUID /
ResourceSaver after autoload initialization; final generation log has zero diagnostics. The initial
tool loaded typed project dependencies before ECS initialization and emitted compile diagnostics;
its corrected deferred dynamic generation overwrote only the task-owned new Template.

Latest direct prepare also checks the plan's captured actor before mutating component_resources;
wrong-actor prepare leaves the second actor unprepared. Parser **2 files PASS**, actual native placed /
prepared GUT **12/12 PASS / 96 assertions**, zero diagnostics (`refactoring_v2_41_prepare_identity_*`).
Actual main after bound-plan/Definition-reference changes PASS with zero diagnostics:
`vertical_slice-20261009-110432772.log`.

WorldSnapshotService now configures/compiles all detached fresh inputs before live mutation and
projects their complete recipes for native snapshot graph checks. Saved Components overlay defaults
before native initialization/entity_added; existing live actors receive their saved fields in the
existing suspended restore transaction. Common initial bindings fix up after all native endpoints
exist. Existing validated ID-rebind/extraneous-persistent deletion semantics remain; no native ID
collision replacement. Runtime restore readiness for all other installers is still unfinished.
Executed pre-activation restore parser 2 files PASS / GUT 82/82 PASS, 1080 assertions; the registration
callback sees saved damaged HP and inventory quantity, before any later callback/overlay. Logs
`refactoring_v2_41_restore_preflight_parser.log` / `refactoring_v2_41_restore_preflight_gut.log`.

First all-script native GUT after activation executed 96 scripts / 1344 tests: 1339 passed, 5 failed.
The standalone schedule fixture omitted the mandatory clock owner; three inherited repetitions of
a delivery collision fixture exposed shared scene reservations; one ordinary Trader interaction
fixture failed to open the panel. Calendar setup and affected native scene fixture registration
have now been migrated to the common constructor. The remaining Trader interaction fixture required
the actual UI request subscriber (DialogueUiFixture.install), which is now wired explicitly.
Do not cite this full run as PASS. It has no shutdown retention warnings, but reports the calendar
script errors and assertions above (`refactoring_v2_41_package_activation_full_gut.log`).
Strict structure/map/dependency/architecture and persistence baseline validators PASS after deletion.

Corrected full all-script native GUT executed **96 scripts / 1346/1346 tests / 11086 assertions PASS**,
zero script errors, warnings or shutdown retention. Inherited test methods are counted where executed,
not presented as 1346 distinct scenarios. Log `refactoring_v2_41_package_activation_full_gut_final.log`.
Package activation parser **8 files PASS**, strict structure/map/domain/dependency/architecture and
persistence baseline PASS. Actual main `vertical_slice-20261009-112826242.log`, Night write/restore
`night_persistence-write-20261009-112918292.log` / `...restore-20261009-112927419.log`, and loot
write/restore `safe_loot_placement-write-20261009-113004294.log` / `...restore-20261009-113013406.log`
all PASS and independently scanned with zero diagnostics.

Factory contexts now carry typed initial_fields, accepted ONLY for exact fields enumerated by enabled
Traits (initial_field_names). The common compiler rejects undeclared fields, duplicate policy owners,
Profile/factory duplicate writers and wrong types before materialization; nested records/containers
remain isolated. ET_PackageState permits shipment delivery_day/supply_key only. ReceivingDeliveryService
supplies those inputs before native registration; its old post-registration writes/required-Component
fallback have been removed. Native publication proof checks both fields alongside complete HP/defaults.
Current native GUT **116/116 PASS / 984 assertions**, zero diagnostics, including policy/conflict/nested
isolation, real receiving, package contents and snapshot reconstruction. Log
`refactoring_v2_41_factory_initial_fields_gut.log`. Strict structure/dependency/architecture PASS.

Factory-field parser compiles all **8 files** but the combined process reports **262 ObjectDB / 218
resources + 2 PagedAllocator** retention at shutdown, so it is NOT a clean parser PASS. Six production
scripts were isolated: five have zero diagnostics; ReceivingDeliveryService alone reproduces the same
retention. A controlled probe using the exact HEAD version of ONLY that owner (all other current task
changes retained) reports identical retention; the current owner was restored byte-for-byte in finally.
This proves its latest field-moving edit does not change that retention; it does NOT prove the entire
current asset/Script graph matches pre-task HEAD. Logs `refactoring_v2_41_initial_fields_isolated_*` and
`refactoring_v2_41_receiving_delivery_parser_baseline_probe.log`. No parser exemption, diagnostic mask
or addons/tool mutation was adopted. Actual native GUT above compiles and executes the owner cleanly.
Investigate broader cold-loading retention if required for the final task parser gate.
Latest initial-field diagnostic provenance now identifies context:initial_fields on rejected factory /
Profile duplicate writes. Clean parser **2 files PASS**, common compiler/prepared/placed/package /
recipe-isolation GUT **56/56 PASS / 358 assertions**, zero diagnostics. Logs
`refactoring_v2_41_factory_field_provenance_parser.log` / `...gut.log`.

Latest actual main after factory fields `vertical_slice-20261009-113813954.log` PASS, latest Night
write/restore `night_persistence-write-20261009-114048094.log` / `...restore-20261009-114057219.log`
PASS; all three logs independently scanned with zero diagnostics. No native validation processes remain.

Two inherited cold-parser prewarm/passive-instance probes did not remove baseline retention; no
parser exemption/tooling change was adopted. Actual GUT runtime remains clean.

The composition manifest currently lists 72 reviewed obligations and 73 Entity-bearing/inherited
scene sources, including global automatic GameWorld bootstrap. Three package obligations, the address factory and two NPC brain/immune installers are now resolved
with exact replacement/retained-intrinsic evidence; 64 remain unresolved. These counts do not establish full acceptance.

District address construction is now ACTIVE through the common compiler. Native-saved flat
`def_entity_npc_address` uses the existing generic EntityTrait: StaticBody3D/Address node/Component
requirements and the sole permitted C_NpcAddress.address_id field. Existing Address/Interactable /
Actions remain explicit intrinsic scene providers; no new ET script, default scene or back-reference.
The entire detached address batch validates before any registration, presentation/pose precede
entity_added, and the old late ID assignment is removed. DistrictPopulationService.initialize now
returns false on rejected address composition before roster mutation; actual main startup consumes
that failure before simulation. UID for the new fixture is native-generated (uid://cutv4gk1ai1gc).

Executed address parser **3 files PASS**, GUT **104/104 PASS / 1002 assertions**, zero diagnostics:
`refactoring_v2_41_address_batch_parser.log` / `...gut.log`. Surface includes actual address publication /
instance isolation / failed-batch cleanup, district population/lifecycle/snapshot/native BT and current
save baseline. Strict project/domain structure, move map, dependency/architecture and persistence
validators PASS. Native full editor import retains the known 6 ObjectDB/3-resource shutdown baseline,
not a new diagnostic (`refactoring_v2_41_address_batch_import.log`). Actual main
`vertical_slice-20261009-120754544.log`, Night write/restore
`night_persistence-write-20261009-121009765.log` / `...restore-20261009-121018888.log` PASS; all three
logs independently scanned with zero diagnostics. No native validation processes remain.

NPC roster/identity/Profile preparation is now ACTIVE before native registration. Pure
NpcPopulationRules preserves authored Profile order, sequential IDs and home/entry/exit assignment.
NpcConstructionService supplies detached typed inputs without consulting ECS.world. The authored
DaySession owns a flat district-roster Template; GameWorld captures fresh or validated saved roster
inputs before whole-placed compilation. Main's existing placed Trader owns the same flat NPC identity
Template as district_npc; its identity is present on its sole native registration, without a second
merchant or re-registering the placed actor. ET_NpcIdentity supplies fresh C_NpcIdentity /
C_PersistentIdentity and configures scene-owned motion from the existing immutable NPC Profile.
The single person.profile.npc_scene_path selector remains authoritative for fresh bodies.

DistrictPopulationService._spawn_body now uses common registration_plan/register_plan before native
publication and no longer adds identity or speed afterwards. It reuses an already prepared placed
body by its roster key. Invalid scene type/recipe instances are freed before publication. Roster
allocation no longer mutates a shared authored Array by appending; callers must read registered
C_District authority. The save baseline fixture now explicitly binds that Component, removing its
accidental dependency on native shallow-copy aliasing.

WorldSnapshotService projects saved district records and authored NPC keys into detached construction
inputs. Fresh restored NPCs compile the saved identity/Profile before saved fields overlay and native
publication. Actual missing-body regression proves damaged HP (37), persistent key and Profile speed
are visible in entity_added; participation reconstruction does not reset HP. These inputs are
transient, not a second runtime population registry. Saved pose/link completion and complete readiness
remain under the unfinished task-41 gate.

Executed NPC identity/startup/save parser **10 files PASS**, zero diagnostics:
`refactoring_v2_41_npc_identity_final_parser.log`. Coupled native GUT **140/140 PASS / 1369 assertions**
across ten scripts, zero engine/GUT diagnostics: `refactoring_v2_41_npc_identity_coupled_gut_final.log`.
Includes real Profile/roster parity, complete identity at native publication, missing-input rejection,
whole-batch duplicate-key rejection, existing placed merchant registration, fresh NPC reconstruction,
district lifecycle/native BT and current-format golden roundtrip. Initial diagnostic runs exposed the
missing fixture inspection-slot authored ID, an incorrect test selector, and the baseline fixture's
stale pre-registration Component reference; all corrected, no validator exemption or golden rewrite.
Native fixture UID generated with ResourceUID API (uid://cw8wodpd6ed1a); exact temporary generator
removed. Strict project/map/domain/dependency/architecture/persistence checks and git diff --check PASS.

Actual main `vertical_slice-20261009-122846783.log` and two-process Night
`night_persistence-write-20261009-123340830.log` / `...restore-20261009-123349959.log` PASS, all logs
independently scanned with zero diagnostics. Full current native GUT before the subsequent brain migration: **98 scripts / 1359/1359 tests /
11169 assertions PASS**, zero diagnostics (`refactoring_v2_41_npc_identity_all_gut.log`).

NPC brain capability migration is now ACTIVE in the same flat district_npc / placed Trader Template.
ET_NpcBrainState provides fresh Awareness/Decision/resistance and configures scene-owned combat from
immutable Profile attack Definitions. Fire immunity is compiled before publication. Old
NpcBrainService.install and NpcTraitService.install are removed; bind_engine only attaches the passive
manual BTPlayer after existing role bridges bind. No recurring cadence capability repair remains.
Existing explicit aura/refuge runtime operations and scheduled trait behavior retain their owners.

Explicit brain reset retains Awareness/Decision Component instances, clears their transient data,
advances C_NpcDecision.lifecycle_generation and retains HP/inventory/durable population authority.
Queued Perception/Traits/Decision/Route callbacks capture that generation, and the decision stage
rechecks it after its synchronous role-clock fact. Thus a newer due interval in the same calendar
phase cannot resurrect an older callback. C_NpcRoute remains removable computed runtime route state;
there is no second decision authority or saved generation. Native runner binding/reset remains
explicit and passive, not a Trait install hook or scheduler.

Executed this brain batch: parser **15 files PASS**, native coupled GUT **126/126 PASS / 1208 assertions**,
zero diagnostics (`refactoring_v2_41_npc_brain_trait_parser.log` / `...gut.log`). Includes immunity map
isolation, complete brain/combat data at publication, same-Component reset retaining HP, all four real
queued stages rejected after reset despite a valid new interval, district lifecycle/native BT,
fresh/in-place NPC restore, current save golden and queued-owner lifetime. Strict project/dependency /
architecture validators and git diff --check PASS. Native authoring UID uid://bx06h57gdvgkb.
Actual main `vertical_slice-20261009-124843963.log`, Night
`night_persistence-write-20261009-124928265.log` / `...restore-20261009-124944533.log` PASS, each independently
scanned with zero diagnostics. No native validation processes remain at this update.

Resident/merchant role composition is now ACTIVE. ET_NpcRoles provides fresh Inventory/Hunger/actions;
its explicit Provider selection either supplies merchant data or requires the existing authored scene
providers. The common district_npc Template uses TRAIT providers; a separate flat district_trader
Template uses SCENE Trader/action providers. No Template inheritance, default_scene or silent fallback.
Placed Trader keeps its sole authored C_Trader.profile and immutable authored trade action list; the
Trait appends the external immutable street action once. Generic spawned merchant uses the existing
Trader Profile Definition and an external trade action. Street action explicitly preserves the old
INTERACT slot/priority 5. Hunger policy remains the authored default and starting value comes from
explicit district Definition inputs, supplied by fresh/placed/saved construction contexts.

FurniturePickup is scene-owned: the existing Trader/main overrides are retained; district_npc now
has the former spawned-merchant pickup pose (2,0,0) as an authored Marker3D. The Trait validates it
for merchant capability and never creates nodes. DistrictPopulationService._install_roles and all
callers are removed. _spawn_body performs no late identity/role Component writes; accepted common
registration is followed only by existing presentation and passive native brain binding. Saved hunger
73, damaged HP 37, Inventory and actions are present at fresh entity_added and survive participation
fixup without repeating defaults.

Executed role batch: **5 owner files parser PASS** / zero diagnostics
(`refactoring_v2_41_npc_roles_owner_parser.log`). Native coupled GUT **125/125 / 1276 assertions PASS**
across nine scripts (`refactoring_v2_41_npc_roles_coupled_gut.log`), role fixture first, zero diagnostics.
All nine individual role methods and the complete role script independently pass in clean native
processes. Includes scene/Trait inventory conflict, missing SCENE provider rejection, existing Profile /
action Definition preservation, spawned merchant marker, native publication, saved hunger/inventory,
district/native BT, Trader furniture transactions and current-format save golden. Minimal inherited
Trader fixture uses the actual scene/root script/Template; it does not load the whole detached level.
Native authoring UID uid://bpcjvv4f88op7. Strict project/dependency/architecture and git diff --check PASS.

Parser/loader limitation remains OPEN: MorningTruck before the role fixture reproduces shutdown
retention (476 Objects / 322 resources / textures/fonts/Variant pages) despite 22/22 passing assertions;
the same complete scripts in reversed order exit cleanly. Retaining the fixture scene through preload
and giving it real tree enter/exit do not remove that order dependency. Every individual method and
role script alone exit cleanly. Verbose evidence `refactoring_v2_41_npc_roles_retention_verbose.log`;
method/order probes `...roles_method_*` / `...roles_order_probe.log`. No addon edits, diagnostic mask,
validator exemption or reduced assertions adopted. This remains an unresolved final acceptance concern,
not proof of order-independent full-suite validation.

The six-file parser also compiles the inherited test_district_snapshot child but its cold process
retains 340 Objects / 233 resources / fonts/Variant pages, so **that combined parser is FAIL**, not a
clean PASS (`refactoring_v2_41_npc_roles_parser.log`). Changed production/role fixture owners are clean
in the five-file parser above and actual NPC snapshot runs cleanly in coupled GUT. Resolve cold loader
retention before claiming the entire task parser/acceptance gate.

Actual main `vertical_slice-20261009-131939377.log` and separate-process Night
`night_persistence-write-20261009-132011329.log` / `...restore-20261009-132026574.log` PASS; all three
logs independently scanned with zero diagnostics. No task validation runtime remains at this update.

Manifest now **8/72 resolved**, **64 remaining**. Whole population construction still commits roster /
addresses before all body recipes are accepted; failed complete population builds must become atomic.
Complete world/per-Entity readiness, remaining customer/factory providers and loader limitations also
remain under the full task-41 acceptance gate. No task completion or task-41 commit claimed.

Next: make initial/replacement population preparation transactional: validate all detached address/body
contexts/plans before any registration, roster/ID/history mutation or presentation; reuse accepted placed
bodies without re-registering them. Then migrate customer actions/role capability providers and the
remaining factories, establish complete defaults/saved-overlay/endpoint/ready ordering, resolve loader
retention and close ALL manifest obligations before the coherent task-41 commit. Task 41 remains
IN_PROGRESS; 42 not started. No old-save migration, rendered gameplay or subjective visual QA.


## Physical-slot initial binding batch

E_PhysicalSlot.on_ready no longer installs R_SlotMountedOn. Its two native scene variants author a
flat physical_slot Template with required slot data/support nodes and an optional mount intent.
EntityAuthoring explicitly declares named ancestor Entity endpoints; common pure context capture
preserves the nearest-parent Entity contract across ordinary intermediate nodes. Duplicate/empty
endpoint authors reject before intrinsic compilation; complete set/World validation rejects foreign
endpoints. Freestanding slots intentionally have no mount. Runtime binding uses the shared validated
registration/fixup path and fresh relation data; it is not an additional Entity callback installer.

Native regression checks nested scene ancestry, pure no-live-state preview, one registration/binding,
shared prototype isolation, optional freestanding mount, missing anchor rejection and ambiguous
endpoint rejection. Fixture teardown now calls pinned World.purge before free to break archetype
transition-edge reference cycles; the prior 24-object/13-resource leak was diagnosed and eliminated.
Current ongoing task-41 worktree validation: coupled compiler/registration/slot/CharacterBody/Customer/
melee native GUT **94/94 / 662 assertions PASS**, zero diagnostics; changed owner/fixture parser
**6 files PASS**, final inspection fixture parser **1 file PASS**. Actual main vertical_slice,
physical_slots_placement, customer_inspection and independent Night write/restore PASS; all final
logs independently scanned with zero diagnostics. The navigation/parcel inspection fixture disables
all district footsteps to isolate accelerated physical validation; audio playback is not claimed as
validated. Strict project/domain/map/dependency/architecture/persistence/preflight and local Formatter
checks PASS. Self-review is non-independent and confirms one mount authority, immutable authoring,
fresh mutable bindings, unchanged authored exports/hierarchy and rejection without publication.

Evidence: `.artifacts/refactoring_v2_41_slot_final_gut.log`, `...slot_parser.log`,
`...slot_inspection_parser.log`, `...slot_finish_runtime.log`. Latest clean native logs:
`vertical_slice-20261009-151240294.log`, `physical_slots_placement-20261009-151250715.log`,
`customer_inspection-20261009-151542812.log`, `night_persistence-write-20261009-151555224.log`,
`night_persistence-restore-20261009-151605356.log`.
This is a bounded initial-provider milestone, not task-41 completion. Task remains IN_PROGRESS;
full manifest, complete ready/saved-overlay/fixup barrier and inherited cold-loader retention are
still pending. Next: session loot queue, package-content/Profile providers, then complete ready gate.


## Receiving carry Profile milestone

C_Grabbable.throw_velocity now derives from the package Definition through ET_PackageState's
explicit field compiler; missing carry data rejects before registration. ReceivingPackageFactory
only captures detached identity/Profile inputs and body-owned mass, with no recipe duplication or
Component rewrite. Tests inspect native publication, source prototype isolation and missing-provider
rejection. Self-review is non-independent; one Profile owns defaults and no compatibility branch
remains for this field.

Executed: changed parser **3 files PASS**; native package Profile/morning truck/receiving limits/
delivery completion GUT **71/71 / 586 assertions PASS**, zero native diagnostics. Actual truck smoke
**write and restore PASS in independent processes**, logs `morning_truck-write-20261009-155835962.log`
and `morning_truck-restore-20261009-155845092.log`. The runner's missing truck restart registration
was fixed independently in **e15b66ae**, with the existing native diagnostic regression PASS.
Separate `receiving_scan-20261009-155855501.log` is **FAIL**: historical smoke removes a required
CustomerFlow Component, still assumes eight/16 supplied boxes and a RigidBody player; the current
main contract supplies five and keeps its required session aggregate. This smoke must be migrated
before broad acceptance; the failure is not waived or reported as gameplay QA.

Evidence: `.artifacts/refactoring_v2_41_receiving_profile_parser.log`,
`...receiving_profile_gut.log`. This is a coherent initial-provider milestone inside task 41.
Task remains IN_PROGRESS, with complete startup/saved-overlay/endpoint-ready gates and remaining
manifest providers pending. Cold inherited parser and separate native golden retention remain OPEN.


## Global fresh/restored startup readiness milestone

GameWorld's native add_observer override suspends every placed and later startup Observer, preserving
its previous activity. The separate startup-observer registration branch is removed; normal pinned
registration is the sole entry. One shared ObserverReactionBoundary owns silent derived monitor
membership reconstruction for both global startup and snapshot restore; nested scopes preserve
inactive startup observers. GameWorld.process holds every scheduled group until accepted global
readiness. Failed placed builds still publish no ready and perform no native registrations.

Passive population participation now synchronizes Entity.enabled with authoritative saved/default
placement before readiness. This removes the initial HOME/enabled disagreement that rejected an
otherwise valid immediate snapshot. The level submits unprepared morning work only after ready,
through the existing typed request and O_DistrictLifecycle scheduled owner. Scheduled planning was
not moved into a Service. Real panel fixture teardown waits for queued UI cleanup rather than
leaving 46 detached row nodes pending.

Executed final native parser **6 owner/fixture files PASS**, then **3 final route files PASS**;
actual placed/bootstrap/fresh+saved startup/snapshot GUT **35/35 / 356 assertions PASS**, zero
native diagnostics and no reported orphans. Fixtures prove native/late Observer suppression,
no initial match replay, normal future dispatch, passive deferred setup, withheld first System tick,
accepted tick after ready and preserved saved HP. Actual main vertical_slice **PASS** and Night
write/restore **PASS in independent processes**, final logs independently scanned by the strict
runner: `vertical_slice-20261009-162258525.log`, `night_persistence-write-20261009-162308973.log`,
`night_persistence-restore-20261009-162318075.log`. Truck write/restore also PASS after participation
fix, logs `morning_truck-write-20261009-161922762.log` / `...restore-20261009-161931880.log`.
Actual local Formatter **44 files PASS**; project/domain/map/strict dependencies/strict architecture,
persistence baseline, preflight and incremental agent-change checks PASS. Headless editor import
created native UIDs/class cache; its prior 6 ObjectDB/3-resource exit diagnostics remain, so import is
not claimed as a clean validation gate. Self-review is non-independent, includes direct composition
subscriptions and native add_observer interception; no addon mutation or gameplay replay introduced.

Evidence: `.artifacts/refactoring_v2_41_fresh_startup_final_parser.log`,
`...startup_gate_final_parser.log`, `...startup_gate_final_gut.log`, `...boundary_import.log`.
This closes the global startup gap, not complete task-41 acceptance. Per-Entity factory readiness,
placed saved overlays/native initial callbacks, remaining providers, legacy receiving_scan migration
and inherited cold/golden retention still need work. Manifest remains **14/72 resolved** in the
ongoing worktree. Task 41 IN_PROGRESS; 42 and Phase 3 have not started.

Placed saved-state construction milestone (task 41 remains IN_PROGRESS):
- Authored actors resolve saved entity IDs and overlay durable fields onto fresh compiler recipes
  before pinned native initialization. Accepted saved poses reach the physical owner before on_ready
  and entity_added. The detached restore path shares the same field overlay operation.
- Whole snapshot compatibility now precedes placed recipe/ID/pose commits; a valid saved pose for a
  non-spatial authored actor rejects with invalid_saved_composition and zero registrations/callbacks.
- An empty pending scene-handoff sentinel no longer masks an explicit automatic startup slot.
- Native parser 4 changed files PASS; GUT 34/34 PASS, 394 assertions; strict dependencies, architecture,
  project/domain structure, migration map, persistence baseline and formatter PASS (41 incremental
  files, local .bin/gdscript-formatter.exe). No runtime warnings/errors in these native gates.
- Actual main Night write/restore in TWO new headless processes PASS, logs
  tests/artifacts/night_persistence-write-20261009-164450717.log and
  tests/artifacts/night_persistence-restore-20261009-164501908.log. Focused logs:
  tests/artifacts/refactoring_v2_41_placed_saved_state_parser.log /
  tests/artifacts/refactoring_v2_41_placed_saved_state_gut.log.
Remaining: per-Entity readiness with endpoint fixup, fresh-spawn saved pose ordering, complete provider
manifest migration and task-41 acceptance. No Phase 42/3 started, no old-save conversion or visual QA.

Per-Entity ready/reconstruction milestone (task 41 remains IN_PROGRESS):
- One derived Entity readiness marker stays false through native registration and endpoint fixup.
  Placed actors publish it when accepted startup finishes; restored actors publish it after saved
  fields, physical state, relationships, participation and passive derived bindings are rebuilt.
- Runtime factory registration captures native ADDED/RELATIONSHIP_ADDED subscription matches at
  their original event, holds gameplay Observer callbacks, then delivers them once with complete
  data/bindings and readiness. Final monitor matching occurs only after readiness. Re-matching all
  Components at the end would duplicate multi-Component on_added effects; that shortcut is excluded
  by an actual native fixture. Inactive startup/restore Observers retain their captured activity.
- Fresh restored physical instances receive their saved pose after native tree entry and BEFORE
  the one World.add_entity call; actual publication proves saved HP, quantity and pose are complete.
- Native parser 7 files PASS; focused GUT 58/58 PASS / 679 assertions; Inventory death/ownership and
  combat attribution GUT 19/19 PASS / 133 assertions. All these native logs have zero warnings/errors.
- Actual main vertical_slice PASS and Night write/restore in TWO new processes PASS, logs
  tests/artifacts/vertical_slice-20261009-165806305.log,
  tests/artifacts/night_persistence-write-20261009-165817468.log and
  tests/artifacts/night_persistence-restore-20261009-165826594.log.
- Strict dependencies/architecture/domain structure, project structure, migration map, persistence
  baseline, refactoring preflight and local Formatter PASS (43 incremental files). Focused logs:
  tests/artifacts/refactoring_v2_41_entity_ready_parser.log,
  tests/artifacts/refactoring_v2_41_entity_ready_gut.log and
  tests/artifacts/refactoring_v2_41_ready_inventory_gut.log.
Remaining task-41 acceptance: complete provider/factory manifest audit and migration, all runtime
construction paths and rejection invariants, full relevant acceptance including known failing native
shutdown/legacy receiving surfaces. These bounded passes do not close task 41 or authorize Phase 42.

Receiving acceptance tooling repaired (task 41 remains IN_PROGRESS):
- receiving_scan now uses actual main's authored batch limit (5 then 10 total), CharacterBody player,
  persistent CustomerFlow and current arrival receipts (all arrivals exist before numbered scans).
- It physically unloads boxes outside the native cargo volume, uses the real START_SHIFT /
  FINISH_SHIFT / SLEEP gates, waits for departure, blocks all actual new-truck cargo candidates,
  then proves resumed second-day supply. Scanner reacquisition follows the real Night held-item reset.
- Preserved checks: native input pickup/use, scan range/aim rejection, duplicate scan identity,
  terminal number/tag state, unchanged older package pose, number release/reuse and no duplicate
  receipts. Test uses only its own receiving_scan_smoke.pvzh slot and drains queued UI nodes.
- Actual headless receiving_scan PASS, zero runtime warnings/errors:
  tests/artifacts/receiving_scan-20261009-171446639.log. Changed-script parser 1 file PASS, formatter
  39 incremental files PASS and project structure PASS. Parser log:
  tests/artifacts/refactoring_v2_41_receiving_scan_parser.log. No rendered/subjective QA executed.
This closes the previously recorded legacy receiving smoke failure, not full task-41 acceptance.
Complete provider manifest migration/audit and remaining native shutdown gates are still open.

Session capability milestone (task 41 remains IN_PROGRESS):
- Shared boundary_trace and package session_loot_queue Traits compile fresh mutable Components
  before native publication in actual main and primitive levels. MainLevel asserts its required
  diagnostic recipe; LootDropService.current reads its required queue without a lazy installer.
- Native GUT 34/34 PASS / 393 assertions proves actual-level prepublication, withheld readiness,
  repeated reads without component events and isolation of trace history and queue runtime state.
  Parser 2 changed scripts PASS. Logs: tests/artifacts/refactoring_v2_41_bootstrap_trace_gut.log
  and tests/artifacts/refactoring_v2_41_bootstrap_trace_parser.log.
- Actual vertical_slice PASS (vertical_slice-20261009-173207325.log); Night write/restore PASS in
  two new processes (night_persistence-write-20261009-173218495.log /
  night_persistence-restore-20261009-173227628.log). Native gates have zero warnings/errors.
- Local .bin/gdscript-formatter.exe is available: actual incremental formatter/lint PASS for
  40 changed GDScript files, no NOT_RUN. Project/domain/map/strict dependencies/architecture,
  persistence baseline and refactoring preflight PASS.
Provider manifest now 16/72 resolved in the ongoing worktree. Complete provider migration/audit
plus remaining native shutdown acceptance failures still require work; 42 and Phase 3 not started.

Physical/package/customer capability milestone (task 41 remains IN_PROGRESS):
- Physical impact inboxes now come from one immutable Trait in authored flat Templates;
  S_Impact binds native reporting to required existing data. Duplicate receiver/inbox providers
  are removed while retained authored Profiles remain the tuning owner.
- Eight package-content variants compile fresh impact/hazard data from scene exports before
  publication; the old Entity define_components provider is removed. Loot preflight rejects
  incomplete recipes before committing the source manifest.
- Standalone customers and district role action sets use authored immutable action Definitions.
  CustomerActionRecipe and its late installers are deleted; entering a transient resident visit
  preserves the compiled action aggregate. Failed customer builds leave visit/history untouched.
- Native production/helper parser 11 files PASS; actual content/registration/loot GUT 53/53 PASS
  / 669 assertions and NPC/customer role GUT 78/78 PASS / 517 assertions, with zero native diagnostics.
  Logs: tests/artifacts/refactoring_v2_41_capability_owners_parser.log,
  ...capability_content_gut.log and ...capability_roles_gut.log. Actual main/Night restart smoke
  for this unchanged implementation batch already PASS in the preceding session milestone.
- Local Formatter PASS for 38 changed GDScript files; project/map/strict dependency/architecture
  and staged agent checks PASS. Native user UID/serialization edits remain unstaged and preserved.
This commits the four previously pending manifest resolutions: committed coverage is now 16/72.
Task-level cold parser/golden shutdown failures remain open: exact cold remains round-trip plus
its setup reproduces retention, while GUT base, individual dependencies and other test functions
compile cleanly. No warning exemption, addon edit or load-order workaround added. Complete provider
audit, address persistence batch and full acceptance are still required before task 42.

Stable address persistence milestone (task 41 remains IN_PROGRESS):
- Schema 10 serializes only C_NpcAddress.address_id and rejects empty, duplicate, unknown or
  non-home keys before live mutation. Detached restoration compiles the saved key and rebuilds
  its authored label before native publication; the population factory shares these operations.
- Current native snapshot/codec inventory and durable persistence documentation are updated.
  Unsupported old versions remain protected; no old-save migration is implemented.
- Actual production parser 7 files PASS, log
  tests/artifacts/refactoring_v2_41_address_owners_parser.log. District/snapshot/codec/golden GUT
  has 49/49 functional tests / 777 assertions, but OVERALL FAIL: native shutdown reports 683
  ObjectDB / 508 resources, Jolt/render/font RIDs and allocator pages. Log
  tests/artifacts/refactoring_v2_41_address_persistence_gut.log. This is not an acceptance PASS.
- Cold failure is localized to the remains save/load function combined with setup. Minimal GUT
  base, direct owners, each direct global class, individual setup constructors, other test functions
  and the snapshot call alone compile cleanly. Uncached fixture loading and codec static_unload
  do not fix it. Transient codec schema lookup reduces retention but still FAILs (359/249).
  All temporary owner edits were reverted to exact pre-trial bytes; no production workaround added.
Remaining: complete provider audit and native shutdown acceptance fixes. Task 41 and the goal
through PASS49 remain active; task 42/Phase 3 and rendered gameplay/visual QA have not started.

Initial NPC route capability milestone (task 41 remains IN_PROGRESS):
- Provider audit found S_NpcRoute._progress_route incorrectly classified as a runtime transition:
  it installed C_NpcRoute on the first scheduled tick. The existing NPC brain Trait now provides
  a fresh route before native publication; scheduled progression only uses required existing data.
- District brain reset previously removed the route. It now clears derived paths/map/clock fields
  on the same Component, retaining the construction contract through participation and restore.
  Native brain binding requires it. Queued-route fixture checks post-departure state and identity.
- Native changed parser 7 files PASS; GUT 123/123 / 777 assertions PASS across identity/publication,
  scheduling, actual native route budgets and district planning. New fixtures prove private route
  buffers and reset without Component-added/removed events. Logs:
  tests/artifacts/refactoring_v2_41_route_final_parser.log / ...route_final_gut.log.
- Actual vertical_slice PASS (vertical_slice-20261009-183213885.log); Night write/restore in two
  new processes PASS (night_persistence-write-20261009-183225053.log /
  night_persistence-restore-20261009-183234225.log). All final native gates have zero diagnostics.
- Local Formatter 7 files PASS and strict dependencies PASS. Manifest is now 17/72 resolved.
Full factory/runtime provider closure and native cold/golden shutdown failures remain required
for task-41 acceptance; task 42 and Phase 3 have not started.


### Physical stack factory rejection audit — 2026-10-09

Inventory death release and paid pickup delivery now keep the original instantiated Node through
root validation and free every rejected instance. Enabled physical collider and explicit stack recipe
are required before registration/source removal or fulfillment. Missing resources reject without
engine load errors; a missing stack never materializes an empty item. The common compiler remains the
sole registration gate. Death-drop publication sees the complete replacement stack while source
ownership still exists, then removes the source exactly once.

Native GUT **28/28 PASS / 488 assertions**, including all malformed-root/body/recipe/resource cases
with zero new orphan Nodes and retained ownership/quantity/pending order/receipts/payment/registry.
Final changed parser **4 files PASS**, actual local Formatter **4 files PASS**, structure, strict
dependency/architecture and incremental agent checks PASS. Actual inventory smoke and furniture
arrival write/restore in **two independent processes PASS**, zero errors/warnings.

Logs: `refactoring_v2_41_factory_rejection_final_parser.log`,
`refactoring_v2_41_factory_rejection_final_gut.log`, `inventory-20261009-184936184.log`,
`furniture_arrival-write-20261009-184951431.log`,
`furniture_arrival-restore-20261009-185006603.log` under `tests/artifacts/`.

Manifest rows `drop`, `release_on_death`, `fulfill_one` are closed; **20/72** resolved.
Task 41 remains IN_PROGRESS: finish all remaining provider audits and full acceptance, including
unresolved cold/shutdown retention. No task-42 or Phase-3 work started.


### Saved runtime marker construction — 2026-10-09

The shared construction overlay now prepares death, private package ink, original anchor release
snapshot and completed NEVER action progress before native registration/on_ready. Saved anchor freeze
is applied on the physical owner before publication. Fresh restore no longer rebuilds/replaces these
markers after publication; in-place reconstruction uses the same data helpers while observers are
quiet. Definitions remain immutable; saved packed ink points are copied and terminal/progress records
are private. Endpoint restoration and passive cache reconstruction still precede final readiness.

Actual placed native on_ready/publication sees the full saved terminal state. Fresh dead marked parcel
publication sees zero health/death/ink; final ink revision proves no second initial application. Fresh
anchored furniture publication sees its freeze and original release settings; the exact snapshot
instance survives the remaining restore boundary. Existing damaged-health, no duplicate setup,
whole-batch rejection, ID safety, endpoint and prolonged-action regressions remain clean.

Final parser **4 files PASS**, local Formatter **4 files PASS**, native GUT **81/81 PASS / 795
assertions**, structure/strict domain/dependency/architecture, agent/preflight checks PASS. Actual
Night write/restore in **two independent native processes PASS**, zero errors/warnings.
Logs under `tests/artifacts/`: `refactoring_v2_41_saved_markers_final_parser.log`,
`refactoring_v2_41_saved_markers_final_gut.log`,
`night_persistence-write-20261009-190321065.log`,
`night_persistence-restore-20261009-190336265.log`.

Completed-progress restore, whole snapshot restore, GameWorld bootstrap and authored identity
providers are closed; manifest **24/72** resolved. This is provider migration evidence, not full task
acceptance: remaining provider audits and known cold/shutdown retention still keep 41 IN_PROGRESS.
Next remains 41, then the declared dependency order through PASS 49; Phase 3 is excluded.


### Remaining Customer fixture callers and full regression rerun — 2026-10-09

Full current GUT first exposed 17 failing tests in four remaining callers that registered a raw
standalone Customer scene and depended on the removed define_components installer. Handoff,
outcome/challenge, debug-HUD and hunger-perception fixtures now compile the selected visit policy
and visit ID before native publication through the production gate. One test helper shares the
common validated registration; no legacy production installer or compatibility path returned.

Changed parser **5 files PASS** and actual local Formatter **5 files PASS**. Full explicit current
GUT **98 scripts / 1415/1415 tests / 11960 assertions PASS**, with **zero native/GUT diagnostics**.
Log: `tests/artifacts/refactoring_v2_41_complete_after_callers_gut.log`. Initial failing full-suite
log remains `refactoring_v2_41_complete_current_gut.log` for diagnosis.

The bounded four-script rerun executes **20/20 / 201 assertions**, but remains **overall FAIL**
on native shutdown: 749 ObjectDB instances, 530 resources and Jolt/material/shader/mesh/texture/font
RIDs/allocator pages are retained. Log: `refactoring_v2_41_remaining_customer_callers_gut.log`.
No warning exemption or load-order workaround adopted. This cold/shutdown acceptance remains
pending independently of the clean full suite; 41 remains IN_PROGRESS, next provider audit/retention.


### Complete procedural provider classification — 2026-10-09

All **72/72** frozen structural writers are now explicitly resolved. Every remaining method and
its construction caller was audited: factories use the common compiled registration gate and reject
without replacing existing actors/committing source removal, wallet, visit, order or reservation
facts; retained valve/debris recipes are deliberate fresh intrinsic data providers with no second
native contribution. Runtime Relationships, transient customer roles, terminal death/anchoring/
protection and per-action progress are explicit operations on existing compiled capabilities.
C_CartDriver is a documented derived reverse lease cache; the Relationship remains authority.
No runtime tick or role transition repairs missing reusable capability; no generic waiver adopted.
Each manifest row records its actual operation/provider resolution.

Evidence: full current native GUT **98 scripts / 1415/1415 / 11960 assertions PASS**, zero diagnostics
(`refactoring_v2_41_complete_after_callers_gut.log`). Current schema/identity/compiled defaults/
bindings/failure cleanup are covered together with actual damage, inventory, customer, interaction,
NPC scheduling, package/hazard, receiving, quest and save/load surfaces. Strict validators remain PASS.

**Task 41 remains IN_PROGRESS**, despite complete provider classification: its separately documented
cold/inherited parser and bounded native shutdown resource retention are not waived. Next: isolate
the concrete Script/resource reference cycle and complete this remaining acceptance; then 42.

## Review findings

Recovery audit (2026-10-09): task 41 remains **IN_PROGRESS**.

- Last task-41 checkpoint: `da636b0c5c46cd82260e58db1a508ca00f531fb8`.
- Current audit HEAD: `a95d10e7d01dbb513788289f6771d41dbefb58d8`.
- Original task baseline: `857ec02d7703eab840dbf496730be48d29294d99`.
- Previous review: **NOT_RUN (result unavailable)**. Neither this task's committed/current
  contents nor the available local session records contain the previous reviewer ID, exact
  snapshot pair, provisional findings, Main acceptance decisions or fix/test evidence. This
  does not establish that a previous review never ran; its outcome cannot be recovered or
  represented as PASS. No historical RV IDs or FIXED statuses are invented.
- `collaboration.list_agents` showed only Main before replacement dispatch. Exactly one
  replacement child was started: `/root/review_task41_checkpoint`.
- Replacement snapshot: BASE_SHA=`857ec02d7703eab840dbf496730be48d29294d99`,
  TARGET_SHA=`da636b0c5c46cd82260e58db1a508ca00f531fb8`.
- GECS snapshot at both revisions: `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`;
  exact commit object is available in `addons/gecs`. Reviewer reads dependency contracts
  with `git -C addons/gecs show <pinned SHA>:<path>`, not mutable addon files.
- Initial replacement snapshot result: **TRIAGED — ARCHITECTURE FAIL** (RV-001, now fixed below).
  Read-only bounded review of
  compiler/fresh recipes, common registration, identity/endpoints, startup/observer readiness
  and saved-state construction. It is not full provider-by-provider task acceptance. The
  reviewer uses Git snapshots, does not write tasks/code or run tests/Godot/MCP.
- The checkpoint-to-audit-HEAD diff changes review policy/documentation/tool tests only;
  no runtime source or gameplay tests changed in that committed range. Mutable worktree
  definition/config/manifest edits remain separate and preserved.

Current validation evidence was read, not rerun: the saved full suite reports 1415/1415;
the bounded Customer run reports 20/20 but leaks 749 Objects/530 resources, and the address
run reports 49/49 but leaks 683 Objects/508 resources. These diagnostic failures remain open.
Different failing fixture graphs are separate symptoms; a shared root cause is not established.
No review PASS, fix verification or task completion is inferred from functional test counts.

### Canonical triage

Reviewer `/root/review_task41_checkpoint` completed the pinned review above. Its single provisional
R1 is mapped to RV-001; unknown/renamed action, changed reset policy, wrong container/element types
and duplicate IDs are triggers of the same validation-before-materialization contract, not separate
findings. No other material finding was reported in the bounded scope. Reviewer STYLE PASS is
static assessment only; reviewer VALIDATION is NOT_RUN.

- **RV-001 | P1 BUG | FIXED**
  - Source: `da636b0c5c46cd82260e58db1a508ca00f531fb8`,
    `content/domains/persistence/services/world_snapshot_service.gd`, `_overlay_saved_markers`,
    lines 552–563; `PersistentInteractionState.recipe_for`, lines 44–46.
  - Evidence: `can_restore`/`restore` prepare and overlay fresh recipes before
    `SnapshotGraphRules.valid_entities` checks `completed_actions`. Unknown IDs or changed NEVER
    policy reach the mandatory timing assertion; malformed containers/elements are consumed before
    rejection. The same overlay is used by placed bootstrap. Runtime reproduction NOT_RUN at triage.
  - HEAD check: affected sources are unchanged at `a95d10e7d01dbb513788289f6771d41dbefb58d8`;
    finding remains current. No existing fix SHA or verification was found.
  - Owner: Main, task 41. Fix: validate container/types/uniqueness and authored NEVER timing against
    the final compiled action set before materializing saved progress; reject through the existing
    construction result. Keep assertions for validated synchronous recipe construction.
  - Verification required: fresh restore and placed overlay negative cases, unchanged
    World/registry/ownership/payment/IDs, no native diagnostics or orphan Nodes; changed parser,
    formatter/static gates and one bounded fix re-review.
  - Fix SHA: `bed9908d38a709f8f565a7a3ced60f78e1980ac2`.
  - Verification completed: native GUT 61/61 / 657 assertions, parser 4/4, formatter 4 files,
    agent/staged/strict architecture and final structure PASS; bounded independent fix re-review
    FIX VERIFIED / ARCHITECTURE PASS. Runtime/formatter checks were performed by Main only.

Cold/shutdown retention remains a separate
unresolved task acceptance gate; no shared root cause with RV-001 is claimed.

### Bounded repair checkpoint

RV-001 fix is implemented: saved completed-actions container, element types, uniqueness and
authored NEVER timing are checked against the final compiled action set before runtime markers
are materialized. Existing Entity validation delegates to the same pure check. Rejection uses the
existing overlay result for both fresh and placed construction; validated recipe assertions remain.

- Actual focused native GUT: **61/61 / 657 assertions PASS**, three scripts; no native/GUT
  errors, warnings or new orphan Nodes. Covers wrong container/element types, unknown/repeatable
  action, duplicate IDs, changed authored reset policy, retained registry/World/calendar/wallet
  and placed overlay without marker installation. Existing saved-state/publication regressions pass.
- Final native changed parser: **4/4 PASS**, no diagnostics.
- Actual incremental GDQuest formatter/lint: **4 files PASS**; incremental agent and strict
  architecture validators PASS.
- Initial project-structure validation FAIL exposed a separate current-HEAD policy task defect,
  recorded below. After its metadata repair, project-structure validation **PASS**.
- Logs: `tests/artifacts/refactoring_v2_41_rv001_gut.log` and
  `tests/artifacts/refactoring_v2_41_rv001_final_parser.log`.
- Fix re-review cycle 1: **TRIAGED — FIX VERIFIED / ARCHITECTURE PASS**.
  BASE_SHA=`a95d10e7d01dbb513788289f6771d41dbefb58d8`,
  TARGET_SHA=`bed9908d38a709f8f565a7a3ced60f78e1980ac2`.
  The same finished reviewer was reused; no concurrent second reviewer. No new material finding
  in the R1 fix scope; reviewer STYLE PASS is static and VALIDATION NOT_RUN. No second repair cycle.

- **RV-002 | P2 | FIXED**
  - Origin: Main's required structure gate, not replacement reviewer R1.
  - Source: `a95d10e7d01dbb513788289f6771d41dbefb58d8`,
    `agent_tasks/parallel_review_pilot.md`, status/section headers. File was unchanged when
    the gate failed: unsupported READY_FOR_PILOT and missing authoritative Task state sections.
  - Contract: normalized task status and Goal/Current/Validation/Owner QA sections.
  - Repair: IN_PROGRESS plus one Task state block; record the actual native pilot checkpoint
    without duplicating task-41 findings or claiming benchmark/full-task completion.
  - Verification: `python utils/validate_project_structure.py` PASS after repair.
  - Fix SHA: `bed9908d38a709f8f565a7a3ced60f78e1980ac2`. Metadata issue verified by Main's
    structure gate; reviewer explicitly did not evaluate RV-002. No independent PASS is claimed.

No broad acceptance rerun, rendered gameplay, task-42 or Phase-3 work is claimed.

Recovery outcome: previous inaccessible review remains NOT_RUN; replacement review and its one
bounded fix review are collected/triaged. No review is currently REVIEW_PENDING and no accepted
RV-001/RV-002 remains open. Runtime source at the fix SHA is the current implementation checkpoint.
In this task file, only the new review section is committed; pre-existing task/config/definition/manifest/addon
worktree changes remain preserved and unstaged. Task 41 remains **IN_PROGRESS** because its separate
cold/parser and bounded shutdown retention acceptance is unresolved. Next: isolate/repair that
resource graph and run its exact failing surfaces before claiming task acceptance or beginning 42.

### Cold retention investigation — 2026-10-10

Task status remains **IN_PROGRESS**. The immutable lifetime review target is
`3a7566318350d4091226cf962e8a6321dd609d60`; the runtime fix checkpoint remains
`bed9908d38a709f8f565a7a3ced60f78e1980ac2`. A Git comparison confirms the RV-001
production and regression files are unchanged between those full revisions. RV-001/RV-002
remain FIXED under their existing evidence; no new functional test PASS is claimed here.

Native cold parser was actually rerun on Godot 4.7.1 (`a13da4feb` build): two scripts
compile, but shutdown **FAILs** with 404 Objects / 291 resources plus font/texture RIDs
and Variant allocator pages. A zero native exit code does not waive these diagnostics.
Log: `tests/artifacts/refactoring_v2_41_retention_current_parser.log`.
The full 1415-test suite and the bounded Customer/address GUT surfaces were not rerun.

Compile-only bisect narrows one graph as follows:

- `TerminalPanel` plus the snapshot call reproduces retention without executing fixture
  setup, snapshot capture or any test body. UI teardown is not established as its cause.
- Each direct TerminalPanel dependency alone with snapshot is clean. The combination of
  `CustomerFlowService` and `CommercePanelFactory`/`CommerceService` fails. Further reduction
  reaches `E_InventoryPickup`, its `E_GrabbableBody` base, and the cargo/grab combination.
- `CartCargoSolver` + `GrabPhysicsSolver` + `CustomerInspectionService` + snapshot retain
  383 Objects / 273 resources. Either solver alone with the Customer flow is clean.
- In that diagnostic probe, omitting `CustomerInspectionService.end` or just its
  `LootDropService.accept_contents(parcel)` call gives a clean shutdown. Omitting the
  other end side effects does not. Stubbing the callee body while retaining the call
  still fails. This isolates a compilation dependency, not a proven runtime transaction bug.
- A lexical reachable-class graph has 405 scripts. It identifies project cart/character/time
  cycles and self references, but lexical cycles alone do not prove the retained owner.

All temporary runtime experiments were reverted; no partial workaround was committed:
cart parameter-cycle separation, all eight retained static owners annotated with
`@static_unload`, transient/string-backed codec schemas, explicit loot queue/ID arguments,
in-place pending filtering, grab self-call/factory changes, separate notification scope,
and dynamic static Callback construction. Some reduce retention; none eliminates the
original failure. Source bytes were saved for bounded temporary stubs and restored in
`finally`; final task-owned runtime diff is empty. Addons and unrelated user edits remain preserved.
Diagnostic probes/logs remain ignored under `tests/artifacts/retention_*` and
`tests/artifacts/refactoring_v2_41_*_trial.log` for reproducibility.

Upstream context is a hypothesis only: [Godot issue 122022](https://github.com/godotengine/godot/issues/122022)
reports a typed/self-reference retention combination on the same official 4.7.1 build;
it was closed without a verified fix and does not establish our root cause. The
[`@static_unload` documentation](https://docs.godotengine.org/en/latest/classes/class_%40gdscript.html)
also records unloading limitations. No engine/addon update or diagnostic waiver is adopted.

Additional bounded lifetime review: **COLLECTED / TRIAGED — NO_FINDING**. The same
`/root/review_task41_checkpoint` completed it; no second concurrent child was started.
BASE_SHA=`857ec02d7703eab840dbf496730be48d29294d99`,
TARGET_SHA=`3a7566318350d4091226cf962e8a6321dd609d60`.
Scope: new compiler/recipe/notification/snapshot Script-resource ownership and immediate
contracts. Reviewer reads immutable Git objects only; no edits/tests/Godot/MCP/live source.
Main accepts the result as inconclusive for the retention cause, not as a full task PASS.
No provisional R-ID or new accepted error was reported; RV-001/RV-002 remain FIXED under
their recorded fix SHA and verification. Reviewer ARCHITECTURE and VALIDATION are NOT_RUN;
STYLE PASS is static assessment only. This review does not reopen the RV-001 fix review.

The review's three proposed falsifying experiments were actually run in separate cold
processes. A restores only the BASE registration block in `CustomerInspectionService.begin`;
B restores only the BASE composition blocks in `LootDropService.prepare/_place`; C combines
A+B. All three retain **383 Objects / 273 resources** plus font/texture RIDs and Variant
allocator pages. Their zero exit codes are diagnostic FAIL, not PASS. Thus these two newly
added edges are not necessary to reproduce this particular compile-only retention.
The original production bytes were restored in `finally`; no runtime fix is inferred or kept.
Logs: `tests/artifacts/refactoring_v2_41_edges_A_trial.log`,
`tests/artifacts/refactoring_v2_41_edges_B_trial.log`, and
`tests/artifacts/refactoring_v2_41_edges_C_trial.log`.

No review remains REVIEW_PENDING. Next: establish the retained owner or a minimal engine
reproduction, then verify the exact cold and bounded shutdown surfaces before task 41
acceptance and archive. Task 42 still depends on task 41 acceptance.

Main's subsequent compiler probes narrow but do not resolve that gate:

- Stubbing `CartCargoSolver._destroyed` while keeping `integrate` gives a clean minimal
  probe. Keeping `_destroyed` while stubbing `integrate` retains 376 Objects / 267 resources.
  Four reduced `_destroyed` variants (typed null, component lookup only, enum only,
  lookup plus numeric comparison) all retain 383 Objects / 273 resources. Removing its
  dependency is not an acceptable production fix or proof of an incorrect gameplay rule.
- Replacing GutTest inheritance/assertions with a plain RefCounted probe still retains
  294 Objects / 247 resources for the solver/customer/snapshot combination and
  315 Objects / 265 resources for TerminalPanel/snapshot. Thus GUT inheritance is not
  necessary for retention. The same solver/customer probe without snapshot is clean;
  the GutTest solver/customer probe without snapshot is also clean.
- These are compile-only processes; no probe method body or rendered gameplay ran.
  Temporary cart source bytes were restored, and the no-GUT probes only wrote ignored
  diagnostic files. Production remains at the existing runtime checkpoint.
- Logs: `tests/artifacts/refactoring_v2_41_cart_*_trial.log` and
  `tests/artifacts/refactoring_v2_41_no_gut*_trial.log`.

Triage was reconciled with full audit HEAD `1b02b9f46fabc50b5e52dc01e98ce47918550daa`.
RV-001 production/regression files are unchanged from their fix SHA; RV-002's metadata
repair remains present. Actual project-structure and refactoring-preflight validation PASS
after the collected review update. Full GUT, bounded shutdown tests and broad acceptance
were not rerun in this diagnostic batch; the previously recorded failures remain OPEN.
