# R26 — Physical items and modular NPC archetypes
Status: **IN_PROGRESS**

## Task state

### Goal

Implement a data-driven expansion of physical items and district NPCs.

The feature has two pillars:

1. Every world item is a real `RigidBody3D` and reuses the existing physical grab / impact / inventory / damage / hazard contracts.
2. NPC identity is composed from a base archetype plus persistent modular traits/variation, while LimboAI Behavior Trees visibly own decision flow.

This root task owns overall status/current/next. Each supporting task owns its own acceptance/evidence:
- [R26.1 — physical items](r26_1_physical_items_and_effects.md)
- [R26.2 — archetypes and variation](r26_2_npc_archetypes_and_variation.md)
- [R26.3 — Behavior Trees](r26_3_npc_behavior_trees.md)
- [R26.4 — dialogue variants](r26_4_dialogue_variants.md)
- [R26.5 — integration and persistence](r26_5_integration_persistence_validation.md)

### Current

R26.1 physical catalog/framework and R26.2 persistent modular identity/category orders are
implemented at the checkpoints recorded in their owning tasks; full integration remains open.
R26.3 native safety/freeze/shy/night/hag/brute/fire/chain milestones passed scoped native
checks and independent reviews. Creepy now uses hidden native paths, actual camera/LOS,
terminal-reader reach and durable actor-specific notice at
`3e88b56983a775cc78c225353251ff6a98d33b87` (schema17).
Recovery review BASE `6f96be1e39eb94b4a4c307c8bce2d3b9a30a14f3` -> that TARGET accepted only
RV-005 in R26.3. Repair `23fa3d44d9024d4becb59477921be1d288d7bee9` passed GUT14/111 and
independent targeted review; suspension now breaks continuous exposure, preserving memory.
R26.4 now has **18/20** native variants (lost/shy/night/angel/hag/brute/fire/chain/creepy).
Creepy `ad79c0eab6a00772dd578a3a7d25053166db70ef` passed native GUT36/1009, parser3/3
and static checks; independent review **PASS**, no findings, on exact
`23fa3d44d9024d4becb59477921be1d288d7bee9..ad79c0eab6a00772dd578a3a7d25053166db70ef`.
Mandatory Vampire capabilities/two dialogues, all-ten live roster binding and R26.5 acceptance
remain unfinished. Required owner QA stays open. Existing user worktree edits were preserved.

### Next

Implement Vampire authoritative blood confirmation,
health-floor combat/cloud/light behavior and its two variants; bind all ten archetypes only
after their mandatory capabilities and outstanding cross-archetype acceptance are ready.

### Validation

Initial R26.1 semantic damage batch has focused parser/GUT evidence in its owning task.
Full item and NPC acceptance remains NOT_RUN. Milestones use
[validation-workflow](../.agents/skills/validation-workflow/SKILL.md) and immutable-SHA
[review-orchestration](../.agents/skills/review-orchestration/SKILL.md) before DONE.

### Owner QA / blockers

Final assets, prose, names, balance, music/shadows and feel require owner QA.
Keep mandatory owner acceptance open; explicitly deferred polish may have a separate checklist.

## Existing contracts to preserve

- Godot 4.7.1 / Forward Plus / Jolt / pinned GECS v8; third-party addons are read-only.
- Physical holding authority remains `item --R_HeldBy--> actor`; use `GrabService` / `E_GrabbableBody`.
  Inventory ownership is a separate `R_OwnedBy` contract: current `InventoryService.can_transfer`
  rejects `C_Grabbable`. Do not assume composing both capabilities enables stack transfer.
- Native rigid-body physics owns transform and velocity.
- Damage enters only through `DamageRequest` / `DamageRequestService`; `C_Health` remains sole HP authority.
- Hazards spawn through `HazardSpawnService` and existing hazard definitions/scenes.
- Inventory ownership remains the existing `R_OwnedBy`/InventoryService contract. Virtual
  owned stacks are valid; the rigid-body requirement applies to their world pickups.
