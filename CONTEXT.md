# Project Context

This file stores project facts, not agent behavior rules.

## Project

- Engine: Godot 4.7
- Language: GDScript
- ECS: GECS
- Tests: GUT
- Editor: VS Code

## Architecture

Describe the stable architecture here:
- major folders;
- scene ownership;
- gameplay authority;
- physics authority;
- system groups/order;
- data/resource conventions;
- important dependencies.

## Routing table

| Task | Read first |
| --- | --- |
| Input/controllers | `path/to/input/CONTEXT.md` |
| Motion/physics | `path/to/motion/CONTEXT.md` |
| Combat | `path/to/combat/CONTEXT.md` |
| Animation/presentation | `path/to/presentation/CONTEXT.md` |
| Tests | `tests/CONTEXT.md` |

Add only routes that materially reduce repository scanning.

## External dependencies

### GECS
Record:
- install method: submodule / addon / copied source;
- pinned branch/tag/commit;
- local path.

The checked-out version is the API authority.

### GUT
For Godot 4.7 use a GUT release that explicitly supports Godot 4.7 (for example GUT 9.7.1).

## Validation

Record project-specific commands here, for example:

```bash
gdscript-formatter --check path/to/changed.gd
godot --headless --path . -s addons/gut/gut_cmdln.gd
```

Only include commands actually supported by the repository.
