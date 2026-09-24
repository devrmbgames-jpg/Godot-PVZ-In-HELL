# Project Context

## Project

- PVZ In Hell Simulator; Godot 4.7, GDScript, Forward Plus, Jolt Physics.
- Configured startup / project-owned ECS prototype: `content/scenes/main_level.tscn`.
- VS Code settings point to a local Godot 4.7.1 executable and enable DoHe.godot-format.

## Architecture

- `content/`: entities, components, systems, definitions, and prototype level.
- `resources/`: imported art, animation libraries, KayKit assets and audio; `materials/`: materials.
- `utils/`: editor/import helpers for glTF splitting, material generation, multimeshes and asset placement.
- `tests/gut/`: jump regression tests, grab lifecycle/input/physics tests and main-scene integration.
- `docs/`: documentation entry point; `godoban_boards/` and `kanban_tasks_data.kanban`: planning data.
- `main_level.gd` sets ECS.world and processes Input -> Interaction -> Physics -> GamePlay on each physics tick. Interaction runs targeting before grab.
- `E_RigidBodyCharacter._integrate_forces` forwards to S_Motion, S_Look and S_Crouch, in that order. Physics state owns physical transform/velocity.
- Physical props use E_Grabbable; its integration callback delegates translation force and held angular-velocity control to S_Grab. A R_HeldBy relationship is the authority for ownership; O_GrabLifecycle maintains collision exceptions and carry modifiers.
- Resource definitions live in `content/definitions/`; runtime components in `content/components/`.
- Autoloads: Audio (quick_audio), InputHelper, DialogueManager, Console, ECS (GECS).

## Routing

| Task | Read first |
| --- | --- |
| Canonical files and dependencies | [PROJECT_INDEX.md](PROJECT_INDEX.md) |
| Level, input, movement, camera, attributes | [content/CONTEXT.md](content/CONTEXT.md) |
| Physical grabbing / controls / tuning | [docs/physical_grab.md](docs/physical_grab.md) |
| Documentation and validation | [docs/README.md](docs/README.md) |
| Agent workflow | [AGENTS.md](AGENTS.md) |
| Codex/Astra token economy | [docs/codex_token_economy.md](docs/codex_token_economy.md) |

## Dependencies

- GECS: Git submodule at `addons/gecs/`; configured branch `release-v8.0.0`; plugin declares 8.0.0; checked-out commit `14d4282e5c1cb2713c187706ba2f5ff4e315d36e`.
- GUT: copied addon at `addons/gut/`, plugin declares 9.7.1.
- GDQuest formatter: `addons/GDQuest_GDScript_formatter/`, plugin declares 0.26.0.
- COGITO has been removed from the working tree. Enabled plugins are listed in `project.godot`; stale COGITO translation paths were removed.
- Local addon source is API authority. Everything under `addons/` is read-only unless dependency work is explicitly requested.

## Validation

- Documentation/static diff check: `git diff --check`.
- No project-specific static-check script or VS Code tasks file is currently present.
- GDScript formatting/linting is configured through VS Code and the GDQuest addon. The formatter is not on PATH; use the executable configured in Godot editor settings with `--check`, `--verify-structure`, or `lint` on changed files.
- Targeted jump tests: `<godot> --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/gut/test_s_jump.gd -gexit`, where `<godot>` is the local Godot 4.7 executable.
- All project tests: `<godot> --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/gut -gexit`.
- Grab tests include real rigid-body force/torque, wall blocking, lifecycle cleanup and the main scene. Input tests substitute OS cursor capture, which is unavailable in headless mode.
