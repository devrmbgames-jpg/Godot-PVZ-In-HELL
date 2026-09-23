# Damage, impact and Package condition (R08)

## Health authority and events

`C_Health` follows the user's attribute model: `base` is authored HP, `value` is computed maximum HP, `current` is remaining HP. `O_Damage` is the only gameplay HP writer. Initialization/reset is separate. `DamageRequestService.submit()` snapshots a request and emits `DamageRequest.EVENT`; its optional builder uses the same path. No System lookup or `S_Damage` exists.

Null, unavailable and non-Health targets are rejected at entry (false). The Observer validates finite positive amounts, live source, valid current/max Health and operation. `C_NoDamage` is a source-side veto for DAMAGE, producing BLOCKED without mutating HP; incoming damage and HEAL remain permitted. A null source represents the environment. `source` identifies the actual damaging Entity, while `instigator` records a throwing actor separately.

`DamageResult.EVENT` carries the copied request, applied amount, old/new HP and pre-reaction world pose. Positive HP crossing zero sets `depleted` before current-value notifications and emits HEALTH_DEPLETED once. Later damage/healing cannot revive it. Reentrant consumers must defer removal until mandatory lifecycle hooks have run.

`O_HealthLifecycle` reacts only to `C_Living`, adds `C_Death` once and performs the existing control/grip cleanup. Package does not have C_Living and never receives C_Death. `O_PackageDamage` sets DAMAGED only when remaining HP falls to or below the package definition's `damaged_health_ratio` of effective maximum HP (ordinary default 0.60, authored fragile supply 0.85). DESTROYED remains exclusive to Health depletion; it releases interactions/cargo and clears ink. Minor nonlethal hits no longer create the Damaged state. Destruction does not delete the physical package or release warehouse registration numbers.

`C_HealthDepletionEffects` is optional authored data: `DEF_DepletionSpawn` entries contain PackedScenes and local offsets; VFX/SFX are separate presentation hooks. `O_DepletionEffects` commits its guard before creating independent scene instances and emits `HealthDepletionEvent.EVENT` after dispatch. Instances do not inherit combat/throw attribution. Package currently spawns one flattened-cardboard placeholder. Content/drop entries can be authored in the same list; actual contents, VFX/SFX consumers, gore and cleanup assets are outside R08.

## Physical contacts and GECS boundaries

`ImpactCaptureSolver` is a non-System physics bridge. E_GrabbableBody and E_RigidBodyCharacter invoke it before their motion/holding solvers. It only writes `PhysicsContact` snapshots into a runtime `C_ImpactInbox`; it never mutates HP or locates Systems. Additional custom physics Entities should forward their own integration callback to this same bridge.

`S_Impact` enables contact reporting when rigid Entities enter the World and owns their runtime inboxes. Its explicit `with_all([C_ImpactInbox]).iterate(...)` query drains inboxes across all archetype batches, then one command-buffer flush coalesces reports and resolves each pair. Empty queries are supported. Held-object/holder contacts are excluded using authoritative C_HeldBy relationships directly. No S_Grab service dependency exists in impact processing.

A pair resolves once per contact episode, including harmless contacts. `body_exited` marks real separation; a later physics snapshot rearms the pair. Resting/sleeping contacts stay consumed. Removal/disable clears pending/pair state; separated stale records expire. Different pairs have independent state.

Each physical contact evaluates A -> B and B -> A separately. Targets require C_Health + C_ImpactReceiver. Tuning lives in immutable DEF_ImpactProfile assets. The physical base is:

```
energy = min(0.5 * source_mass * normal_speed^2,
             0.5 * measured_normal_impulse * normal_speed)
damage = max(0, energy - absorption_joules) * damage_per_joule
```

Closing normal speed and measured impulse must both cross profile thresholds. No damage uses render FPS or total linear speed alone. An immovable environment uses the receiver's moving mass, never infinite source mass. Each callback sums its manifold's normal impulses; mirrored reports are coalesced by maximum rather than double-counted. The pure calculation is in `ImpactCalculation`. It uses the existing project's Jolt world-axis contact convention; API reference: [PhysicsDirectBodyState3D](https://docs.godotengine.org/en/latest/classes/class_physicsdirectbodystate3d.html).

`C_ThrowDamage` is optional. `ThrowContext` arms it only after actual throw release/impulse. `S_ThrowLifetime` has its own C_ThrowDamage iterate query and counts simulation seconds. The first physically qualifying hit consumes the bonus, even if receiver protection blocks it; ordinary drops/pushes never arm it. Pickup, expiry and source removal/disable cancel context. A physically valid hit may earn the bonus even when absorption reduces base HP damage to zero. Source-side veto remains exclusively in O_Damage.

Severity (None/Weak/Medium/Strong) classifies total potential damage. `C_ImpactProtection.tier` fully blocks severity up to the configured tier; stronger impacts retain full damage. Protected impacts emit ImpactResult with protected=true and amount=0, without an HP request. Other damage types bypass this impact-specific protection. R19 owns the future Bubble Wrap inventory item/application. ImpactResult is attempted physical feedback, not proof that O_Damage accepted the HP request.

## Package setup, tilt and opening

`O_PackageConditionSetup` initializes definition Health/profile once for both authored and received packages. Save loaders must restore runtime state with the initialization guard set before World registration. Fragile supply definitions explicitly select `impact_fragile.tres`; generic impact never branches on package tags. Heavy damage comes from real rigid mass. Profiles were retuned after user playtesting and require re-validation: regular parcels use minimum_speed 5 m/s, minimum_impulse 3 N*s, absorption 200 J and 0.0175 HP/J; fragile parcels use 2.5 m/s, 1 N*s, absorption 30 J and 0.1 HP/J. Both sets are deliberately more than twice as resilient around the absorption threshold than the initial proposed tuning. Each profile also caps *physical* HP loss per contact episode at a fraction of the effective maximum: 0.075 regular / 0.15 fragile. Severity and protection are resolved from uncapped potential damage before applying this cap; ordinary healing, liquid and future non-impact damage are not capped. Profiles and state thresholds still require user playtesting.

Liquid definitions receive C_LiquidTilt. `S_LiquidTilt` uses a focused iterate query and continuous unsafe exposure: angle beyond the configured limit must persist for the entire duration; returning upright resets elapsed time to zero. One committed exposure marks DAMAGED/Leaking and publishes typed hooks. Optional HP loss uses DamageRequest.Type.LIQUID, not IMPACT. No repeated spill ticks or R09 hazard behavior are implemented.

`DEF_OpenPackageAction` exposes F/open through the existing action resolver. `PackageOpening` checks live actor/package, control focus, physical reach and first-hit LOS, or the actor's own held relationship. `PackageOpenRequest` is consumed by O_PackageOpening, which revalidates and commits OPENED before notifying subscribers. Recipient/registration/damage condition does not forbid opening. Opening itself applies no damage and never repeats its event. Carry retains target-action priority and falls back to the carried package's authored action.

`PackageLifecycleEvent.EVENT` carries stable package ID, physical Entity, transition kind, actor and optional DamageResult. Damaged/Destroyed/Opened/Leaking are the typed R09/R11 seam. No money, customer or hazard consequences run here. PackageConditionView displays persistent condition labels and owns no gameplay state.

## Validation handoff

The user explicitly owns all runtime, physics and visual validation. No Godot, GUT or smoke invocation was run for this R08 continuation. Static structure/formatter/diff checks and read-only code review do not establish physics correctness or tuning. The existing damage_smoke observer adapter was updated but not executed. Manual checklist: [R08 manual validation](r08_manual_validation.md).
