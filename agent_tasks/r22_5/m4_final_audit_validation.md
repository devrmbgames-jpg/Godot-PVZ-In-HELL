# R22.5 M4 — Final Audit and Validation

Status: **DONE**
Owner task: [R22.5](../roadmap_22_5_gecs_architecture_polish.md)

## Task state

### Goal
Perform the final architecture audit and bounded validation after M1–M3 are complete.

### Current
Final audit and bounded validation complete after M1–M3. Hazard follow migrated to native GECS Relationship with preserved owner-loss and save contracts; Hunger consumes its iterated state; unavailable Entity targets cannot regain fallback highlight. R1–R7 FIXED and independently reviewed. Next: R23 full-day validation.

### Validation
Final `r225_final_gut.log`: 151/151 PASS, 921 assertions, no project errors/orphans/ObjectDB/resource leaks; external Windows certificate error only. Eleven scripts cover grab/main scene, access, prolonged session/progress, melee/NPC attacks, impact, damage feedback, persistent runtime and Hunger. Strict hazards-20261002-144233354.log and integrated player_feedback-20261002-144441861.log PASS. Static gate: 39 scheduled Systems, 28 reactive Observers, no System helper/locator/frame-machine or legacy follow-origin field violations. Structure/diff PASS. No formatter available; no formatter claim. Class-cache refresh was headless; editor settings/certificate/editor shutdown messages are separate from clean runtime evidence. Initial validation exposed test cleanup errors/leaks and a freed-object assertion; corrected and final rerun clean. Separate read-only reviewer rechecked fixes; no unresolved material findings.

### Owner QA / blockers
No implementation blocker. Rendered/full-day/gamepad/audio acceptance remains in owning feature tasks and R23; this architecture task has no outstanding runtime check.

## Audit disposition and review findings

- Component methods in Attribute/Health/Strength are intrinsic state initialization/access/change notification, not gameplay decisions. Godot child references stay in Entity glue; `C_PhysicsBodyRef` is the explicit raw-body proxy boundary. Target/cursor and documented reverse caches are not ownership co-authority.
- Systems have specific component/relationship queries. Homogeneous state processing consumes iterated fields. Deferred domain transactions intentionally revalidate current components after earlier commands; optional mode/protection components are not made universally required merely to remove lookups.
- Structural commands in scheduled loops use CommandBuffer. Impact setup/entity callbacks use copied queries and the approved World lifecycle. Observers react to discrete signals/events, not per-frame state machines. Dead/depleted state and retirement remain distinct; no speculative pending-delete group is added.
- **R4 FIXED:** `R_HazardFollow` previously stored a direct `origin` field as an ordinary component. Effect → owner now uses native `Relationship.target`; payload contains offset/policy only. Spawn, scheduled follow, cleanup and persistence use one authority. Saved primitive target/offset/policy format and schema remain unchanged; explicit replace is guarded against replaying owner-loss effects.
- **R5 FIXED:** synchronous Hunger scheduling discarded its iterated state and fetched it again. It now passes the typed state to the existing service; optional old service call form is preserved.
- **R6 FIXED (separate review):** disabled source hazards lose World relationship forwarding. A direct source listener preserves Despawn semantics through deferred weak-reference retirement. Transient pending state is synchronously drained before Night capture and excluded from snapshots. Explicit independent restore cancels stale deferred retirement. Tests prove actual registry removal, immediate Night capture/load and restoration cancellation.
- **R7 FIXED (separate review):** disabled rigid Entity targets could regain highlight through the raw-body fallback after targeting cleared them. Availability now gates Entity-backed visual targets while preserving scriptless-body Carry support. Regression covers disable → targeting/highlight tick.
- M2 R1/R2 and M3 R3 remain FIXED. Their regressions and integrated scene run passed in this final surface. Shared crouch HeadRoot is explicitly gameplay geometry; paths/timing are preserved.

---

## Audit checklist

Audit project Systems/Observers for:
- data-only Component violations;
- unrelated responsibilities in one System;
- direct `S_* -> S_*` calls;
- System classes used only as static helpers/services;
- required Components repeatedly fetched instead of iterated;
- broad queries followed by manual filtering;
- SceneTree group lookup where a Component query exists;
- unsafe direct structural mutation during iteration;
- Observers used as per-frame state machines;
- reusable Components storing Node child references instead of Entity glue;
- duplicate relationship authority/caches;
- immediate removal where an explicit pending-delete lifecycle is required;
- gameplay and presentation mixed in one scheduled owner;
- redundant Entity/Node casts in hot loops.

Do not mechanically rewrite valid boundary code to satisfy a metric.

## Recommended implementation order

1. Rebuild a current dependency/disposition list of `content/systems/**/*.gd`.
2. Finish Cart/Push scheduled-vs-solver boundaries.
3. Finish Grab decomposition.
4. Regression-audit Damage/Impact.
5. Keep raw PlayerInput separate from mode constraints.
6. Verify Targeting/Highlight separation.
7. Finish Marker boundaries.
8. Finish Receiving/DayPhase service separation.
9. Reclassify remaining callback-only physics pseudo-Systems.
10. Re-audit remaining Systems/Observers and remove verified unused shells.
11. Update scene SystemGroups/deps and docs.
12. Run static architecture review.
13. Run the single final runtime regression budget.

Commit coherent stages separately.

## Non-goals

- gameplay redesign;
- balance changes;
- visual tuning;
- new content;
- GECS addon modifications;
- speculative performance micro-optimization without evidence.

## Completion criteria

- zero direct project System-to-System service calls;
- every remaining `S_*` has real scheduled work;
- no registered no-op/pseudo-System nodes;
- no System-instance scan used as service locator;
- physics orchestration only at Godot Entity callback boundaries;
- hot Systems use specific queries + iterated required Components;
- multi-responsibility owners are split by authority/data contract;
- presentation does not own gameplay decisions;
- structural mutation follows pinned GECS lifecycle rules;
- dead/destroyed state vs actual removal has explicit ownership;
- SystemGroups + `deps()` express execution order;
- gameplay behavior remains equivalent;
- R23 can validate the polished architecture.

## Final validation

Run only after the complete R22.5 pass:
1. `python utils/validate_project_structure.py`;
2. formatter/lint/static checks on changed project-owned files;
3. `git diff --check`;
4. one relevant GUT invocation covering the refactored interaction/damage surfaces;
5. one headless smoke/runtime pass covering the integrated main behavior.

Rendered/visual acceptance remains user-owned unless explicitly approved.
