# R26.1 — Physical item framework and requested catalog
Status: **PLANNED**

Parent: `agent_tasks/r26_items_npc_expansion.md`

## Goal

Create the requested physical item catalog on top of the existing Jolt/GECS gameplay contracts.

**All world items are real `RigidBody3D` objects.** Do not replace thrown/held items with fake transform-driven props while they are in the world.

## Required shared design

### Physical base

Prefer a shared project-owned physical-item scene/entity derived from the existing `E_GrabbableBody` contract, or extend the existing inventory pickup path where appropriate.

Every world item must:
- retain native rigid-body physics when free;
- use `R_HeldBy` + `GrabService` when held/carried;
- preserve physical velocity/impact behavior on release/throw;
- route impact through the existing impact capture pipeline;
- never write HP directly.

Inventory-capable items may hide/freeze their world body while owned using the existing inventory lifecycle. Large items remain physical and normally do not collapse into a stack.

### Capabilities, not item-specific dispatch

Represent reusable capabilities through typed definitions/components rather than `if item_id == ...`.

Required concepts:
- handheld;
- large;
- melee weapon;
- large-AOE melee;
- throwable;
- explosive/breakable payload;
- hazard producer;
- contact damage;
- valuable;
- stackable;
- has Health/destructible.

Reuse `C_MeleeWeapon`, `DEF_MeleeAttack`, `C_Health`, impact profiles, `HazardSpawnService`, inventory contracts and existing grab/throw behavior where possible.

### Item categories

Add an authored category/tag contract usable by commerce and NPC order preferences. At minimum support:
- WEAPON
- CLOTHING
- ARTIFACT
- REAGENT
- TOY
- VALUABLE

An item may belong to several categories.

Do not equate gameplay capability with shopping category.

### Damage/effect types

Existing damage types must remain compatible. Add only the missing semantic types required by this feature:
- ACID
- HOLY
- UNHOLY

Keep FIRE, TOXIC, IMPACT, EXPLOSION, MELEE, etc. on the existing `DamageRequest` path.

Holy/unholy behavior must be data-driven by receiver tags/karma rules, not by checking scene names.

If no karma contract exists, introduce a minimal persistent player karma component/state and authored low/high thresholds. Exact thresholds are tuning data, not hard-coded gameplay constants.

Introduce reusable receiver tags/capabilities sufficient to express:
- affected by holy damage;
- affected/healed by unholy effect;
- vampire;
- other unholy/unclean creature.

Do not infer these from class names.

## Requested items

Create authored definitions + physical scenes using placeholder meshes/materials where final assets do not exist.

### Scythe / Коса
- handheld;
- melee weapon;
- deliberately larger melee AOE/cone than the axe;
- physical RigidBody when dropped/thrown;
- weapon category.

### Axe / Топор
- handheld;
- melee weapon;
- ordinary melee AOE;
- weapon category.

### Throwing knife / Метательный нож
- handheld;
- usable as melee weapon;
- throwable;
- thrown physical body can deal attributed impact/weapon damage once per valid contact episode;
- weapon category.

### Alchemical fire flask / Алхимический огонь
- handheld;
- throwable;
- breakable/explosive;
- creates FIRE damage and a fire Hazard;
- reagent category.

### Toxin flask / Колба с токсинами
- handheld;
- throwable;
- breakable/explosive;
- creates TOXIC damage and toxic Hazard;
- reagent category.

### Explosive reagent flask / Колба с взрывным реагентом
- handheld;
- throwable;
- breakable/explosive;
- explosion/impulse presentation may be explosive, but requested health damage is IMPACT-oriented;
- reagent category;
- no persistent toxic/fire hazard unless authored later.

### Holy artifact / Святой артефакт
- handheld;
- artifact category;
- Hazard/effect source;
- HOLY damage affects authored unholy targets;
- also damages player only when player karma is below the authored low-karma threshold;
- neutral/high-karma player is not damaged by this rule.

### Unholy artifact / Нечистый артефакт
- handheld;
- artifact category;
- Hazard/effect source;
- UNHOLY effect heals authored unholy targets;
- damages player only when player karma is above the authored high-karma threshold;
- neutral/low-karma player is not damaged by this rule.

Healing must still go through `DamageRequest.Operation.HEAL`, not direct Health mutation.

### Bones / Кости
- valuable category;
- stackable inventory item;
- physical pickup while in world;
- no special damage behavior.

### Acid barrel / Бочка с кислотой
- large physical RigidBody;
- C_Health/destructible;
- breakable/explosive payload;
- produces ACID Hazard and acid damage;
- not a normal hand inventory stack.

### Alchemical solution barrel / Бочка с алхимическим раствором
- large physical RigidBody;
- C_Health/destructible;
- breakable/explosive payload;
- produces FIRE damage/Hazard;
- not a normal hand inventory stack.

### Spiked chains / Цепи с шипами
- valuable category;
- physical item;
- reusable CONTACT_DAMAGE capability while a valid physical contact occurs;
- prevent repeated per-frame damage from one resting contact episode.

### Slave collar / Ошейник для раба
- valuable category;
- physical item;
- no additional gameplay behavior required in this milestone.

### Blood flask / Колба крови
- handheld;
- throwable;
- breakable into a **non-damaging Blood Hazard**;
- Blood Hazard is behavior stimulus, not HP damage;
- vampire: immediately calms and prefers/stays inside the blood zone while it is valid;
- other authored unholy creatures: blood zone may provoke aggression;
- reagent category.

### Blood barrel / Бочка крови
- large physical RigidBody;
- C_Health/destructible;
- breaking creates the same non-damaging Blood Hazard at larger authored radius/duration;
- vampire/other-unholy behavioral reactions are identical in meaning to the flask;
- no direct damage solely because it is blood.

## Break/throw attribution

For thrown and explosive items preserve:
- real instigator;
- physical source item;
- stable origin ID when the source disappears;
- no self/holder double-hit;
- no damage replay from resting contacts;
- `C_NoDamage`/existing source veto behavior.

Breaking an item may spawn a hazard/explosion, but the spawned effect must use the existing hazard factory/event path.

## Acceptance

- Every requested world item root/body is a real `RigidBody3D`.
- Handheld items can be picked up/released/thrown through existing grab contracts.
- Large barrels remain physically simulated and destructible.
- No item directly edits `C_Health.current`.
- No central item-ID dispatcher implements the catalog.
- Damage types/resistances and blood/holy/unholy receiver selection are typed/data-driven.
- Stackable bones use existing inventory ownership.
- Contact damage is episode-bounded.
- Focused tests cover throw attribution, break once, hazard spawn once, resistance/heal rules, inventory ownership and resting contacts.

## Validation

Near completion: changed-script parser, structure check, focused GUT for item/damage/hazard surface, and one bounded headless physical smoke. No rendered playtest without owner approval.
