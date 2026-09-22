---
name: project-rules
description: >
  Repository-specific architecture, dependency, physics-authority and validation
  rules for code changes in this Godot project.
---

# Project rules

Use this skill for project code/architecture changes. Navigation/token rules come from root `AGENTS.md`; do not reread project-wide docs unless the task needs them.

## Dependency boundary

Everything under `addons/` is read-only by default. Inspect pinned APIs when needed, but never patch, format, rename, upgrade, or commit addon changes unless explicitly requested.

## Architecture defaults

- Godot physical bodies own physical transform/velocity unless a documented sync contract says otherwise.
- Immutable design data -> `Resource`.
- Mutable runtime actor state -> `Component`.
- Independent identity/lifecycle -> `Entity`.
- Components are data-only.
- Behavior belongs in Systems/Observers/services.
- Entity scripts may contain scene glue, own-child Node references, engine callbacks, and thin forwarding.
- Avoid reusable Component Resources holding direct scene-child Node references.
- Prefer typed Request/Event/Result classes over semantic Dictionaries.
- Reuse an existing service/System/Observer contract before creating a parallel manager.
- Presentation is never gameplay authority.
- Scene-authored serializable Components should prefer `component_resources` so they are visible in Inspector; runtime-only construction must have a real serialization/lifecycle reason.

## GDScript

Load `.agents/skills/gdscript-style/SKILL.md` for `.gd` edits.

Required baseline: static typing, no shadowing, no magic gameplay constants, explicit casts from Variant/untyped collections, allocation-aware hot paths, project naming conventions.

## Change discipline

Make the smallest coherent change. After finding the owner/contract, do not opportunistically refactor unrelated code.

For already-designed repetitive edits, prefer the `mechanical_worker` subagent. Architectural decisions stay with the main agent.

## Validation

Use the narrowest relevant project checks. Never report a runtime/formatter/test result that was not actually executed.
