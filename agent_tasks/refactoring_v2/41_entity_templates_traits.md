# Refactoring v2.41 — Entity Templates / Traits runtime composition

Status: **IN_PROGRESS**

Зависимости: [47_game_time_randomness.md](47_game_time_randomness.md), strict domains и authoritative ECS contracts.

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
