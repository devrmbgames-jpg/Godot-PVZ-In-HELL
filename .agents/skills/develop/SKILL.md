---
name: develop
description: Executes implementation work in Godot-PVZ-In-HELL with a right-sized workflow. Use for code changes, bug fixes, refactors, migrations, tracked roadmap tasks, or substantial implementation review. Investigate first, classify work as Fix/Task/Feature, load only required context, implement in small milestones, independently review the result, and perform the narrowest allowed verification.
compatibility: Godot 4.7 / GDScript / GECS v8 / Jolt Physics.
metadata:
  project: Godot-PVZ-In-HELL
  version: "1.0"
---

# Develop

Use a right-sized process. Investigation determines ceremony; ceremony does not determine investigation.

## 1. Investigate

Start from the exact task, error, symbol, path, or scene. Establish only:
- authoritative owner;
- direct data/scene/API contract;
- direct callers/callees affected;
- smallest relevant regression surface.

Load `PROJECT_INDEX.md`, subsystem `CONTEXT.md`, roadmap/task files, or specialized skills only when one of those facts is missing or the task explicitly needs them. Do not inventory the repository.

## 2. Classify after inspection

Choose the smallest level that safely fits:

- **Fix** — local, low-risk change with a clear owner/contract. No new task document.
- **Task** — several files/components, meaningful regression surface, or multiple implementation stages. Reuse the project's existing task/roadmap artifact when one exists; create bookkeeping only when the work is genuinely interruptible/long-running or the user requests it.
- **Feature** — new subsystem, architecture/migration work, cross-system ownership/physics/GECS contract change, or work spanning multiple sessions. Durable tracked state is required, using the repository's existing task/roadmap convention.

Escalate or de-escalate if inspection changes the real scope.

## 3. Plan only enough

For Task/Feature work, define small coherent milestones. Record decisions that constrain later stages, not an exploration transcript.

A tracked task should keep an authoritative compact state with:
- status and goal;
- constraints/acceptance;
- milestones;
- durable decisions/invariants;
- exact current checkpoint and one next step;
- validation actually performed;
- remaining owner QA/blockers.

Do not create a parallel plan when an existing roadmap/task file already owns the work.

## 4. Implement

Make the smallest coherent change that satisfies the current milestone.
- Follow root `AGENTS.md`.
- Load `gecs-v8` only for GECS-specific architecture/API work.
- Preserve authoritative ownership: Components/Relationships/contracts/services must not become accidental co-authorities.
- Preserve physics authority and input/control priority.
- Keep typing explicit when inference is not mechanically obvious.
- Do not mix unrelated cleanup into the task.
- Commit completed logical milestones when the work spans multiple stages.

## 5. Review independently

After implementation, reread the resulting diff as if written by another developer. Do not trust the plan.

Prioritize:
- behavior regressions;
- lifecycle/ownership bugs;
- physics authority or synchronization errors;
- GECS boundary violations and System-to-System coupling;
- input/control priority conflicts;
- Variant/type inference mistakes;
- serialized scene/resource/relationship/contract breakage;
- introduced public mutable behavior fields or resource-naming regressions;
- missing or misleading validation.

For material findings, assign stable IDs (`R1`, `R2`, ...). New findings start as `OPEN` and must end as `FIXED`, `ACCEPTED`, or `FALSE_POSITIVE`; do not silently drop findings. Persist only material findings for tracked Task/Feature work. Use the read-only `reviewer` only when separate context materially improves a substantial diff review.

## 6. Verify

Use the narrowest deterministic check that can falsify the change, following root `AGENTS.md` and the exact active roadmap/task rules.

Load `gut-testing` only when authoring/modifying/running GUT. Do not run runtime validation merely because implementation is complete if the active task does not require it.

Report exactly what ran. Separate automated/static evidence from owner gameplay/visual QA.

## 7. Finish or checkpoint

If complete: summarize changed behavior, meaningful paths, validation, and remaining owner QA.

If interrupted: update the existing authoritative task/roadmap state plus `CURRENT_WORK.md` only as a compact resume pointer. Do not create duplicate state files.
