# R26.5 — Integration, persistence and acceptance for R26
Status: **DONE** — принято владельцем 2026-10-15.

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal
Integrate physical items, modular NPC archetypes, LimboAI behavior and dialogue into the existing district/parcel/save systems without regressing current gameplay.

### Current

**Завершено: владелец принял результат 2026-10-15.** Новые замечания и запланированные доработки сохраняют собственный незавершённый статус.

Техническая контрольная точка до ручной приёмки; прежние пометки ожидания OWNER_QA ниже закрыты решением владельца:

All ten canonical archetypes/two visitor presets remain bound; twelve stable slots,
eight residents/four visitors, merchant and participation preserved. Schema19 unchanged:
owned fire effects were transient and excluded by WorldSnapshotService._persistent.
Owner decision2026-10-13 supersedes10m floor-fire acceptance: completely remove the wide
effect/producer/definition/prefab and reduce contact radius25%, 2.25 ->1.6875m.
Parcel opening/ignition, immunity, contact4HP/0.5s/TTL60s, native follow/retirement preserved.
Reviewed code `2c18343d39d0a3ee774c9f80c33ff16d7e6d70c4`, BASE `fc68226b6e051ea15f14e5d42deb9fbb1d86bd44`:
ARCHITECTURE/STYLE PASS, no findings; reviewer VALIDATION NOT_RUN. No accepted findings remain.
Current native week and connected write/fresh restore PASS; unchanged survival >=6/8.
Runnable QA `.export/windows/20261013-194958Z-f20e59e7-r26-r27-integrated`: export/headless menu/level120frames PASS,
dirty=true preserves user work. Required owner gameplay/visual/tone/balance QA remains open.
[District fixture](district_release_validation.md) RV-004/005 remain FIXED; same fixture gates pass on new gameplay.

### Validation

Post-R27 checkpoint `f20e59e7e668f3dc164c8f49129f36195d93e933`:16scripts GUT388/11029 PASS,
angel37/701 reused; `.artifacts/r26-final-native-checks.json`. Full55-SHA ancestry/status audit
PASS (`.artifacts/r26-checkpoint-audit.json`). Week `district-20261014-053843158.log` native PASS,
unchanged >=6/8; connected write054256206/restore054446891 PASS/exits0/0; R27.5 owns full logs.
Wrappers FAIL only shutdown retention/DEFERRED. Both QA builds headless startup PASS;
ordinary export has no LimboAI DLL-copy error.

Current owner-change: GUT72tests/490assertions PASS: presence11/68 (`gut-20261013-062550024`),
opening10/83 (`062418878`), queue51/339 (`062427053`); parser4/0failures `parsefiles-20261013-062556161` PASS.
Initial presence FAIL10/11 (wrong sleep-margin assertion) is fixed. ResourceSaver062052041 saved/exit0, but bootstrap ECS compile errors mean validation FAIL.
Import062528749 exit0 settled UID fallback warnings; fresh parser/presence clean. Import wrapper FAIL only shutdown retention.
Formatter4files, agent-change2gameplayfiles, strict architecture0findings, structure/persistence inventory PASS.
Final week `tests/artifacts/district-20261013-162731685.log` PASS/wrapper0; connected `tests/artifacts/district_release-write-20261013-162956129.log` and
`tests/artifacts/district_release-restore-20261013-163149620.log` native PASS/exits0/0. Write wrapper FAIL only shutdown35RID/418ObjectDB/327Resource/VariantPools DEFERRED.
Review UTC06:27:21..06:29:36 (135s) PASS. Export/startups PASS; no rendered playtest or visual proof.
Golden schema19 `gut-20261012-225647766` 5/364 PASS; runner FAIL only shutdown Resource/RID/VariantPools DEFERRED. Inventory PASS.
Fresh-process night write090418708 and restore090443023 PASS after creation-seed fixture repair.
Historical FAIL: unchanged reviewed endpoint-safety week `district-20261013-111311881.log`, survival5/required6;
prior094309939/085722945 FAIL4, legacy FAIL5. Night/snapshot/restore pass; shutdown retention DEFERRED, no other runtime errors.
Historical batch `.artifacts/r26_roster_regressions-20261013.log` FAIL:57suites,1232/1252tests,17719/17793assertions, lifecycle parse failure; scope `.artifacts/r26_roster_regression_paths-20261013.txt`.
Prior QA export/menu/level120frames PASS: `.export/windows/20261013-012719Z-4c60e3dc-r26-reviewed-pressure-qa`, dirty=true/full reviewed SHA in manifest.
Fresh failed/omitted/live suites PASS293/5690; logs20261012 `.artifacts/godot_agent/`: blood23175732114/195, queue23205106551/340, snapshot23184298816/205,
stage23212246359/427, catalog2319336434/934, chain23193673739/945, participation2320030779/162,
pride23244302917/263, vampire23203847139/1069, soul23210681116/186, lifecycle23172017619/166,
live23173643310/798. Parser2318103918files and final formatter/static gates PASS.
[Route convergence](npc_route_goal_convergence.md): RV-001/002 reviewed FIXED; latest unsafe endpoint retirement native121/918/parser/static/review PASS; pre-tuning week FAIL5/6, final week112524520 PASS.
[Disconnected refuge candidates](npc_hazard_escape_connected_candidates.md): RV-001..004 FIXED; latest120/899/parser/static/review PASS.
Historical floor2 control `.artifacts/r26_floor_asset_comparison-20261013-103745981.log` FAIL5/6, tick2/0.5 verified; fire00391791111/77 PASS; bytes restored exactly.
Floor1 control `.artifacts/r26_floor_counterplay_candidate-20261013-111752457.log`: native PASS7/6,
radius10/tick1/0.5 and applied damage1 verified, torso4 unchanged, exit0; original bytes restored.
Shutdown4ObjectDB/2Resource retention DEFERRED; controls predate complete floor removal.
ResourceSaver012124213 exit0/UID PASS (runner FAIL shutdown RID/Resource DEFERRED); fire01223947511/77/structure/inventory PASS, schema/path/UID unchanged.
Prior production `tests/artifacts/district-20261013-112524520.log` PASS/wrapper0:7days,unchanged >=6/8,night/snapshot/restore/navigation/identity PASS.
Export shutdown422ObjectDB/152Resource/VariantPools and1startup Resource retention DEFERRED; logs preserved.

