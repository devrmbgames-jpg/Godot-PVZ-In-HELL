# R22.5 — GECS Architecture Polish

Status: planned
Dependencies: R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22
Timing: execute after feature work is stable and before R23 vertical-slice validation.
Source: upstream GECS `addons/gecs/docs/BEST_PRACTICES.md` snapshot `69c7a2b9ad75f1a12a35c57895d6a751081055c0`, plus project `.agents/skills/gecs-v8/SKILL.md`.

## Goal

Refactor the working gameplay code toward GECS best practices without changing gameplay design.

This is intentionally late-roadmap polishing. Current systems are allowed to remain functional/legacy until R22.5; agents must not opportunistically perform this refactor while implementing R08-R22 unless a blocking bug requires a minimal local fix.

**Explicit exception:** `S_Damage` and `S_Impact` are owned by active R08 and must be cleaned up there immediately after R08 Milestone 5. Their System coupling/service-locator/impact-capture issues are **not deferred to R22.5**. R22.5 only re-audits them for regressions.

Primary principles:

- Components are pure data.
- Systems/sub-systems have one responsibility.
- Systems do not call other Systems.
- Query + `iterate()` is the hot-path data contract.
- Different component sets imply different Systems/sub-systems.
- Use `deps()` / SystemGroups for ordering.
- Use typed state/events/relationships instead of System service APIs.
- Use CommandBuffer for structural mutation during iteration.
- Keep Godot child-node references as Entity glue.
- Separate gameplay state from presentation.
- Separate dead/destroyed state from actual entity removal.
- RigidBody callback forwarding is the only physics orchestration exception.

## Milestone 0 — Relationship Authority Cleanup

Before broader System decomposition, normalize Entity-to-Entity authority that is still stored inside ordinary `C_*` Components. This milestone must preserve gameplay behavior; it changes ownership representation, lifecycle cleanup and lookup paths only.

### Goal

After this milestone:
- authoritative live Entity-to-Entity ownership/session/binding state uses `Relationship` + project `R_*` payloads;
- ordinary `C_*` Components contain intrinsic entity state/configuration or explicitly documented derived caches only;
- mirrored Entity references must not remain co-authorities;
- existing `R_HeldBy`, `R_PushedBy` and `R_HazardFollow` conventions remain the reference shape.

### M0.1 — Cart cargo binding: `C_CartCargo` -> Relationship

Current problem:
- `C_CartCargo.cart` is the authoritative `cargo -> cart` binding;
- `local_pose`, previous integration/sleep state and collision-exception bookkeeping describe the lifetime of that binding, not intrinsic cargo state;
- `C_CartTransport.cargo` mirrors the same ownership from the cart side.

Required target:
- replace `C_CartCargo` with an interaction Relationship payload, preferably `R_CartCargo` (or another equally explicit `R_*` name chosen once and used consistently);
- relationship direction is **cargo Entity -> cart Entity**;
- move binding-owned payload into the Relationship:
  - `local_pose`;
  - `previous_custom_integrator`;
  - `previous_can_sleep`;
  - `added_exception`;
  - any additional reversible lifecycle fields introduced during the refactor;
- Relationship presence is the single authority for whether cargo is currently attached to a cart;
- loading adds the Relationship; unloading/destruction/cart loss removes it and restores physics policy exactly once;
- stacked-cargo support checks must resolve the supporting cargo's cart through the Relationship, not an ordinary Component field.

`C_CartTransport.cargo: Array[Entity]`:
- remove it if pinned GECS relationship lookup is sufficient;
- otherwise it may remain only as an explicitly documented **derived/rebuildable cache** maintained from Relationship lifecycle;
- it must never be consulted as an independent authority when the Relationship disagrees.

`C_CartTransport.settling` is not automatically a Relationship: it is cart-local transient candidate timing and may remain ordinary runtime state unless implementation reveals a stronger ownership contract.

Acceptance:
- no project-owned `C_CartCargo` class/path/reference remains;
- no cargo ownership decision is made from a mirrored `Array[Entity]` alone;
- loading/unloading preserves current collision exception, custom integrator, sleep and local-pose behavior.

### M0.2 — Cart driver session: `C_CartTransport.driver` -> Relationship

Current problem:
- `C_CartTransport.driver` is explicitly the cart-side authoritative `cart -> actor` session;
- `capture_token` is lifecycle data of that session;
- `C_CartDriver.cart` mirrors the relation from the actor side.

