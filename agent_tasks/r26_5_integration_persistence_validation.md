# R26.5 — Integration, persistence and acceptance for R26
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal
Integrate physical items, modular NPC archetypes, LimboAI behavior and dialogue into the existing district/parcel/save systems without regressing current gameplay.

### Current
Native ResourceSaver now binds all ten canonical archetypes and two explicit visitor presets.
Twelve stable NPC slots, eight residents/four visitors, slot-eight merchant, recipients and participation
schedules preserved. Legacy fixtures isolate regressions; live acceptance/smoke use production data.
Schema advances from 18 to 19 because saved profile paths/meaning change; no conversion or alias.
Roster checkpoint `81f22ee6e09a3466237ac67564554052fc4a2634` and repair
`5a861f1a83cef7c53a962326eda42420de1238cd` have collected review PASS; integration remains open.

### Validation
PASS: clean native visitor reference/UID finalization, `.artifacts/r26_roster_finalize-uid-20261013.log`.
PASS: production live-roster GUT `gut-20261012-225635220` 10 tests/798 assertions;
parser225451860 four files and230043030 final helper/test; formatter/strict architecture/structure/index.
Golden schema19 capture `gut-20261012-225647766` 5/364 assertions PASS; runner FAIL solely
at shutdown Resource/RID/VariantPools retention, KNOWN_ENGINE_LIMITATION/DEFERRED. Inventory PASS.
Fresh-process night write090418708 and restore090443023 PASS after creation-seed fixture repair.
FAIL: unchanged reviewed retained-goal week `district-20261013-105104090.log`, survival5/required6;
prior094309939/085722945 FAIL4, legacy FAIL5. Latest native night/snapshot/restore checks pass; no other runtime errors.
Full affected batch `.artifacts/r26_roster_regressions-20261013.log` FAIL: 57 suites,
1232/1252 tests, 17719/17793 assertions, one lifecycle suite failed to parse. Scope pinned by
`.artifacts/r26_roster_regression_paths-20261013.txt`. Only failed/omitted suites are rerun
after repair in fresh processes; current totals below. QA export/menu/level120frames PASS:
`.export/windows/20261013-005901Z-a030253a-r26-reviewed-retained-goal-qa`; dirty=true, full reviewed SHA in manifest.
Fresh failed/omitted/live suites PASS: 293 tests/5690 assertions, logs date20261012 under
`.artifacts/godot_agent/`: blood23175732114/195, queue23205106551/340, snapshot23184298816/205,
stage23212246359/427, catalog2319336434/934, chain23193673739/945, participation2320030779/162,
pride23244302917/263, vampire23203847139/1069, soul23210681116/186, lifecycle23172017619/166,
live23173643310/798. Parser2318103918files and final formatter/static gates PASS.
[Route convergence](npc_route_goal_convergence.md): RV-001 reviewed FIXED; RV-002 unsafe endpoint retirement native121/918/parser/static PASS, review pending.
[Disconnected refuge candidates](npc_hazard_escape_connected_candidates.md): native131/1842,
map repair103/1549/review PASS; moving-source139/1904/review PASS; retained-goal120/899/review PASS, unchanged week FAIL5/6.
Latest bounded probe1055116147200frames PASS: retained safe goal, reachable movement/no combat;
deaths4/day1,3/day3,1/day4 remain; full week NOT_RUN. Prior104155522 shutdown retention DEFERRED.
Isolated floor-damage2 control `.artifacts/r26_floor_asset_comparison-20261013-103745981.log`
FAIL5/6, actual tick_damage2/cadence0.5 verified; fire-presence00391791111/77 PASS; original asset restored byte for byte.

### Review / triage

