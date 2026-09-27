# R22.5 M4 — Final Audit and Validation

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
