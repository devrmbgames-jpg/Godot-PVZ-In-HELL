# Project Index

This is a compact navigation map for humans and AI agents.

It is **not** a complete file manifest. Keep only canonical entry points, subsystem roots, important contracts, and validation commands.

## Project roots

| Area | Path | Purpose |
| --- | --- | --- |
| Engine config | `project.godot` | Engine version, autoloads, plugins, input, rendering/physics configuration |
| Gameplay | `<fill>` | Main project-owned runtime/gameplay code |
| Tests | `<fill>` | GUT tests / integration fixtures |
| Docs/context | `<fill>` | Architecture/context documents |
| Addons | `addons/` | Third-party dependencies; read-only unless explicitly requested |

## Canonical contracts

Add only files that agents repeatedly need:

| Concern | Canonical file(s) | Notes |
| --- | --- | --- |
| Entity base / actor root | `<fill>` | |
| Controller intent | `<fill>` | |
| Motion / physics | `<fill>` | |
| Look / camera | `<fill>` | |
| Combat | `<fill>` | |
| Animation / presentation | `<fill>` | |
| Save/load | `<fill>` | |

## Subsystem routing

| Task | Start here |
| --- | --- |
| Input/controllers | `<fill>/CONTEXT.md` |
| Motion/physics | `<fill>/CONTEXT.md` |
| Combat | `<fill>/CONTEXT.md` |
| Animation/presentation | `<fill>/CONTEXT.md` |
| Tests | `<fill>/CONTEXT.md` |

## Dependency pins

| Dependency | Version/ref | Path | Rule |
| --- | --- | --- | --- |
| Godot | 4.7 | `project.godot` | Project version wins |
| GECS | `<fill>` | `addons/<gecs-path>` | Read-only; local pinned source is API authority |
| GUT | `<fill>` | `addons/gut` | Read-only dependency |

## Validation commands

Keep only commands actually supported by this repository.

```bash
# formatter
<fill>

# static checks
<fill>

# targeted tests
<fill>
```

## Maintenance rule

Update this index only when:
- a canonical entry point changes;
- a new subsystem becomes important enough to route directly;
- a dependency/version pin changes;
- a validation command becomes canonical.

Do not add every source file. The purpose is to reduce search, not mirror the repository tree.
