---
name: project-rules
description: >
  Work safely in this Godot project using its architecture, context routing, typing,
  documentation, physics authority, dependency boundaries, and validation rules.
  Use for every gameplay feature, refactor, bug fix, or architecture change.
---

# Project rules

Use this skill as the repository-specific layer. Engine/framework/style details belong to their own skills.

## Workflow

1. Read root `CONTEXT.md`.
2. Read `PROJECT_INDEX.md`.
3. Follow routing to the nearest subsystem `CONTEXT.md`.
4. Read data contracts before the System/Observer that mutates them.
5. Reuse an existing service/event/request contract before creating a new one.
6. Make the smallest coherent change and validate direct callers.

## Read-only dependency boundary

**Everything under `addons/` is read-only by default.**

Normal project work must never:
- modify addon source;
- format addon source;
- rename/move addon files;
- "fix" warnings inside an addon;
- patch an addon to make project code easier;
- upgrade an addon/submodule;
- commit generated addon changes.

Inspect addon code only to understand the pinned API.

Changing `addons/` requires an explicit user request for addon/dependency work.

## Architecture defaults

- Godot physical bodies are authority for physical transform/velocity unless a documented sync contract explicitly says otherwise.
- Immutable design definitions -> `Resource`.
- Mutable runtime actor state -> `Component`.
- Independent identity/lifecycle -> `Entity`.
- Components are data-only.
- Gameplay behavior belongs in Systems/Observers/services.
- Entity subclasses may contain scene glue, child Node references, engine callbacks, and thin forwarding into Systems.
- Node references to an entity's own scene children should not live in reusable Component Resources.
- Prefer typed Request/Event/Result classes over semantic `Dictionary` payloads.
- Avoid global manager objects when an existing service/System/Observer contract owns the concern.
- Presentation must not become gameplay authority.

## GDScript quality

Load `.agents/skills/gdscript-style/SKILL.md` for any `.gd` change.

Baseline:
- static typing;
- no variable/type/native-class shadowing;
- project-owned filenames in `snake_case`;
- authored Inspector Node names in `PascalCase`;
- class names in `PascalCase`, with approved GECS prefixes such as `C_`, `S_`, `O_`, `DEF_`, `E_`, `R_`;
- explicit type/cast when extracting values from untyped collections;
- functions grouped by responsibility;
- no magic constants in gameplay logic;
- hot paths allocation-light.

## Navigation

Do not scan the repository file-by-file.

Use:
`CONTEXT.md -> PROJECT_INDEX.md -> subsystem CONTEXT -> exact symbol -> direct references`.

If `PROJECT_INDEX.md` does not exist, create a compact one using top-level structure and the current task's canonical entry points. Never turn it into a complete manifest.

## Validation

Use project-specific commands from root `CONTEXT.md`.

Never report runtime validation that was not executed.
