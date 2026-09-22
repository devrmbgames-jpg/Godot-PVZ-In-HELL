# Project Index

Compact canonical map. Read [CONTEXT.md](CONTEXT.md), then the relevant subsystem context; inspect only the named code and its direct contracts.

## Roots

| Area | Entry point | Purpose |
| --- | --- | --- |
| Configuration | [project.godot](project.godot) | Startup, autoloads, input, plugins, physics/rendering |
| Startup | [main_level.tscn](content/scenes/main_level.tscn) | Player, morning supply, scanner, terminal and day stations |
| Gameplay prototype | [content/CONTEXT.md](content/CONTEXT.md) | Project-owned ECS, character, level and attributes |
| Resources | `resources/`, `materials/` | Imported art/audio, generated scenes and materials |
| Editor/import helpers | `utils/` | Asset generation and import tooling |
| Tests | [test_s_jump.gd](tests/gut/test_s_jump.gd), [test_s_grab.gd](tests/gut/test_s_grab.gd), [test_grab_main_scene.gd](tests/gut/test_grab_main_scene.gd) | Unit and real physics integration tests |
| Documentation | [docs/README.md](docs/README.md) | Documentation navigation |
| Agent efficiency | [docs/codex_token_economy.md](docs/codex_token_economy.md), [.codex/config.toml](.codex/config.toml) | Model/subagent routing and token budget |
| Planning | `godoban_boards/`, `kanban_tasks_data.kanban` | Board data |
| Dependencies | `addons/` | Read-only by default |

## Canonical contracts

All gameplay rows route through [content/CONTEXT.md](content/CONTEXT.md).

| Concern | Canonical files |
| --- | --- |
| Level and ECS scheduling | [main_level.tscn](content/scenes/main_level.tscn), [main_level.gd](content/scenes/main_level.gd) |
| Actor and physics callbacks | [e_rigid_body_character.gd](content/entities/e_rigid_body_character.gd), [scene](content/entities/e_rigid_body_character.tscn) |
| Input intent | [c_controller.gd](content/components/gameplay/c_controller.gd), [s_player_input.gd](content/systems/input/s_player_input.gd), [player marker](content/components/input/c_player_input_controller.gd) |
| Motion | [c_motion.gd](content/components/motion/c_motion.gd), [s_motion.gd](content/systems/motion/s_motion.gd) |
| Look / camera | [c_look.gd](content/components/motion/c_look.gd), [s_look.gd](content/systems/motion/s_look.gd) |
| Jump / crouch | [s_jump.gd](content/systems/motion/s_jump.gd), [s_crouch.gd](content/systems/motion/s_crouch.gd), `content/components/motion/` |
| Grab / interaction | [s_grab.gd](content/systems/interaction/s_grab.gd), [s_interaction_targeting.gd](content/systems/interaction/s_interaction_targeting.gd), [o_grab_lifecycle.gd](content/observers/interaction/o_grab_lifecycle.gd) |
| Grab data / tuning | `content/components/interaction/`, [c_carry_load.gd](content/components/motion/c_carry_load.gd), [design and controls](docs/physical_grab.md) |
| Physical props | [e_grabbable.gd](content/entities/props/e_grabbable.gd), [box.tscn](content/entities/props/box.tscn) |
| Attributes / health | [c_attribute.gd](content/components/gameplay/c_attribute.gd), [c_attribute_changed.gd](content/components/gameplay/c_attribute_changed.gd), [c_health.gd](content/components/gameplay/c_health.gd) |
| Resource definitions | [definition.gd](content/definitions/definition.gd), [def_attribute.gd](content/definitions/gameplay/def_attribute.gd), [health.tres](content/definitions/gameplay/attributes/health.tres) |
| glTF import | [gltf_import_split_script.gd](utils/gltf_import_split_script.gd) |
| Asset tooling | [material_collection_generator.gd](utils/material_collection_generator.gd), [multi_mesh_generator.gd](utils/multi_mesh_generator.gd), [assets_grid_sort.gd](utils/assets_grid_sort.gd) |