Required target:
- introduce an interaction Relationship payload such as `R_CartDrivenBy`;
- relationship direction is **cart Entity -> actor Entity**;
- move `capture_token` and other session-lifetime bookkeeping out of `C_CartTransport` into the Relationship;
- `C_CartTransport` keeps authored cart motion configuration and intrinsic runtime motion state (`drive_speed`, `actual_velocity`, settling configuration/state as appropriate), not driver ownership;
- begin/end/lifecycle cleanup add/remove the Relationship idempotently;
- actor/cart removal must not leave a stale control capture.

`C_CartDriver`:
- prefer removing it if current-driver lookup can be expressed cleanly through pinned GECS Relationships;
- if a reverse actor-side index is required for hot lookup, keep it only as a **derived cache** whose comment and lifecycle make the Relationship the sole authority;
- never create two mutable ownership authorities.

Acceptance:
- `C_CartTransport` contains no authoritative `driver: Entity`;
- cart operation validity is proven from `R_CartDrivenBy`;
- no stale driver session/capture survives actor or cart teardown.

### M0.3 — Deliberate throw attribution: split `C_ThrowDamage`

Current problem:
- `C_ThrowDamage` mixes authored/capability configuration with temporary `source -> instigator` relationship state;
- `instigator`, `remaining_seconds` and `armed_tick` exist only while a deliberate throw attribution is active.

Required target:
- keep `C_ThrowDamage` as intrinsic/configuration data:
  - `throw_damage`;
  - `window_seconds`;
- represent an active deliberate throw with a gameplay Relationship such as `R_ThrownBy`, direction **thrown source Entity -> instigator Entity**;
- move relation-lifetime state into its payload:
  - `remaining_seconds`;
  - `armed_tick`;
- `ThrowContext.arm()` creates/replaces the relation after a valid throw;
- pickup/new grip, expiration and first qualifying impact remove the relation;
- `S_ThrowLifetime` (or its R22.5 replacement) processes the active relation rather than using a nullable Entity field in `C_ThrowDamage`;
- impact attribution reads the relation target;
- preserve current semantics if the instigator Entity becomes unavailable: do not invent durable identity behavior in this milestone. If later persistence requires durable attribution, add a stable ID contract separately rather than keeping a second live Entity authority.

Acceptance:
- `C_ThrowDamage` has no `instigator: Entity`, `remaining_seconds` or `armed_tick`;
- active throw attribution exists iff the throw Relationship exists;
- expiration/pickup/impact cleanup is idempotent;
- existing impact damage amount/window behavior is unchanged.

### M0.4 — Marker actor duplication: remove redundant Entity authority

Current problem:
- `C_Marker.actor` duplicates the holder already represented by the marker's authoritative `R_HeldBy.target`;
- drawing cannot currently begin or remain active unless the marker is held by that actor.

Required target:
- remove `C_Marker.actor`;
- derive the live actor from the marker's `R_HeldBy` relationship whenever starting/updating/ending a drawing session;
- keep marker-local session data that is not ownership (`capture_token`, pointer and stroke continuity) in the appropriate marker/session state;
- releasing/transferring the marker must terminate drawing and release capture using relationship lifecycle/session cleanup.

Do **not** introduce `R_DrawingBy` merely to replace the deleted field. Add a separate drawing Relationship only if the refactor proves that drawing-session ownership has semantics independent of `R_HeldBy` (for example, it can legitimately outlive or differ from the holder). Under current behavior it is redundant.

`C_Marker.parcel` is not part of this migration: it is transient current-stroke continuity state, not package ownership.

Acceptance:
- no `C_Marker.actor` remains;
- marker session validation has one holder authority: `R_HeldBy`;
- grip loss/transfer cannot leave a stale drawing capture.

### M0.5 — Explicit non-candidates / audit guard

Do not mechanically convert every Entity/Object reference into a Relationship.

Keep these as ordinary state unless a separate semantic reason is discovered:
- `C_Interactor.target`: transient gameplay targeting, not ownership;
- `C_PhysicsBodyRef.body`: GECS proxy -> Godot object reference, not Entity-to-Entity ownership;
- `C_GrabControl.held_carry/right/left`: derived reverse indexes for `R_HeldBy`; may be removed later, but are not new authoritative Relationships;
- `C_PushControl.pushed_object`: derived reverse index for `R_PushedBy`;
- `C_Hazard.origin` / `C_Hazard.instigator`: live attribution/cache only; actual follow/lifetime ownership is already `R_HazardFollow`, while stable string IDs carry durable attribution;
- `C_Marker.parcel`: transient stroke continuity.

