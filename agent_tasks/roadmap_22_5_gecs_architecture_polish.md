# R22.5 — GECS Architecture Polish

Status: planned
Dependencies: R08, R09, R10, R11, R11.1, R12, R13, R14, R15, R16, R17, R18, R19, R20, R21, R22
Timing: execute after feature work is stable and before R23 vertical-slice validation.
Source: upstream GECS `addons/gecs/docs/BEST_PRACTICES.md` snapshot `69c7a2b9ad75f1a12a35c57895d6a751081055c0`, plus project `.agents/skills/gecs-v8/SKILL.md`.

## Goal

Refactor the working gameplay code toward GECS best practices without changing gameplay design.

This is intentionally late-roadmap polishing. Current systems are allowed to remain functional/legacy until R22.5; agents must not opportunistically perform this refactor while implementing R08-R22 unless a blocking bug requires a minimal local fix.

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

### Priority A — structural coupling / large monoliths

#### S_Grab — highest priority

Current issues:
- ~668 lines;
- many unrelated public static APIs;
- input validation/routing, pickup/release/throw, relationship lifecycle, physics holding, slot queries, scene anchors, availability checks and math in one class;
- direct calls to `S_Impact`, `S_CartCargo`, `S_Marker`, `S_InteractionTargeting`;
- repeated `get_component()` / `has_component()` across hot and imperative paths.

Target:
- keep authoritative ownership in `C_HeldBy` Relationship;
- move relationship add/remove side effects fully into lifecycle Observer(s);
- separate holder input processing from physical hold solver;
- move pure slot/anchor/query math into non-System helper/service where it is not ECS processing;
- use focused query/sub-system component sets for holder processing;
- replace direct Impact/CartCargo/Marker calls with state/event/relationship transitions;
- keep RigidBody hold integration as an independent non-System physics solver called only from Entity physics callback.

#### S_Impact + S_Damage

Current issues:
- `S_Impact` combines contact capture, throw-window lifetime, contact-pair dedup, impact calculation and damage submission;
- `S_Impact -> S_Damage`;
- `S_Impact -> S_Grab`;
- `S_Damage -> S_Grab`;
- static `submit()` scans `ECS.world.systems` to find the owning System;
- throw timeout currently manually queries all `C_ThrowDamage` entities instead of using a dedicated query/iterate contract.

Target:
- physics callback capture becomes an independent bridge/solver that records typed contact data only;
- dedicated query/sub-system processes `C_ThrowDamage` lifetime using `iterate()`;
- impact resolution consumes typed contact state/events;
- Damage requests use typed event/request/inbox semantics rather than finding `S_Damage` by scanning systems;
- Damage System owns only Health arithmetic/result publication;
- availability/held-state checks consume authoritative Components/Relationships or non-System domain helpers;
- preserve R08 formula/semantics exactly.

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
- `S_Motion` additionally dispatches to Push/Transport.

Target:
- remove Push/Transport dispatch from Motion;
- if a class has no real ECS query/process responsibility, convert/rename it to a clearly named non-System physics solver/helper;
- keep independent solver calls only at `E_RigidBodyCharacter._integrate_forces()`;
- preserve scene-child references such as head axes/camera/collision shapes on the Entity as GECS recommends.

Do not over-split cohesive locomotion math merely to reduce line count. Split only when ownership/data contracts differ.

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

1. Baseline dependency graph of all `content/systems/*.gd`.
2. Refactor Cart Transport/Cargo and remove Transport/Push dispatch from Motion/Input.
3. Refactor Push lifecycle + physics boundaries.
4. Refactor Grab into focused ECS/lifecycle/physics/helper responsibilities.
5. Refactor Impact/Damage request flow and throw lifetime query.
6. Split raw PlayerInput from mode-specific constraints.
7. Separate InteractionTargeting from highlight presentation.
8. Split Marker session/sampling/ink mutation.
9. Split Receiving schedule/spawn and remove DayPhase System service dependency.
10. Reclassify Motion/Look/Crouch static solvers where appropriate.
11. Audit remaining Systems/Observers against GECS checklist.
12. Update scene SystemGroups/deps and remove obsolete System nodes/classes.
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
- do not start before R08-R22 are complete unless the user explicitly changes priority.

---

## Completion criteria

- zero direct project System-to-System service calls, except no exception inside Systems;
- physics orchestration only at Godot Entity callback boundaries;
- hot Systems use specific queries + `iterate()` for required Components;
- large multi-responsibility Systems are split into atomic Systems/sub-systems/helpers;
- presentation is separated from gameplay authority;
- structural mutations during iteration use CommandBuffer/approved GECS lifecycle;
- dead/destroyed vs removal follows pending-cleanup semantics;
- main SystemGroups and `deps()` express execution order;
- behavior remains equivalent to pre-refactor gameplay;
- R23 runs against the polished architecture.
