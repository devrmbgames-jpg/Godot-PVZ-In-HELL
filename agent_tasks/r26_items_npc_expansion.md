# R26 — Physical items and modular NPC archetypes
Status: **PLANNED**

## Goal

Implement a data-driven expansion of physical items and district NPCs.

The feature has two pillars:

1. Every world item is a real `RigidBody3D` and reuses the existing physical grab / impact / inventory / damage / hazard contracts.
2. NPC identity is composed from a base archetype plus persistent modular traits/variation, while LimboAI Behavior Trees visibly own decision flow.

This root task owns overall status/current/next. Supporting specifications:
- `agent_tasks/r26_1_physical_items_and_effects.md`
- `agent_tasks/r26_2_npc_archetypes_and_variation.md`
- `agent_tasks/r26_3_npc_behavior_trees.md`
- `agent_tasks/r26_4_dialogue_variants.md`
- `agent_tasks/r26_5_integration_persistence_validation.md`

## Existing contracts to preserve

- Godot 4.7 / Jolt / GECS v8.
- Physical holding authority remains `item --R_HeldBy--> actor`; use `GrabService` / `E_GrabbableBody`.
- Native rigid-body physics owns transform and velocity.
- Damage enters only through `DamageRequest` / `DamageRequestService`; `C_Health` remains sole HP authority.
- Hazards spawn through `HazardSpawnService` and existing hazard definitions/scenes.
- Inventory ownership remains the existing `R_OwnedBy`/InventoryService contract.
- Persistent district identity remains `NpcRecord`; do not encode persistent identity in transient scene nodes.
- LimboAI Behavior Tree is the decision pattern. Do not hide a FSM/dispatcher in one `BTAction`.
- Dialogue uses the existing Dialogue Manager adapters/resources.
- Preserve current parcel service, schedule, memory, relationships, navigation, save/load, and existing owner-authored level geometry.

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

## Current

Specifications created. Implementation not started.

## Next

Start with R26.1. Do not implement NPC behavior before the shared item damage/tags contracts and archetype/trait data model are stable.

## Validation

Specification only; no engine/tests run.

## Owner QA / blockers

Exact balance values, final names, final dialogue prose, final models/animations/VFX/SFX and final item prices are intentionally author-tunable placeholders.

## Task state

### Goal

Implement the scope and acceptance specified in the Goal and required-design sections above.

### Current

PLANNED. Specification only; implementation has not started. Phase 1 task 03 normalizes metadata only; no R26 gameplay work is authorized by this repair.

### Validation

Specification only; no R26 engine or gameplay tests run. Use the validation requirements above when implementation is scheduled.

### Owner QA / blockers

No implementation blocker assessed. Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