PASS: existing terminal reviewer reused after live-status check, exact BASE
`25e54edea6bf38d28d3d4548d79a38155ed29a89` -> TARGET
`81f22ee6e09a3466237ac67564554052fc4a2634`; no findings, elapsed108s;
architecture/style PASS, reviewer validation NOT_RUN. Required week FAIL remains unresolved.
RV-001/P2: night smoke mutated world_seed after native population/merchant publication at BASE
`25e54edea6bf38d28d3d4548d79a38155ed29a89`, violating the committed variation seed contract.
FIXED `81f22ee6e09a3466237ac67564554052fc4a2634`, detached clock recipe before registration;
fresh-process night write/restore and collected review PASS. No reroll/default/validator weakening.
RV-002/P1 FIXED: new legacy DEF_District fixture resides under tests/, rejected by the
existing closed GameplayResourcePaths definition roots during snapshot decode at target81f above.
Production live-roster/native restore passes. Native move into NPC definitions root preserves
exact bytes/UID and changes three test/helper literals; snapshot16/205 PASS. Fix/review PASS at repair SHA below.
MCP move refused before mutation at discovery limit10000; editor clean/quit, native move log
`.artifacts/r26_legacy_fixture_move-20261013.log` PASS. Whitelist/production district unchanged.
RV-003/P2 FIXED: lifecycle test retained Array[DEF_NpcProfile] after profiles became typed
Array[DEF_NpcArchetype]; repair19/166 PASS. RV-004/P2 FIXED: catalog/home-dialogue tests
assumed canonical visitors had resident participation; live schedule parity retains coverage,
private-home scenarios now use isolated resident copies, shared authored data unchanged.
RV-005/P2 FIXED: fire queue asserted one effect after authored floor effect was added;
now both effects bind the emitter and retire on death, queue51/340 and inherited stage PASS.
RV-006/P2 FIXED: pride test's fixed child index points to the newer feeding subtree.
Resource-identity hypothesis was disproven by fresh path assertions232240604; actual typed toy
subtree lookup now checks relative safety/blood/feeding/combat order and real native execution.
RV-002..006 FIXED `5a861f1a83cef7c53a962326eda42420de1238cd`; targeted review PASS, no findings.
BASE `81f22ee6e09a3466237ac67564554052fc4a2634` -> repair TARGET above; elapsed55s,
architecture/style PASS, reviewer validation NOT_RUN.

### Owner QA / blockers

Required [owner QA](../qa_tasks/r26_acceptance.md) remains open for gameplay/dialogue/assets/balance;
Deferred polish requires owner input; no rendered gameplay has run. Balance clarification pending;
new endpoint-retirement defect now has native proof; radius10m/4HP/0.5s/60s unchanged.

## Persistence
Persist durable physical item state/Health supported by existing snapshot rules, player karma,
soul-deal/progression, NPC archetype/variation seed/name/selected traits/dialogue and personal memories.
Exclude live Node/Object references, BT instances/Blackboards, physics inboxes, per-frame perception,
route caches and reconstructible hazard interest.

Restore authoritative data first, then rebuild derived BT/perception/presentation state.

Extend domain `SAVE_FIELDS` and the closed `SaveDataCodec` whitelist/preflight, with the
existing passive restore/readiness boundary. Persist links by stable endpoint keys and
rebuild Relationships before gameplay resumes; no default spawn/damage reactions during restore.

Preserve raw/scriptless placements: stable `raw_actor/placed/<UUID>` groups and
`RawPhysicsSnapshot` presence/pose restored from native authored recipes. Grab-proxies stay
transient; no serialized NodePath/instance identity or second item model. Check agreement
with `TruckCargoReceipt.raw_actor_id`; pending runtime disposal without a recipe rejects.

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

Gameplay logic is independent of renderer/audio completion; use placeholders for missing final assets.

## Schema and new-game construction
Current `AutosaveStore.SCHEMA_VERSION` is 19 in this migration. When serialized fields/paths/meaning change,
advance the actual supported version, guards, golden fixture and save-visible inventory.
Unsupported old/newer/invalid saves reject before live mutation, preserve original bytes
and remain protected from later autosave. No conversion, previous-format aliases or load defaults.
Initialize new-game records deterministically from existing authored profiles without mutating
shared Resources. Use [save-systems](../.agents/skills/save-systems/SKILL.md).

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
- Fire Elemental maintains authored fire/floor hazard without duplicate spawn storm;
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
2. Actual Godot parser through `utils/godot_agent.ps1`, independent of MCP availability.
3. Focused GUT by subsystem and dialogue import/parser, using current project skills.
4. Fresh-process current-format roundtrip, passive restore and incompatible-slot protection.
5. One bounded connected district headless smoke; immutable-SHA review and finding triage.
6. Runnable Windows QA export under `.export/` at the completed large gameplay milestone.

## Owner QA
Manual owner checks cover scythe AOE/thrown-knife feel, barrel/flask physics and hazard
readability; Angel look/freeze; Night Hunter light/music/shadows; Creepy stalking;
Vampire visibility/cloud escape; final prose and balance of aggression, probabilities,
order weights and karma thresholds.