During implementation, audit every remaining project-owned `C_*` field typed as `Entity`, `Array[Entity]` or equivalent Entity reference. For each one, classify it explicitly as:
1. intrinsic/transient state;
2. derived cache/index;
3. authoritative cross-Entity relation.

Any item in category 3 must become an `R_*` Relationship or be documented with a concrete reason why GECS Relationship semantics do not fit.

### M0.6 — Migration/validation requirements

- Preserve existing `.gd.uid` identity where moving/renaming an existing script is appropriate; update scene/resource/script references atomically.
- Use strict typing throughout.
- Do not introduce direct System-to-System service calls as part of the migration.
- Update `PROJECT_INDEX.md`, relevant subsystem docs and structure validation rules if canonical relationship paths/classes change.
- Update focused tests for cargo attach/detach, transport driver lifecycle, deliberate throw attribution/expiry and marker grip/session cleanup.
- Do not add broad new gameplay behavior.

Milestone validation:
1. `python utils/validate_project_structure.py`;
2. changed-file formatter/lint/static checks;
3. repository search confirms removed legacy classes/fields have no production references;
4. `git diff --check`;
5. no GUT/smoke/runtime invocation yet unless a blocking issue cannot be established statically.

Final R22.5 validation later covers the relevant GUT + headless smoke surfaces once, per project runtime budget.

### M0 implementation checklist

- [ ] M0.1 migrate cart cargo authority to an `R_*` Relationship and eliminate/coherently derive cart cargo reverse indexes.
- [ ] M0.2 migrate cart driver authority/capture token to an `R_*` Relationship; remove or explicitly derive `C_CartDriver`.
- [ ] M0.3 split `C_ThrowDamage` configuration from active `R_ThrownBy` attribution/lifetime.
- [ ] M0.4 remove `C_Marker.actor` and use `R_HeldBy` as the only holder authority.
- [ ] M0.5 audit every remaining Entity reference in project-owned Components and classify it.
- [ ] M0.6 update references/docs/tests/static validation and create one coherent local commit for this milestone.

---

## Existing good reference

`S_Jump` is the local shape to preserve:
- focused responsibility;
- narrow query;
- `iterate([C_Jump, C_Controller, C_Motion])`;
- no foreign System calls;
- no unrelated presentation/service surface.

Do not refactor a System merely because it is short or uses one justified boundary lookup.

---

## Audit summary

### Full current `S_*` disposition

The default-branch audit covered every current `content/systems/**/*.gd` System file. R22.5 must explicitly classify each one instead of refactoring only the largest files.

| Current class | R22.5 disposition |
| --- | --- |
| `S_Damage` | **R08-owned now.** R08 M5.1 removes service-locator submission and foreign System calls; R22.5 only verifies no regression. |
| `S_DayPhase` | Keep scheduled transition processing; remove static global service facade from System consumers. |
| `S_Impact` | **R08-owned now.** R08 M5.1 splits contact capture/resolution, query-driven throw lifetime and typed Damage submission; R22.5 only verifies no regression. |
| `S_Receiving` | Split phase reaction/batch scheduling from spawn-space/package construction and identity lookup. |
| `S_PlayerInput` | Keep raw input intent capture focused; move Push/Transport mode constraints to authoritative focus/state processing. |
| `S_CartCargo` | Legacy pseudo-System: separate real cargo lifecycle/query work from the RigidBody cargo solver; do not keep a static-only `System`. |
| `S_CartTransport` | Legacy pseudo-System: split session/control/drive/follow responsibilities; scheduled parts become real Systems/sub-systems, physics parts become solvers. |
| `S_Door` | Empty legacy System shell. Verify no later R13 requirement/reference needs it, then remove instead of growing a parallel Door architecture. |
| `S_Grab` | Highest-priority decomposition: holder input, ownership lifecycle, physical hold solver, helpers and typed transitions. |
| `S_InteractionTargeting` | Keep target selection authoritative; move mesh highlight to presentation and remove Grab System dependency. |
| `S_Marker` | Split session/control, sampling and package mark mutation; remove Grab/Targeting System calls. |
| `S_Push` | Split session/relationship lifecycle from independent cart and actor physics solvers. |
| `S_Crouch` | Legacy pseudo-System: reclassify physics/state solver and separate camera-only crouch interpolation from collision/state authority. |
| `S_Jump` | **Keep as the local reference shape** unless later feature work materially changes its contract. |
| `S_Look` | Reclassify static callback code as a non-System solver if it remains unscheduled; preserve gameplay-critical head/raycast/anchor Entity glue. |
| `S_Motion` | Reclassify static callback code as a non-System locomotion solver; remove Push/Transport dispatch. |

