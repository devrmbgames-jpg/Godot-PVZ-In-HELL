# Project Context

## Project

- PVZ In Hell Simulator; Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- Startup/prototype scene: `content/scenes/main_level.tscn`.
- Machine-specific Godot executable paths belong in local user settings, not the repository.
- Local dependency source is authoritative; `addons/` is read-only unless dependency work is explicitly requested.

## Architecture

- `content/components/`: mutable ECS data/state.
- `content/relationships/`: authoritative Entity-to-Entity ownership/session/binding.
- `content/contracts/`: typed requests/results/events/runtime records.
- `content/definitions/`: immutable authored design data.
- `content/entities/`: Entity scripts plus currently colocated authored scenes.
- `content/systems/`: scheduled GECS `S_*` work only.
- `content/observers/`: reactive/event lifecycle work.
- `content/services/`: shared domain services/solvers/helpers that are not scheduled Systems.
- `content/ui/`: presentation; never gameplay authority.
- `resources/`, `materials/`: art/audio/material data.
- `utils/`: editor/import/static-validation helpers.
- `tests/gut/`, `tests/smoke/`: focused regression/runtime validation.

`main_level.gd` owns the coarse Input -> Interaction -> Physics -> GamePlay schedule. Do not infer body-callback execution from scene-node order: Entity physics callbacks are the authority for body integration.

## Routing

| Need | Read only if needed |
| --- | --- |
| Unknown owner/path | [PROJECT_INDEX.md](PROJECT_INDEX.md) |
| Cross-system gameplay invariants | [content/CONTEXT.md](content/CONTEXT.md) |
| Grab/input/control contract | [docs/physical_grab.md](docs/physical_grab.md) |
| Cart transport | [docs/cart_transport.md](docs/cart_transport.md) |
| Damage/impact | [docs/damage_impact.md](docs/damage_impact.md) |
| Hazards | [docs/hazards.md](docs/hazards.md) |
| Documentation/validation navigation | [docs/README.md](docs/README.md) |
| Agent workflow | [AGENTS.md](AGENTS.md) |
| Human-facing Astra/token guidance | [docs/codex_token_economy.md](docs/codex_token_economy.md) |

Do not read all routing targets as startup context.

## Dependencies

- GECS: submodule `addons/gecs/`, 8.0.0 / `release-v8.0.0`, pinned commit `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`.
- GUT: 9.7.1.
- GDQuest formatter addon: 0.26.0.
- Enabled plugins are authoritative in `project.godot`.

## Validation

Use the smallest check that can falsify the change:
- structure/path validation: `python utils/validate_project_structure.py`;
- whitespace/diff sanity: `git diff --check`;
- GDScript formatter/lint: changed project-owned files only, using the configured local formatter;
- targeted GUT/headless smoke only when the task requires runtime validation.

Do not run broad tests after every edit. Rendered/visual Godot is user-approved only.