### Review / triage

Roster review BASE `25e54edea6bf38d28d3d4548d79a38155ed29a89` -> TARGET `81f22ee6e09a3466237ac67564554052fc4a2634`:
architecture/style PASS, no findings,108s; reviewer validation NOT_RUN. Original week FAIL remains above.
RV-001/P2: night smoke mutated world_seed after native population/merchant publication at BASE above.
FIXED `81f22ee6e09a3466237ac67564554052fc4a2634`, detached clock recipe before registration;
fresh-process night write/restore and collected review PASS. No reroll/default/validator weakening.
RV-002/P1 FIXED: new legacy DEF_District fixture resides under tests/, rejected by the
closed GameplayResourcePaths roots during snapshot decode at81f. Native move into NPC definitions
preserves bytes/UID; three test/helper literals change, snapshot16/205 PASS. Fix/review below.
MCP move refused pre-mutation at limit10000; native `.artifacts/r26_legacy_fixture_move-20261013.log` PASS;
editor clean/quit, whitelist/production district unchanged; live-roster/native restore passes.
RV-003/P2 FIXED: lifecycle test retained Array[DEF_NpcProfile] after profiles became typed
Array[DEF_NpcArchetype]; repair19/166 PASS. RV-004/P2 FIXED: catalog/home-dialogue tests
assumed canonical visitors had resident participation; live schedule parity retains coverage,
private-home scenarios now use isolated resident copies, shared authored data unchanged.
RV-005/P2 OBSOLETE `2c18343d39d0a3ee774c9f80c33ff16d7e6d70c4`: owner removed the complete floor effect.
Its original two-emitter defect was fixed at `5a861f1a83cef7c53a962326eda42420de1238cd`
(queue51/340/stage PASS); the current one-contact-effect contract is reviewed, queue51/339 PASS.
RV-006/P2 FIXED: pride test's fixed child index points to the newer feeding subtree.
Resource-identity hypothesis was disproven by fresh path assertions232240604; actual typed toy
subtree lookup now checks relative safety/blood/feeding/combat order and real native execution.
RV-002/003/004/006 FIXED `5a861f1a83cef7c53a962326eda42420de1238cd`; RV-005 obsolete as above.
Original targeted repair review PASS, no findings.
BASE `81f22ee6e09a3466237ac67564554052fc4a2634` -> repair TARGET above; elapsed55s,
architecture/style PASS, reviewer validation NOT_RUN.
Historical floor-pressure review PASS, no findings,20s: BASE `f9888f3c87fb7715d5ab8bdf07b5ef55382c5979`
-> TARGET `4c60e3dc784352c2fb95ca617cebbafa9a834366`, same reviewer;
architecture/style PASS, reviewer validation NOT_RUN. Final ordinary production week PASS above.

### Owner QA / blockers

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Связанные чеклисты: [owner QA](../../qa_tasks/r26_acceptance.md)

## Persistence
Persist durable item state/Health, karma, soul/progression, NPC identity/variation and memories
through domain `SAVE_FIELDS`/closed codec. Exclude live Objects, BT/Blackboards, physics inboxes,
perception/route caches and derived hazard interests. Restore authority before derived state,
rebuild Relationships from stable keys before readiness and suppress ordinary spawn/damage reactions.
Raw/scriptless actors keep `raw_actor/placed/<UUID>` and native `RawPhysicsSnapshot` recipes,
matching `TruckCargoReceipt.raw_actor_id`. Grab-proxies/NodePaths/instance IDs are transient;
pending disposal without a native recipe rejects. No second item model.

## Existing-system integration
### Parcel/customer flow

Requested physical item definitions must be orderable/packageable where fulfillment makes sense.
NPC order preferences weight clothing, weapons, artifacts, reagents, toys or unrestricted/anything.

Large barrels may require large-item/package policy rather than ordinary stack inventory. Do not force them through a small stack path just to satisfy ordering.