### Additional findings from the full-system audit

1. **Pseudo-Systems are a distinct cleanup class.** `S_CartTransport`, `S_CartCargo`, `S_Motion`, `S_Look` and `S_Crouch` currently have no meaningful GECS query/process contract and are primarily static service/physics surfaces. `S_Motion`, `S_Look` and `S_Crouch` are also registered as System nodes in the main scene despite being driven by the character physics callback. R22.5 must make the class identity and scene registration truthful.
2. **`S_Crouch` crosses the gameplay/presentation boundary.** The same physics callback toggles collision shapes / crouch state and interpolates `camera_root`. Preserve collision/state authority in the physics path, but move camera-only interpolation to a presentation consumer unless a concrete gameplay dependency is discovered.
3. **`S_Damage.submit()` is a service locator.** It scans `ECS.world.systems` to find the active `S_Damage` instance. Replace this with typed request/event/inbox wiring; do not generalize this lookup pattern.
4. **`S_Door` is currently an empty shell.** It is not registered in the audited main SystemGroups and no current default-branch reference was found by the repository search. Verify again after R13 is implemented, then remove it if still unused rather than using it as a dumping ground for Door logic.
5. **Cart cargo has duplicated mutable indexes.** `C_CartTransport.cargo/settling` coexist with per-cargo `C_CartCargo` bindings. During the Cart pass, choose one ownership authority and treat any reverse index/cache as derived and rebuildable; do not leave mirrored mutable collections as co-authorities.
6. **Not every large physics helper needs more Systems.** `S_Look` manipulates head axes that also parent gameplay raycasts/hold anchors, so R22.5 must preserve that Entity-glue contract. Split by authority/component set, not by line count.

### Priority A — structural coupling / large monoliths

#### S_Grab — highest priority

Current issues:
- ~668 lines;
- many unrelated public static APIs;
- input validation/routing, pickup/release/throw, relationship lifecycle, physics holding, slot queries, scene anchors, availability checks and math in one class;
- direct calls to `S_Impact`, `S_CartCargo`, `S_Marker`, `S_InteractionTargeting`;
- repeated `get_component()` / `has_component()` across hot and imperative paths.

Target:
- keep authoritative ownership in `R_HeldBy` Relationship;
- move relationship add/remove side effects fully into lifecycle Observer(s);
- separate holder input processing from physical hold solver;
- move pure slot/anchor/query math into non-System helper/service where it is not ECS processing;
- use focused query/sub-system component sets for holder processing;
- replace direct Impact/CartCargo/Marker calls with state/event/relationship transitions;
- keep RigidBody hold integration as an independent non-System physics solver called only from Entity physics callback.

#### S_Impact + S_Damage — moved forward to active R08

These issues were discovered during the R22.5 audit but are now an explicit **R08 Milestone 5.1 architecture gate**.

R08 owns:
- removal of `S_Impact -> S_Damage`, `S_Impact -> S_Grab` and `S_Damage -> S_Grab`;
- replacement of `S_Damage.submit()` system scanning with a typed request/inbox/event path;
- separation of physics contact capture from scheduled impact resolution;
- dedicated query + `iterate()` processing for `C_ThrowDamage` lifetime;
- preservation of existing R08 impact/dedup/throw/damage semantics.

R22.5 must not schedule this work again. It only verifies that later feature work did not reintroduce those anti-patterns.

#### S_Push

Current issues:
- session validation, Relationship lifecycle, derived actor cache, cart physics, actor-follow physics and LOS validation in one class;
- direct dependency on `S_Grab` and `S_InteractionTargeting`;
- many public static APIs;
- same architectural pattern that caused Transport coupling.

Target:
- Relationship remains Push authority;
- Observer owns relationship add/remove side effects;
- interaction/session request is separate from physics;
- cart physics solver and actor-follow solver are independent;
- Entity physics callback performs solver orchestration;
- no Push dispatch from `S_Motion`;
- no foreign System calls.