The R04 damage pipeline exists; combat sources/AI, save/load and animation systems are still planned. Imported animation assets do not establish gameplay contracts.

## Dependency authority

| Dependency | Version/ref | Source |
| --- | --- | --- |
| Godot | 4.7 project feature; editor path names 4.7.1 | `project.godot`, `.vscode/settings.json` |
| GECS | 8.0.0 plugin; `release-v8.0.0`; commit `14d4282e5c1cb2713c187706ba2f5ff4e315d36e` | `.gitmodules`, `addons/gecs/plugin.cfg`, local submodule |
| GUT | 9.7.1 plugin | `addons/gut/plugin.cfg` |
| GDQuest formatter | 0.26.0 plugin | `addons/GDQuest_GDScript_formatter/plugin.cfg` |

GECS tag-based `git describe` output may refer to an older reachable tag; use the checked-out commit and local source as authority.

## Validation and maintenance

See [CONTEXT.md](CONTEXT.md#validation) for supported checks and current gaps. Run `git diff --check` for documentation edits.

Update this map when entry points, subsystem routes, dependency pins or validation commands change. Do not add asset manifests or generated/imported files.

## Package foundation

- Definition: `content/definitions/gameplay/def_package.gd`.
- Runtime identity/state: `content/components/gameplay/c_package.gd`, `c_package_state.gd`.
- Physical scene: `content/entities/props/package.tscn`, `e_package.gd`; contracts in `content/CONTEXT.md`.

## Contextual interaction

- Action definition: `content/definitions/interaction/interaction_action.gd`; data: `content/components/interaction/c_interaction_actions.gd`.
- Resolver/handlers: `content/systems/interaction/interaction_actions.gd`, `grab_action.gd`, `interaction_choice.gd`.
- Read-only HUD: `content/ui/interaction_hud.tscn`.

## Day cycle

- Singleton state: `content/components/gameplay/c_day_cycle.gd` on main-level DaySession.
- Transitions: `content/systems/gameplay/s_day_phase.gd`, `day_transition_request.gd`, `day_phase_action.gd`.
- World controls: `content/entities/day_station.tscn`, `e_day_station.gd` (ShiftConsole and SleepPoint).
- Standalone checks: `tests/smoke/day_cycle_smoke.tscn`, `tests/smoke/interaction_actions_smoke.tscn`; run with Godot `--headless --path . res://tests/smoke/<scene>.tscn --quit-after 120` and require the PASS marker (assertions alone do not guarantee nonzero exit).

## Damage and controls

- Gameplay control contract: [docs/controls.md](docs/controls.md).
- Damage pipeline: `content/systems/gameplay/s_damage.gd`, `damage_request.gd`, `damage_result.gd`.
- Health: `content/components/gameplay/c_health.gd`; package adapter: `c_package_integrity.gd`.
- Physics contact check: `tests/smoke/character_contact_smoke.tscn`; damage check: `tests/smoke/damage_smoke.tscn`.

## Receiving and registration

- Supply data: `content/definitions/gameplay/morning_supply.tres`, `def_delivery.gd`, `def_package.gd`.
- Receiving: `content/entities/receiving_zone.tscn`, `content/systems/gameplay/s_receiving.gd`, `content/components/gameplay/c_receiving.gd`.
- Scanner: `content/entities/props/scanner.tscn`, `content/systems/interaction/scan_action.gd`.
- Registry authority: `content/systems/gameplay/package_registration_service.gd`; `C_PackageLedger` on `E_DaySession`.
- Terminal: `content/entities/terminal.tscn`, `content/ui/terminal_panel.tscn`; printer definition only: `content/definitions/gameplay/label_printer.tres`.
- End-to-end check: `tests/smoke/receiving_scan_smoke.tscn`; add `-- --preview` with rendering to capture `tests/artifacts/terminal_preview.png`.