NPC parcel opening reuses existing package opening/lifecycle/hazard behavior.
### Combat/social memory

Player-owned thrown/melee/explosive damage retains player attribution for retaliation,
witness memory and killing/attack incidents.

Blood Hazard behavior stimulus must not be recorded as damage because it is harmless.

Holy/unholy healing/damage should produce meaningful combat/social attribution only when an actual damage/heal event occurs.

### NPC vs NPC

NPCs should use receiver/archetype/trait data when deciding conflicts:
- ordinary NPCs avoid initiating conflict with Weeping Angel;
- fire immune actors do not avoid fire solely from predicted damage;
- traits/memory may influence conflict but do not bypass the existing relationship/intent ownership.

## Presentation hooks
Expose narrow events/state for Night Hunter music/shadows, Vampire invisibility/cloud escape,
Angel signs and elemental aura VFX.


## Schema and new-game construction
Current `AutosaveStore.SCHEMA_VERSION` is 19 in this migration. When serialized fields/paths/meaning change,
advance the actual supported version, guards, golden fixture and save-visible inventory.
Unsupported saves reject before mutation and retain bytes/protection; no conversion/aliases/load defaults.
Initialize new-game records deterministically from existing authored profiles without mutating
shared Resources. Use [save-systems](../../.agents/skills/save-systems/SKILL.md).

## Debugging support

Extend compact read-only diagnostics with item capabilities/categories/effect source,
NPC archetype, selected traits/dialogue variant and species/receiver tags. Show important
BT branch/status where LimboAI exposes it cheaply, and relevant blood/light/gaze conditions.

Implemented: explicit-refresh detached archetype/variation/tags, item categories/effect source,
native running branches and blood/light/gaze/veil state. GUT23353043921/202 PASS,
parser2336473932files and formatter/architecture/structure PASS. Review PASS, no findings:
BASE `5a861f1a83cef7c53a962326eda42420de1238cd` ->
TARGET `1b37fcb468e1c0c7d996d1d4df3d7940c933a807`; architecture/style PASS, runtime NOT_RUN.
No per-frame verbose logging or duplicated gameplay authority.
## Automated acceptance matrix
### Physical items
- each requested item scene root/body is `RigidBody3D`;
- grab/release/throw preserves physical authority;
- `R_OwnedBy` stack ownership and `R_HeldBy` grip remain distinct; virtual owned stacks
  drop into real pickups, and rejected transfer/drop preserves quantity/ownership;
- barrels break exactly once;
- explosive/hazard payload spawns exactly once;
- contact damage does not repeat every resting frame;
- player attribution survives thrown/broken source lifetime.

### Damage
- FIRE immunity for Fire Elemental/Chain Devil; Angel ignores non-HOLY and receives HOLY;
  ACID resistance uses typed damage.
- HOLY player rule obeys low-karma threshold; UNHOLY heals authored unholy NPC and damages
  high-karma player. Healing respects Health authority; Blood Hazard causes zero HP damage.

### NPC variation
- Same seed/save-load keeps name/traits/dialogue; replacement may roll a different valid combination.
- Incompatible traits never coexist; missing order categories degrade gracefully.

### Behavior
- Angel freezes under actual observation, moves unobserved; aggressive form is faster but still freezes.
- Night Hunter attacks in dark/flees bright light; Shy reacts to sustained gaze; Brute perceives real toys.
- Fire Elemental maintains only contact aura radius1.6875m, no wide floor effect or duplicate spawn storm;
  Creepy approaches from behind without teleporting.
- Vampire prioritizes blood zone, calms, stops before ordinary lethal finish, and can escape as cloud;
- BT resources are composed from real conditions/actions/composites/decorators/subtrees rather than one generic dispatcher action.

### Dialogue
- 2 variants × 10 archetypes load/import; Angel communicates with signs.
- Soul confirmations apply once; third accepted deal kills player; refusals retain total count.
- Accepted vampire blood request removes 5–40% of current HP; decline/cancel never mutates stats.

### Performance/safety
- Bounded perception/events replace broad per-frame scans; hazard spawning is bounded/idempotent.
- No resource loads in hot BT ticks or per-frame debug spam.

## Validation sequence

1. Incremental formatter, agent-change, strict architecture/domain and structure validators.
2. Actual Godot parser via `utils/godot_agent.ps1`, focused subsystem GUT and dialogue import; MCP-independent.
3. Fresh-process roundtrip/passive restore/incompatible-slot protection, connected district smoke and exact-SHA review/triage.
4. Runnable Windows QA export under `.export/` at the completed large gameplay milestone.

## Owner QA

Принято владельцем 2026-10-15 по сообщению «Закрой все задачи где OWNER_QA». Ранее реализованный объём закрыт общей приёмкой; новые замечания остаются отдельными задачами. Поштучный прогон всех сценариев и новая визуальная QA агентом не заявляются.

Manual checks cover scythe/knife feel, barrel/flask physics and hazard readability; Angel freeze, Night Hunter light/music/shadows, Creepy stalking, Vampire visibility/cloud, prose and aggression/probability/order/karma balance.