#### Cart Transport + Cart Cargo

Use the transport design already documented in the former atomic-system refactor:
- one authoritative transport binding;
- separate session lifecycle;
- input intent System;
- cart drive System/query;
- independent driver-follow physics solver;
- independent cargo query/lifecycle;
- no `S_CartTransport -> S_Grab/S_CartCargo`;
- no `S_Motion -> S_CartTransport`;
- no transport lookup from `S_PlayerInput`.

Do not preserve mirrored actor/cart mutable caches as co-authorities.

#### S_PlayerInput

Current issues:
- raw Godot input capture and gameplay intent generation are mixed with Push/Transport control-mode behavior;
- calls `S_Push.pushed_object()` and `S_CartTransport.current()`;
- look suppression and transport orientation are decided by querying foreign systems.

Target:
- raw input capture stays focused on writing `C_Controller` intent;
- actual mode/focus state is represented by Components/Relationships/InteractionControlFocus state;
- separate focused System/sub-system applies mode-specific intent constraints when required;
- no direct Push/Transport System calls;
- use query data instead of extra component lookup for long-drop settings where practical.

---

### Priority B — responsibility separation

#### S_InteractionTargeting

Current issues:
- owns both gameplay target selection and visual mesh highlight;
- depends on `S_Grab` helpers.

Target:
- targeting System writes only authoritative `C_Interactor.target`;
- highlight becomes presentation Observer/System reacting to target changes;
- raycast/held-exclusion data comes from Entity glue + authoritative relationships/non-System helper;
- presentation never participates in target validity.

#### S_Marker

Current issues:
- marker session lifecycle;
- input/session update;
- held-hand validation;
- raycast surface sampling;
- package ink mutation;
- presentation-facing surface conversion;
- direct calls to Grab/Targeting.

Target:
- marker control/session state separated from drawing sample application;
- package mark mutation is a focused System/Observer consuming typed samples;
- surface sampling uses Entity glue/non-System helper as needed;
- no foreign System calls;
- use `sub_systems()` if several cohesive marker query/process pairs remain in one feature class.

#### S_Receiving

Current issues:
- day-phase gating via `S_DayPhase.current()`;
- starts daily batches;
- checks duplicate Package IDs through an ad-hoc world query;
- performs spawn-space physics;
- instantiates/configures/registers Package;
- initializes identity/Health.

Target:
- Morning/day transition Observer creates/arms receiving batch state;
- receiving spawn System only processes pending receiving state;
- package identity lookup uses the established package registration/domain service or indexed state, not repeated broad lookup;
- spawn/configuration logic may use a non-System factory/helper for scene construction;
- structural world changes go through safe command/lifecycle pattern compatible with pinned GECS;
- no direct DayPhase System call.

#### S_DayPhase

Current issues:
- real ECS transition System plus static global query/service API `current/permits/submit`;
- other Systems can depend on it as a service.

Target:
- System remains transition processor over `C_DayCycle`;
- pure transition predicates may move to a non-System helper;
- commands arrive via typed request/state/event;
- consumers react to `C_DayCycle` / phase events rather than calling `S_DayPhase.current()`.

---

### Priority C — physics solver classification

#### S_Motion / S_Look / S_Crouch

Current issue:
- these classes are registered/named as ECS Systems but mainly act as static `_integrate_forces()` solvers;
- `S_Motion` additionally dispatches to Push/Transport;
- `S_Crouch` mixes collision/crouch-state authority with camera-only interpolation in the same physics callback;
- `S_Look` touches head axes that also parent gameplay raycasts/hold anchors, so those transforms are not automatically presentation-only.

Target:
- remove Push/Transport dispatch from Motion;
- if a class has no real ECS query/process responsibility, convert/rename it to a clearly named non-System physics solver/helper and remove stale SystemGroup registration;
- keep independent solver calls only at `E_RigidBodyCharacter._integrate_forces()`;
- keep crouch collision/state changes in the physics/state owner but move camera-only crouch interpolation to presentation;
- preserve gameplay-critical scene-child references such as head axes, raycasts, anchors and collision shapes on the Entity as GECS recommends.

Do not over-split cohesive locomotion/look math merely to reduce line count. Split only when ownership/data contracts differ.

---

## System/sub-system selection rule

