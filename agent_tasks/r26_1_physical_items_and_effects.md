# R26.1 — Physical item framework and requested catalog
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Create the requested physical item catalog on top of the existing Jolt/GECS gameplay contracts.

**All world items are real `RigidBody3D` objects.** Do not replace thrown/held items with fake transform-driven props while they are in the world.

### Current

Baseline: `44a2a6df367c928dc72dbdd5b1bb316cd7daf8da`, dev; reviewed checkpoint
`ecc2b24e8c9d1c1ecfa054d48f08619eebb84a37`. All 15 items have native MCP-authored bodies.
PHYSICAL commerce materializes bodies; inventory categories stay separate from capabilities.
Shared sweep, contact episodes and break factory preserve attribution, lifetime and source veto.
Combat-owned C_Karma persists with strict authored thresholds; schema 13 rejects schema 12 before mutation.
Artifacts use native volumes, typed receiver tags/karma and DamageRequest HEAL/DAMAGE; restore restarts transient clocks.
Blood payloads use typed non-damaging native zones with larger barrel radius/TTL and passive reconstruction.
NPC perception now binds R_NpcBloodZone through LOS/FOV/light; spawn facts immediately calm perceived vampires.
Native trees expose approach/retention after danger and before combat; native Area overlap retains the body.
Other tagged unclean actors react only toward visible recognized instigators; failed routes are not retried per tick.
Brain reconstruction clears transient blood bindings/rejections; HP and durable memories keep their existing owners.
Blood review found unrelated-route rejection and reentrant receiver retirement/reset; scoped fixes pass native regressions.
Navigation results now identify the request/action/goal; pending planning cannot reject blood.
Perception stops after a social fact retires or resets its captured receiver. Targeted review remains pending.
Next: targeted review, catalog smoke, then modular NPC archetypes and receiver composition.
Preserve [R26 contracts](r26_items_npc_expansion.md#existing-contracts-to-preserve).

### Validation

Native logs: `.artifacts/godot_agent/`; names below use `{kind}-20261011-{stamp}.stdout.log`.
All accepted batches passed formatter, parser and relevant strict/static gates. Reviews use
consecutive immutable SHA ranges; reviewer VALIDATION NOT_RUN, serial/token comparison NOT_MEASURED.
- Damage: parser171357080; GUT171353779 8/8,55. Review `a8c5a83f8a69256e6c1bd3daa0ae8c4208216ed9`, no findings,34s.
- Bones: parser172224170; GUT172024637 16/16,129 and172219843 8/8,99. Native class scan fixed UID warnings.
  Review `c573beff8c2c5f0bfe25356bd3632d3ad8cfcfc0`, no findings,41s.
- Storage: parser172756196; GUT172821959 17/17,135 and172826250 32/32,414.
  Initial dependency declaration FAIL fixed. Review `4eba367f5b06073ec21737cb332178a280a1b6f9`, no findings,44s.
- Weapons: parser174642064; GUT174600769 15/15,194, native ray pickup/release/throw and contact snapshots.
  Review `e07ae9f016acb942079f57fe61348ddb46cdc6ac`, no findings,78s.
- Payloads: parser180741444; GUT180508009 8/8,169, real bounded Jolt throw/floor break and native area/explosion.
  Regressions GUT180156002 melee15/15,194;180547285 packages13/13,234;180600373 physics8/8,41;
  180632450 persistence22/22,213;180645765 queued lifetime13/13,100.
  Review `20497d37158d8d29943db36a2142c599a1022b91`, no findings,135s.
- Chains: parser181801371; GUT181727375 6/6,40, real contact/resting episode, held/source veto and attribution.
  Regressions181810657 payload8/8 and181820090 melee15/15. Review `dfb5e101deb02ce99125b1b973b28a7b7d2c3397`,no findings,36s.
- Karma: parser183129874; GUT182941944 4/4,40;183001794 snapshot32/32,394;183056049 physics8/8,41.
  Native player/placed override isolated recipes and pre-mutation malformed-state rejection.
  Review `e505d83e96a6eccbb5f4968c09a52125f1d50b0e`,no findings,136s.
- Artifacts: parser184241192; GUT184150165 7/7,104, real overlap/karma/resistance/heal/source veto/throw/lifetime.
  Regressions184300129 host2/2,260 and184336631 damage8/8,55. Forward-ray fixture corrected.
  Review `0665c83e12f451806b6e844fcc699774ee34d5a7`,106s, RV-001/P1 reused transient clock.
  FIXED `359dcd02c2c6f373df923d8e47db1716815fa554`; parser184906734; GUT184758090 33/33,407.
  Existing/fresh reset and rejected-save preservation verified; first run needed blood class registration.
  Targeted review ARCHITECTURE/STYLE PASS,no findings,16s.
- Blood foundation: parser185512611; GUT185450268 payload10/10,233 and185403337 persistence23/23,226.
  Real throw/break, attribution, no HP requests, TTL, missing marker and fresh/reused geometry verified.
  Review `876f99d044dc20e43f55ce79ff3dadefb9e5e8bd`,66s, RV-002/P2 authored Mesh material lost.
  FIXED `0a8f1a98a242e695f0478057bfeaaed0a0c801db`; parser185859504;
  GUT185832961 payload10/10 and185850118 persistence23/23 cover spawn/reused/fresh material_override.
  Targeted review ARCHITECTURE/STYLE PASS,no findings,16s.
- Native MCP tree tool: parser190752580; GUT190730338 4/4,23; live inspect/reload/save PASS.
  Review `d81e256f95ebf4ee1e70419f23ea9d961f0c9473`,69s, RV-003/P1 unbounded shared-DAG traversal.
  FIXED `ecc2b24e8c9d1c1ecfa054d48f08619eebb84a37`; GUT191241018 5/5,27; live diagnostics checked[].
  Whole-operation budget/refusal before mutation verified; targeted review ARCHITECTURE/STYLE PASS,no findings,15s.
- NPC blood: GUT192642226 7/7,91, actual composed bodies/LOS/overlap/native and customer trees,
  immediate windup cancel, social ATTACK/FLEE suppression, hidden/unreachable/expired targets and reentrant retirement.
  Parser192854798 17/17; GUT192930514 perception8/8,27 and192954230 community15/15,99 PASS.
  Initial fixture lacked mandatory district definition: corrected through NpcConstructionService; failed log192319169 preserved.
  GUT193204369 shared host2/2 and193216831 MCP authoring5/5,28 PASS; strict architecture/domain/project checks PASS.
  MCP saved both tree insertions and the new World Observer; editor unsaved count is zero.
  Review `d68cfa821c7227bdc6c5f4f79c8cdb5ede84c713`,165s: ARCHITECTURE FAIL, STYLE PASS.
  RV-004/P1 ACCEPTED: navigation failure did not identify the blood approach; request/action/goal provenance fixes it.
  RV-005/P1 ACCEPTED: cadenced social fact could retire/reset receiver; captured owner/state/generation guard fixes it.
  GUT194326551 10/10,120 covers stale/unrelated/same-goal action, pending planning, genuine failure and receiver retirement/reset.
  Parser194416896 9/9; GUT194442598 intent and194451640 perception PASS; all strict/static checks PASS.
  Initial new-test insertion parse failure corrected; log194306979 preserved. Targeted review pending.
- MCP native authored saves throughout. Loaded global script reload error43 remains NOT_PASS;
  fresh parser/GUT are actual independent PASS. No rendered gameplay or clean editor visual QA claimed.
- NOT_RUN: final 15-item physical smoke, archetype receiver composition and full owner acceptance.

### Owner QA / blockers

Subjective gameplay, dialogue, assets and balance require owner QA after implementation.
Required owner acceptance remains open; explicitly deferred polish gets a QA checklist.

## Required shared design

### Physical base

Prefer a shared project-owned physical-item scene/entity derived from the existing `E_GrabbableBody` contract, or extend the existing inventory pickup path where appropriate.

Use editable `.tscn` and direct Entity Traits with typed `.tres` tuning through the existing
compiler. Keep inventory/combat/hazard implementations in their current vertical domains.
Use [scene-authoring](../.agents/skills/godot-scene-authoring/SKILL.md),
[physics](../.agents/skills/godot-physics-4.7/SKILL.md) and
[combat](../.agents/skills/first-person-combat/SKILL.md) when implementing their contracts.

Every world item must:
- retain native rigid-body physics when free;
- use `R_HeldBy` + `GrabService` for physical holding/carrying where that capability is authored;
- preserve physical velocity/impact behavior on release/throw;
- route impact through the existing impact capture pipeline;
- never write HP directly.

Inventory ownership uses `R_OwnedBy` / `InventoryService`; physical holding uses `R_HeldBy`.
Current `InventoryService.can_transfer` rejects `C_Grabbable`, packages and furniture.
`E_InventoryPickup` may hide/freeze an owned body; `InventoryService.grant` may instead
create a virtual stack, and `InventoryDropService.drop` creates a native physical pickup.
Preserve quantity, ownership and failure behavior across that boundary. Do not require
every owned stack to retain the same body or add `C_Grabbable` to stack pickups by default.
If a requested item needs both hand slots and stack transfer, declare and validate that
contract change explicitly, including grip cleanup and rejection without item loss.
Large items remain physical and normally do not collapse into a stack.

### Capabilities, not item-specific dispatch

Represent reusable capabilities through typed definitions/components rather than `if item_id == ...`.

Required reusable concepts: handheld, large, melee/large-AOE melee, throwable,
explosive/breakable payload, hazard producer, contact damage, valuable, stackable and Health/destructible.

Reuse `C_MeleeWeapon`, `DEF_MeleeAttack`, `C_Health`, impact profiles, `HazardSpawnService`, inventory contracts and existing grab/throw behavior where possible.

### Item categories

Commerce and NPC preference tags support WEAPON, CLOTHING, ARTIFACT, REAGENT, TOY
and VALUABLE. An item may belong to several categories.

Do not equate gameplay capability with shopping category.

### Damage/effect types

Existing damage types must remain compatible. Add only the missing semantic types required by this feature:
- ACID
- HOLY
- UNHOLY

Keep FIRE, TOXIC, IMPACT, EXPLOSION, MELEE, etc. on the existing `DamageRequest` path.
Preserve existing serialized enum meanings/values; version any incompatible field interpretation.

Holy/unholy behavior must be data-driven by receiver tags/karma rules, not by checking scene names.

If no karma contract exists, introduce a minimal persistent player karma component/state and authored low/high thresholds. Exact thresholds are tuning data, not hard-coded gameplay constants.

Declare one Component owner and its explicit mutation boundary before adding karma;
dialogue/receiver tags must not create another mutable player-stat authority.

Introduce reusable receiver tags/capabilities sufficient to express:
- affected by holy damage;
- affected/healed by unholy effect;
- vampire;
- other unholy/unclean creature.

Do not infer these from class names.

## Requested items

Create authored definitions + physical scenes using placeholder meshes/materials where final assets do not exist.

All rows retain real rigid-body world physics and shared capability execution.

| Item | Capabilities/category | Required behavior |
| --- | --- | --- |
| Scythe / Коса | Handheld, melee, WEAPON | Larger melee AOE/cone than axe; physical when dropped/thrown. |
| Axe / Топор | Handheld, melee, WEAPON | Ordinary melee AOE. |
| Throwing knife / Метательный нож | Handheld, melee, throwable, WEAPON | Attributed impact/weapon damage once per valid contact episode. |
| Alchemical fire flask / Алхимический огонь | Handheld, throwable, breakable/explosive, REAGENT | FIRE damage and fire Hazard. |
| Toxin flask / Колба с токсинами | Handheld, throwable, breakable/explosive, REAGENT | TOXIC damage and toxic Hazard. |
| Explosive reagent flask / Колба с взрывным реагентом | Handheld, throwable, breakable/explosive, REAGENT | Explosion/impulse presentation with IMPACT health damage; no persistent fire/toxic hazard unless later authored. |
| Holy artifact / Святой артефакт | Handheld, effect source, ARTIFACT | HOLY damages authored unholy targets; player only below low-karma threshold, never neutral/high by this rule. |
| Unholy artifact / Нечистый артефакт | Handheld, effect source, ARTIFACT | UNHOLY heals authored unholy targets; damages player only above high-karma threshold, never neutral/low by this rule. |
| Bones / Кости | Stackable world pickup, VALUABLE | No special damage behavior. |
| Acid barrel / Бочка с кислотой | Large, Health/destructible, breakable/explosive | ACID damage/Hazard; no normal hand inventory stack. |
| Alchemical solution barrel / Бочка с алхимическим раствором | Large, Health/destructible, breakable/explosive | FIRE damage/Hazard; no normal hand inventory stack. |
| Spiked chains / Цепи с шипами | Physical, CONTACT_DAMAGE, VALUABLE | Valid contact damage once per episode; no per-frame resting damage. |
| Slave collar / Ошейник для раба | Physical, VALUABLE | No extra gameplay behavior required in this milestone. |
| Blood flask / Колба крови | Handheld, throwable, breakable, REAGENT | Non-damaging Blood Hazard; behavioral stimulus only. |
| Blood barrel / Бочка крови | Large, Health/destructible, breakable | Same non-damaging Blood Hazard with larger authored radius/duration; no direct blood damage. |

Blood immediately calms a vampire and attracts/retains it in a perceived valid zone;
other authored unholy creatures may become aggressive. Both blood items share this meaning.
Healing uses `DamageRequest.Operation.HEAL` through `O_Damage`, never direct Health writes.

## Break/throw attribution

For thrown and explosive items preserve:
- real instigator;
- physical source item;
- stable origin ID when the source disappears;
- no self/holder double-hit;
- no damage replay from resting contacts;
- `C_NoDamage`/existing source veto behavior.

Breaking an item may spawn a hazard/explosion, but the spawned effect must use the existing hazard factory/event path.

Systems own periodic contact/hazard work; Observers react once to committed break/depletion
facts. Preserve package destruction/replacement contracts; generic item payloads do not
require fake `C_Package` identity. Fact publication follows visible registration/state/link
mutation. `DamageRequestService.submit()` dispatch success is not committed damage;
consume `DamageResult` for effects/social consequences. Queued owners resolve at the existing
lifetime boundary before typed calls; capture source IDs/context before source retirement.

## Acceptance

- Every requested world item root/body is a real `RigidBody3D`.
- Handheld items can be picked up/released/thrown through existing grab contracts.
- Large barrels remain physically simulated and destructible.
- No item directly edits `C_Health.current`.
- No central item-ID dispatcher implements the catalog.
- Damage types/resistances and blood/holy/unholy receiver selection are typed/data-driven.
- Stackable bones use existing inventory ownership and return to a real rigid-body pickup
  through the existing drop boundary; a rejected transfer/drop preserves quantity and ownership.
- Contact damage is episode-bounded.
- Focused tests cover throw attribution, break once, hazard spawn once, resistance/heal rules, inventory ownership and resting contacts.

## Validation requirements

Near completion: changed-script parser, structure check, focused GUT for item/damage/hazard surface, and one bounded headless physical smoke. No rendered playtest without owner approval.
