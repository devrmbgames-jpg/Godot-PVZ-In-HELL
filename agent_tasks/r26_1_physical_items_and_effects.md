# R26.1 — Physical item framework and requested catalog
Status: **IN_PROGRESS**

Parent: [R26](r26_items_npc_expansion.md).

## Task state

### Goal

Create the requested physical item catalog on top of the existing Jolt/GECS gameplay contracts.

**All world items are real `RigidBody3D` objects.** Do not replace thrown/held items with fake transform-driven props while they are in the world.

### Current

Baseline: `44a2a6df367c928dc72dbdd5b1bb316cd7daf8da`, `dev`.
Reviewed checkpoint: `e505d83e96a6eccbb5f4968c09a52125f1d50b0e`.
Thirteen of 15 items have native MCP-authored RigidBody scenes and focused evidence:
bones, axe, scythe, knife, three reagent flasks, acid/fire barrels, collar, chains and two artifacts.
Categories remain separate from capabilities; PHYSICAL purchases/deliveries materialize
native bodies and cannot become virtual stacks. Existing furniture courier policy stays.
Shared sweep keeps default one target; scythe permits four with synchronous cancellation.
Breakable payloads reuse C_Health/impact/emitter/retirement and the existing hazard factory.
A contact snapshot preserves thrower identity across both directions and synchronous free.
Reagent explosion uses IMPACT HP damage with a separate native radial impulse.
Authored contact damage reuses System episode ownership, bypasses impact protection,
rejects resting contacts and never cuts its physical holder. Two blood items remain.
Player karma is now a combat-owned C_Karma with KarmaService as its explicit runtime writer.
Persistence alone restores its validated SAVE_FIELDS; authored thresholds are strict and
their boundary values neutral. Native player Trait survives main-level component overrides.
Schema 13 requires this state and rejects schema 12 before mutation; no old-save conversion.
Artifacts use authored physical Area3D volumes and S_ReceiverEffect cadence; immutable
C_ReceiverTraits chooses creature damage/heal, with player karma taking precedence.
All HP changes pass through DamageRequest/O_Damage, with resistance, source veto,
held/thrown actor attribution and queued lifetime checks. Artifact clocks restart with
a full interval after reconstruction; no pending health request is restored.
Blood stimulus, two blood items and final catalog smoke remain unfinished.