Use a separate System when:
- responsibility is independently schedulable;
- it owns a different Component set;
- it has independent lifecycle/order;
- it should be enabled/disabled independently.

Use GECS `sub_systems()` when:
- one feature owns several distinct queries;
- the queries share one cohesive lifecycle/owner;
- separating them into unrelated System nodes adds no value.

Each sub-system still has:
- one focused query;
- explicit `iterate()` data when hot;
- no calls to another System.

Use a non-System service/helper when:
- the code is pure calculation;
- it is an imperative domain query that is not repeated ECS iteration;
- it wraps scene/physics utility behavior without owning ECS scheduling.

---

## Additional GECS best-practice pass

During R22.5 audit every project System/Observer for:

- pure-data Component violations;
- System with more than one unrelated responsibility;
- direct `S_* -> S_*` calls;
- System class used only as static service/helper;
- required Components fetched repeatedly instead of `iterate()`;
- overly broad query followed by manual filtering;
- SceneTree group query where Component query exists;
- direct structural mutation during active iteration instead of `cmd`;
- Observer used as per-frame state machine;
- Node child reference stored in reusable Component instead of Entity glue;
- duplicate relationship construction that merits a typed relationship factory;
- immediate entity deletion where a pending-delete lifecycle is required;
- gameplay/presentation mixed in the same System;
- redundant Entity/Node casts in hot loops.

Do not mechanically rewrite valid boundary code just to satisfy a metric.

---

## SystemGroups

The current main scene already separates systems into coarse groups:
- Input;
- GamePlay;
- Physics;
- Interaction.

Preserve scene-based groups.

During R22.5:
- verify each System is in the correct group;
- use group placement + `deps()` for ordering;
- do not encode processing order through direct System calls;
- introduce a late cleanup group only if PendingDelete/cleanup semantics require it.

---

## Implementation sequence

1. Baseline dependency graph of all `content/systems/**/*.gd`; classify every current `S_*` as keep, split, reclassify or remove.
2. Refactor Cart Transport/Cargo and remove Transport/Push dispatch from Motion/Input; establish one Cart/Cargo ownership authority.
3. Refactor Push lifecycle + physics boundaries.
4. Refactor Grab into focused ECS/lifecycle/physics/helper responsibilities.
5. Regression-audit the R08 Damage/Impact architecture gate; do not plan another broad `S_Damage`/`S_Impact` refactor unless later work reintroduced a violation.
6. Split raw PlayerInput from mode-specific constraints.
7. Separate InteractionTargeting from highlight presentation.
8. Split Marker session/sampling/ink mutation.
9. Split Receiving schedule/spawn and remove DayPhase System service dependency.
10. Reclassify Motion/Look/Crouch static solvers; remove stale SystemGroup nodes and split Crouch camera presentation from physics/state.
11. Audit remaining Systems/Observers against GECS checklist; verify `S_Jump` still needs no change and re-check/remove unused `S_Door`.
12. Update scene SystemGroups/deps and remove obsolete System nodes/classes/services after their replacements are wired.
13. Static architecture review, then one final allowed runtime regression pass under project validation budget.

Commit each numbered stage separately. Do not combine the entire refactor into one commit.

---

## Non-goals

- no gameplay redesign;
- no balance changes;
- no visual tuning;
- no new content;
- no GECS addon modifications;
- no speculative performance micro-optimization without evidence;
- do not start the broad R22.5 polish before R08-R22 are complete. Exception: Damage/Impact cleanup has explicitly moved into active R08 M5.1 and must happen there now.

---

## Completion criteria

- zero direct project System-to-System service calls, with no service-call exception inside Systems;
- every remaining `S_*` / `extends System` has real GECS-scheduled work; static-only solvers/helpers are non-System classes;
- zero registered no-op/pseudo-System nodes;
- zero System-instance lookup by scanning `ECS.world.systems` as a service locator;
- physics orchestration only at Godot Entity callback boundaries;
- hot Systems use specific queries + `iterate()` for required Components;
- large multi-responsibility Systems are split into atomic Systems/sub-systems/helpers;
- presentation is separated from gameplay authority, including crouch camera interpolation vs crouch collision/state;
- structural mutations during iteration use CommandBuffer/approved GECS lifecycle;
- dead/destroyed vs removal follows pending-cleanup semantics;
- main SystemGroups and `deps()` express execution order;
- behavior remains equivalent to pre-refactor gameplay;
- R23 runs against the polished architecture.
