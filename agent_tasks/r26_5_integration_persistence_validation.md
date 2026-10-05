# R26.5 — Integration, persistence and acceptance for R26
Status: **PLANNED**

Parent: `agent_tasks/r26_items_npc_expansion.md`

## Goal

Integrate physical items, modular NPC archetypes, LimboAI behavior and dialogue into the existing district/parcel/save systems without regressing current gameplay.

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
- durable state needed for “three accepted soul deals” if that state survives save/load.

Do **not** persist:
- live Node/Object references;
- BT task instances;
- transient Blackboard references;
- current physics contact inboxes;
- per-frame perception;
- temporary route caches;
- derived hazard interest that can be reconstructed.

Restore authoritative data first, then rebuild derived BT/perception/presentation state.

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

## Migration/backward compatibility

Current saves/profiles without R26 fields must load to deterministic valid defaults where feasible.

Do not silently mutate shared authored Resources during migration.

If an old NPC has no archetype/seed:
- assign a deterministic compatible baseline from existing profile data;
- persist it on next save.

If exact compatibility is impossible, fail validation explicitly rather than partially corrupting district identity.

## Debugging support

Extend developer diagnostics with compact read-only output:
- item capabilities/categories/effect source;
- NPC archetype;
- selected traits;
- dialogue variant;
- species/receiver tags;
- current important BT branch/status where LimboAI exposes it cheaply;
- blood/light/gaze special-condition state only when relevant.

Do not add per-frame verbose logging.

## Automated acceptance matrix

### Physical items
- each requested item scene root/body is `RigidBody3D`;
- grab/release/throw preserves physical authority;
- stack ownership hides/disables only inventory-owned world pickup;
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

Use coherent batches.

1. Static/structure validation.
2. Godot parser on changed project GDScript.
3. Focused GUT by subsystem.
4. Save/load roundtrip tests.
5. One bounded connected district headless smoke covering several archetypes/items.
6. Build/export only at the final large milestone if normal project policy requires it.

Do not run rendered gameplay automatically.

## Owner QA

Manual owner checks should focus on:
- feel/readability of scythe AOE and thrown knife;
- barrel/flask physics;
- hazard readability;
- Angel “look/freeze” feel;
- Night Hunter light transition/music/shadows;
- Creepy stalking feel;
- Vampire visibility/cloud escape;
- final dialogue prose;
- balance of aggression, probabilities, order weights and karma thresholds.