Next: blood stimulus and remaining two physical items, then final catalog smoke.
Preserve [R26 contracts](r26_items_npc_expansion.md#existing-contracts-to-preserve).

### Validation

Evidence below is under `.artifacts/godot_agent/`; all native runs use Godot 4.7.1.
- PASS damage: parser 3/3 `parsefiles-20261011-171357080.stdout.log`;
  GUT 8/8 `gut-20261011-171353779.stdout.log`; formatter/architecture.
  Fixed warning-name table before acceptance. Review target `a8c5a83f8a69256e6c1bd3daa0ae8c4208216ed9`, no findings, 34 s.
- PASS bones: parser 5/5 `parsefiles-20261011-172224170.stdout.log`;
  stack GUT 16/16,129 `gut-20261011-172024637.stdout.log`; physical drop/isolation GUT
  8/8,99 `gut-20261011-172219843.stdout.log`; formatter/static. Native scan fixed UID warnings.
  Review target `c573beff8c2c5f0bfe25356bd3632d3ad8cfcfc0`, no findings, 41 s.
- PASS storage: parser 7/7 `parsefiles-20261011-172756196.stdout.log`; inventory
  17/17,135 `gut-20261011-172821959.stdout.log`; purchase/arrival 32/32,414
  `gut-20261011-172826250.stdout.log`; formatter/static. Initial dependency FAIL fixed
  by explicit read-method API declaration. Review target `4eba367f5b06073ec21737cb332178a280a1b6f9`, no findings, 44 s.
- PASS weapons: parser 9/9 `parsefiles-20261011-174642064.stdout.log`; melee
  15/15,194 `gut-20261011-174600769.stdout.log`; formatter/static. Native ray pickup,
  release and throw; episode tests inject contact snapshots. Weapon review no findings, 78 s.
- PASS payload batch: parser 13/13 `parsefiles-20261011-180741444.stdout.log`;
  GUT 8/8,169 `gut-20261011-180508009.stdout.log`; formatter13 and architecture/domain
  structure/dependencies strict/project structure. Actual bounded Jolt flask/floor contact,
  area FIRE ticks, one break/spawn, native explosion impulse and stable ID after actor free.
- PASS regression: melee15/15,194 `gut-20261011-180156002.stdout.log`; packages13/13,234
  `gut-20261011-180547285.stdout.log`; character physics8/8,41
  `gut-20261011-180600373.stdout.log`; persistent hazards22/22,213
  `gut-20261011-180632450.stdout.log`; queued lifetime13/13,100
  `gut-20261011-180645765.stdout.log`.
- Reviews use consecutive immutable SHA ranges, ARCHITECTURE/STYLE PASS,
  reviewer VALIDATION NOT_RUN; serial/token comparison NOT_MEASURED.
  Payload review to `20497d37158d8d29943db36a2142c599a1022b91`: no findings, 135 s.
- PASS chains: native parser4/4 `parsefiles-20261011-181801371.stdout.log`; GUT6/6
  `gut-20261011-181727375.stdout.log`, including native collision/resting and episode
  separation, held/source veto and attribution. Formatter4 and strict/static checks PASS.
  Payload8/8 regression `gut-20261011-181810657.stdout.log` and melee15/15
  `gut-20261011-181820090.stdout.log` PASS. Review to
  `dfb5e101deb02ce99125b1b973b28a7b7d2c3397`: no findings, 36 s.
- PASS karma: parser10/10 `parsefiles-20261011-183129874.stdout.log`;
  GUT4/4,40 `gut-20261011-182941944.stdout.log`; snapshot32/32,394
  `gut-20261011-183001794.stdout.log`; character physics8/8,41
  `gut-20261011-183056049.stdout.log`; formatter10 and strict architecture/domain
  structure/dependencies/project checks. Native player and placed override each get
  one isolated recipe; real slot restore and malformed/missing state rejection.
  Review to `e505d83e96a6eccbb5f4968c09a52125f1d50b0e`: no findings, 136 s.
- PASS artifacts: native parser6/6 `parsefiles-20261011-184241192.stdout.log`;
  GUT7/7,104 `gut-20261011-184150165.stdout.log`; formatter6 and strict/static checks.
  Actual native area overlaps, player/tag precedence, resistance and heal cap, cadence,
  source veto, native pickup/throw attribution, disabled source and queued retirement.
  Shared host startup2/2 `gut-20261011-184300129.stdout.log` and damage feedback8/8
  `gut-20261011-184336631.stdout.log` regressions PASS.
  Initial pickup fixture aimed an oblique ray that gameplay correctly reset; fixed to
  the actual forward interaction ray. Review target
  `0665c83e12f451806b6e844fcc699774ee34d5a7`: RV-001 identified, 106 s.
  RV-001/P1: reused artifact retained transient clock during restore. Accepted and fixed
  at the existing reconstruction boundary with explicit passive restore permission.
  GUT33/33 `gut-20261011-184758090.stdout.log` verifies existing/fresh artifact clocks
  reset to zero, next 0.1 s stays incomplete, rejected snapshot preserves 0.9 s.
  First run exposed unregistered new blood classes; native MCP class scan resolved it.
  Fix checkpoint re-review pending commit; artifact milestone remains REVIEW_PENDING.
- MCP native scene/resource saves used throughout. Loaded script hot reload error43:
  NOT_PASS; fresh-process parser/GUT passed. Do not equate staged authoring logs with clean editor QA.
- NOT_RUN: full 15-item/receiver/blood acceptance and final catalog physical smoke.

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
