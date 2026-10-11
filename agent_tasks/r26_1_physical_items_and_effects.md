# R26.1 — Physical item framework and requested catalog
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Create the requested physical item catalog on top of the existing Jolt/GECS gameplay contracts.

**All world items are real `RigidBody3D` objects.** Do not replace thrown/held items with fake transform-driven props while they are in the world.

### Current

Implementation baseline: `44a2a6df367c928dc72dbdd5b1bb316cd7daf8da`, `dev`.
Semantic damage checkpoint: `a8c5a83f8a69256e6c1bd3daa0ae8c4208216ed9`.
ACID/HOLY/UNHOLY append after existing values 0..7; resistance, committed feedback,
HEAL bypass and HUD labels use the existing damage authority.
Bones/category checkpoint: `c573beff8c2c5f0bfe25356bd3632d3ad8cfcfc0`.
It adds six independent shopping-category flags and inert VALUABLE stacks.
Authored bones Definition, stack recipe and RigidBody pickup are saved through live MCP.
Data-only item Definition/Component support native editor instantiation with `@tool`.
Shared physical storage batch appends `Kind.PHYSICAL`: purchases and terminal deliveries
materialize native bodies through the existing placement transaction; grant/transfer
reject virtual ownership even without C_Grabbable. Marked furniture-only trader courier
eligibility remains in its existing rule. No central item-ID dispatch was introduced.
No receiver eligibility, karma or new hazard execution is claimed yet; 14 catalog items remain.

Next: authored item category/capability definitions and receiver/karma ownership,
then physical catalog and shared payload/contact execution. Preserve the contracts
in [R26](r26_items_npc_expansion.md#existing-contracts-to-preserve).

### Validation

- PASS: initial damage contract batch, native Godot 4.7.1 parser 3/3;
  `.artifacts/godot_agent/parsefiles-20261011-171357080.stdout.log`.
- PASS: focused damage feedback GUT 8/8;
  `.artifacts/godot_agent/gut-20261011-171353779.stdout.log`.
  Regression found and fixed the eight-entry warning-name table before acceptance.
- PASS: incremental formatter/role naming (3 scripts), architecture strict.
- PASS: independent scoped damage review from implementation baseline to
  `a8c5a83f8a69256e6c1bd3daa0ae8c4208216ed9`; no material findings,
  ARCHITECTURE/STYLE PASS, reviewer VALIDATION NOT_RUN; 34 seconds,
  serial/token comparison NOT_MEASURED.
- PASS: bones stack/inert-use GUT 16/16, 129 assertions;
  `.artifacts/godot_agent/gut-20261011-172024637.stdout.log`.
- PASS: physical inventory GUT including bones drop/pickup, rejected drop and
  per-instance recipe isolation, 8/8 and 99 assertions;
  `.artifacts/godot_agent/gut-20261011-172219843.stdout.log`.
  New UID warnings were resolved by native editor filesystem scan before acceptance.
- PASS: bones batch native parser 5/5, formatter/role naming 5 scripts,
  architecture/domain structure/domain dependencies strict;
  `.artifacts/godot_agent/parsefiles-20261011-172224170.stdout.log`.
- PASS: independent bones/category review from damage checkpoint to
  `c573beff8c2c5f0bfe25356bd3632d3ad8cfcfc0`; no material findings,
  ARCHITECTURE/STYLE PASS, reviewer VALIDATION NOT_RUN; 41 seconds,
  serial/token comparison NOT_MEASURED.
- PASS: shared physical storage batch native parser 7/7,
  `.artifacts/godot_agent/parsefiles-20261011-172756196.stdout.log`;
  focused inventory GUT 17/17, 135 assertions,
  `.artifacts/godot_agent/gut-20261011-172821959.stdout.log`.
- PASS: physical purchase/courier/arrival regression including PHYSICAL purchase
  and terminal fulfillment;
  `.artifacts/godot_agent/gut-20261011-172826250.stdout.log`.
- PASS: physical storage formatter/role naming 7 scripts, strict architecture,
  domain structure and dependencies. Independent storage review pending commit.
- MCP edits used native script patching. Tests reloaded without diagnostics;
  loaded DamageRequest and HUD script hot reload returned error 43, so live reload
  is NOT_PASS. Fresh-process native parser/GUT passed; editor log gained no new entries.
- NOT_RUN: full item/hazard/inventory catalog acceptance and physical smoke.
  Initial damage contract batch does not close R26.1.

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