- Persistent district identity remains `NpcRecord`; do not encode persistent identity in transient scene nodes.
- LimboAI Behavior Tree is the decision pattern. Do not hide a FSM/dispatcher in one `BTAction`.
- Dialogue uses the existing Dialogue Manager adapters/resources.
- Preserve current parcel service, schedule, memory, relationships, navigation, save/load, and existing owner-authored level geometry.
- Components own state; Relationships own live Entity bindings; Systems own cadence;
  Observers own discrete reactions; Services perform explicit synchronous operations.
- Author actors/UI as editable `.tscn`, tuning as typed `.tres`; use editor/MCP for open
  editor-owned assets and settings. No runtime source/scene generation.
- Extend `E_TraitedEntity.traits` and its existing compiler; Templates are optional editor
  presets. Behavioral `DEF_NpcTrait` data is distinct from Entity capability Traits.
- New gameplay lives in `content/domains/<owner>/<role>/`; use Shared only for genuine
  cross-domain contracts. Preserve stable IDs, exported bindings and mandatory references.
- Implementation uses [gdscript-style](../.agents/skills/gdscript-style/SKILL.md) for project
  scripts and [gecs-v8](../.agents/skills/gecs-v8/SKILL.md) for pinned ECS APIs.
- Use GameClock/DecisionRandomRules for gameplay cadence and persistent decision seeds;
  native physics delta retains its existing authority.
- Current save schema is `AutosaveStore.SCHEMA_VERSION = 17`; version incompatible
  serialized changes from the actual implementation baseline. No old-save conversion,
  defaults that accept an unsupported format, or automatic rejected-slot overwrite.

## Architecture direction

### Items

Do not implement each item as a unique hard-coded gameplay script.

Use composable authored capabilities/definitions for concepts such as:
- handheld;
- large/carryable;
- melee;
- throwable;
- breakable/explosive payload;
- hazard producer;
- contact damage;
- valuable;
- stackable inventory item;
- damage type/effect;
- Health/destructibility.

Item categories used by commerce/NPC preferences must also be data-driven, e.g. weapon, clothing, artifact, reagent, toy, valuable.

### NPC

Do not implement NPC types as a single enum followed by large `match` blocks.

Use:
- base archetype definition;
- mandatory archetype traits;
- optional compatible trait pool;
- persistent selected traits / variant seed in `NpcRecord`;
- authored order-category weights;
- two initial name/dialogue variants per archetype;
- Behavior Trees composed from Conditions / Actions / Decorators / Composites / Subtrees.

Shared traits must be reusable across archetypes so future NPCs can combine unexpected behavior without adding a new monolithic class.

## Milestones

- [ ] R26.1 — shared physical-item/capability/effect framework and the requested item catalog.
- [ ] R26.2 — NPC archetype data, persistent variation, tags, order preferences and placeholder identities.
- [ ] R26.3 — real LimboAI BT decomposition and all archetype-specific behavior.
- [ ] R26.4 — two dialogue variants per archetype and special communication modes.
- [ ] R26.5 — persistence, integration, focused regressions, headless acceptance and owner QA checklist.

## Completion criteria

- Requested items exist as physical `RigidBody3D` entities and use shared systems instead of per-item hard-coded execution.
- Requested NPC archetypes exist as authored data and spawn with stable persistent variation.
- Important NPC decisions are readable from LimboAI tree hierarchy without reading a dispatcher script.
- Two dialogue variants exist for every archetype.
- Item/NPC combinations are driven by tags/traits and can be extended without editing central giant `match` statements.
- Save/load reproduces the same person, name, traits and dialogue variant.
- Focused automated tests and headless acceptance pass.
- Subjective gameplay, visuals, tuning, music/shadow presentation and dialogue quality remain owner QA.
- Required owner acceptance keeps the owning task OWNER_QA; DONE/archive only after
  all required gates close or the owner explicitly defers the remaining manual scope.
