# R26.5 — Integration, persistence and acceptance for R26
Status: **PLANNED**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Integrate physical items, modular NPC archetypes, LimboAI behavior and dialogue into the existing district/parcel/save systems without regressing current gameplay.

### Current

PLANNED; no R26 implementation or acceptance is claimed. Apply the current contracts
in [R26](r26_items_npc_expansion.md#existing-contracts-to-preserve) when this milestone starts.
Prerequisite milestones now include schema16 soul receipts and Strength; their scoped evidence is in R26.3. Full integration acceptance below remains NOT_RUN.

### Validation

NOT_RUN: R26 engine/gameplay checks. Follow the acceptance and validation sections below,
[validation-workflow](../.agents/skills/validation-workflow/SKILL.md) and the root review gate.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Persistence

Extend the closed save schema deliberately.

Persist only durable facts:
- physical persistent item state required by the existing world snapshot contract;
- item Health where already supported by snapshot rules;
- player karma if introduced;
- player soul-deal/progression state;
- NPC archetype;
- stable variation seed;
- selected name;
- selected optional traits;
- selected dialogue variant;
- durable NPC personal memories already owned by `NpcRecord`;

Do **not** persist:
- live Node/Object references;
- BT task instances;
- transient Blackboard references;
- current physics contact inboxes;
- per-frame perception;
- temporary route caches;
- derived hazard interest that can be reconstructed.

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

Requested item definitions must be orderable/packageable where their physical fulfillment makes sense.

NPC order preferences use category weights:
- clothing;
- weapon;
- artifact;
- reagent;
- toy;
- unrestricted/anything.

Large barrels may require large-item/package policy rather than ordinary stack inventory. Do not force them through a small stack path just to satisfy ordering.

NPC parcel opening must reuse existing package opening/lifecycle/hazard behavior.

### Combat/social memory

Damage from player-owned thrown/melee/explosive items must preserve player attribution so:
- NPC retaliation works;
- witness memory works;
- killing/attack incidents remain correct.

Blood Hazard behavior stimulus must not be recorded as damage because it is harmless.

Holy/unholy healing/damage should produce meaningful combat/social attribution only when an actual damage/heal event occurs.

### NPC vs NPC

NPCs should use receiver/archetype/trait data when deciding conflicts:
- ordinary NPCs avoid initiating conflict with Weeping Angel;
- fire immune actors do not avoid fire solely from predicted damage;
- traits/memory may influence conflict but do not bypass the existing relationship/intent ownership.

## Presentation hooks

Expose narrow events/state for:
- Night Hunter appearance music change;
- denser shadow presentation;
- Vampire invisibility;
- Vampire cloud escape;
- Angel signs;
- elemental aura VFX.

Gameplay logic must not depend on a renderer/audio node completing successfully.

Use placeholders if final assets do not exist.

## Schema and new-game construction

Current `AutosaveStore.SCHEMA_VERSION` is 16. When serialized fields/paths/meaning change,
advance the actual supported version, guards, golden fixture and save-visible inventory.
Unsupported old/newer/invalid saves reject before live mutation, preserve original bytes
and remain protected from later autosave. No conversion, previous-format aliases or load defaults.
Initialize new-game records deterministically from existing authored profiles without mutating
shared Resources. Use [save-systems](../.agents/skills/save-systems/SKILL.md).

## Debugging support

Extend compact read-only diagnostics with item capabilities/categories/effect source,
NPC archetype, selected traits/dialogue variant and species/receiver tags. Show important
BT branch/status where LimboAI exposes it cheaply, and relevant blood/light/gaze conditions.

Do not add per-frame verbose logging.

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
- FIRE immunity for Fire Elemental and Chain Devil;
- Angel ignores non-HOLY damage and receives HOLY;
- ACID resistance path uses typed damage;
- HOLY player rule obeys low-karma threshold;
- UNHOLY heals authored unholy NPC and damages high-karma player;
- healing never exceeds ordinary Health authority rules;
- Blood Hazard causes zero HP damage.

### NPC variation
- same seed => same name/traits/dialogue variant;
- save/load => same person variation;
- replacement/new person can roll a different valid combination;
- incompatible traits never coexist;
- missing order category degrades gracefully.

### Behavior
- Angel freezes while truly observed and can move while unobserved;
- aggressive Angel is faster but still freezes when seen;
- Night Hunter attacks in dark and flees in bright light;
- Shy NPC reacts to sustained direct gaze;
- Brute toy embarrassment requires real perception;
- Fire Elemental maintains authored fire/floor hazard without duplicate spawn storm;
- Creepy NPC approaches from behind without teleporting;
- Vampire prioritizes blood zone, calms, stops before ordinary lethal finish, and can escape as cloud;
- BT resources are composed from real conditions/actions/composites/decorators/subtrees rather than one generic dispatcher action.

### Dialogue
- 2 variants × 10 archetypes load/import;
- Angel sign communication works;
- soul deal applies once per accepted confirmation;
- third consecutive accepted deal causes player death;
- vampire accepted blood request removes 5–40% of current HP through gameplay contract;
- decline/cancel paths do not mutate stats.

### Performance/safety
- no broad ECS/world scan added per physics frame where an existing bounded perception query/event can be reused;
- hazard spawning is bounded/idempotent;
- no resource loads in hot BT ticks;
- no per-frame debug spam.

## Validation sequence

1. Incremental formatter, agent-change, strict architecture/domain and structure validators.
2. Actual Godot parser through `utils/godot_agent.ps1`, independent of MCP availability.
3. Focused GUT by subsystem and dialogue import/parser, using current project skills.
4. Fresh-process current-format roundtrip, passive restore and incompatible-slot protection.
5. One bounded connected district headless smoke; immutable-SHA review and finding triage.
6. Runnable Windows QA export under `.export/` at the completed large gameplay milestone.

Do not run rendered gameplay automatically.

## Owner QA

Manual owner checks cover scythe AOE/thrown-knife feel, barrel/flask physics and hazard
readability; Angel look/freeze; Night Hunter light/music/shadows; Creepy stalking;
Vampire visibility/cloud escape; final prose and balance of aggression, probabilities,
order weights and karma thresholds.
