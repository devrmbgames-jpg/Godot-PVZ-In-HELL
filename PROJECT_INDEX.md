# Project Index

Optional routing map. Do not read this file by default. Use it only when the task does not already identify the owning subsystem/path; read root/subsystem `CONTEXT.md` only when a specific architecture, dependency, persistence, or validation contract is still unclear.

## Roots

| Area | Entry point | Purpose |
| --- | --- | --- |
| Configuration | [project.godot](project.godot) | Startup, autoloads, input, plugins, physics/rendering |
| Startup | [main_level.tscn](content/scenes/main_level.tscn) | Main playable prototype |
| Gameplay context | [content/CONTEXT.md](content/CONTEXT.md) | Cross-system runtime contracts; read only when relevant |
| Components | `content/components/` | Mutable GECS actor/effect data |
| Relationships | `content/relationships/` | `R_*` ownership/link data by subsystem; GECS payloads still extend Component |
| Contracts | `content/contracts/` | Requests/results/runtime records/DTO-like typed data |
| Definitions | `content/definitions/` | Immutable design Resources and authored `.tres` |
| Entities | `content/entities/` | Entity scripts colocated with world scenes by category |
| Services | `content/services/` | Shared gameplay services/resolvers that are not GECS Systems |
| Systems | `content/systems/` | GECS `S_*` behavior only |
| Observers | `content/observers/` | GECS `O_*` lifecycle/event behavior |
| UI | `content/ui/` | Presentation; never gameplay authority |
| Tests | `tests/gut/`, `tests/smoke/` | Unit/integration/smoke validation |
| Editor/import helpers | `utils/` | Asset/import and deterministic repository validation tooling |
| Documentation | [docs/README.md](docs/README.md) | Documentation navigation |
| Agent efficiency | [docs/codex_token_economy.md](docs/codex_token_economy.md), [.codex/config.toml](.codex/config.toml) | Model/subagent routing and token budget |
| Dependencies | `addons/` | Read-only by default |

## Canonical gameplay routes

| Concern | Start here |
| --- | --- |
| Level / ECS scheduling | [main_level.gd](content/scenes/main_level.gd), [main_level.tscn](content/scenes/main_level.tscn) |
| Character / physics callbacks | [e_rigid_body_character.gd](content/entities/characters/e_rigid_body_character.gd), [scene](content/entities/characters/e_rigid_body_character.tscn) |
| Input intent | [c_controller.gd](content/components/gameplay/c_controller.gd), [s_player_input.gd](content/systems/input/s_player_input.gd) |
| Motion | [c_motion.gd](content/components/motion/c_motion.gd), [s_motion.gd](content/services/motion/character_motion_solver.gd) |
| Look | [c_look.gd](content/components/motion/c_look.gd), [s_look.gd](content/services/motion/character_look_solver.gd) |
| Jump / crouch | [s_jump.gd](content/systems/motion/s_jump.gd), [s_crouch.gd](content/systems/motion/s_crouch.gd) |
| Grab / targeting | [s_grab.gd](content/systems/interaction/s_grab.gd), [s_interaction_targeting.gd](content/systems/interaction/s_interaction_targeting.gd), [o_grab_lifecycle.gd](content/observers/interaction/o_grab_lifecycle.gd), [PhysicsGrabTarget](content/services/interaction/physics_grab_target.gd), [GrabPhysicsSolver](content/services/interaction/grab_physics_solver.gd), [CarryLoadPolicy](content/services/interaction/carry_load_policy.gd); scriptless RigidBody3D Carry + Strength-based mobility for move/look/rotate/throw |
| Physical Push | [s_push.gd](content/systems/interaction/s_push.gd), [o_push_lifecycle.gd](content/observers/interaction/o_push_lifecycle.gd); C_Pushable/R_PushedBy/C_PushControl; independent puzzle mechanic |
| Cart transport | [push_cart.tscn](content/entities/props/push_cart.tscn), [s_cart_transport.gd](content/systems/interaction/s_cart_transport.gd), [c_cart_transport.gd](content/components/interaction/c_cart_transport.gd); CharacterBody3D forward/reverse transport |
| Cart cargo | [s_cart_cargo.gd](content/systems/interaction/s_cart_cargo.gd), [c_cart_cargo.gd](content/components/interaction/c_cart_cargo.gd); [transport contract](docs/cart_transport.md) |
| Interaction routing | [interaction_action_resolver.gd](content/services/interaction/interaction_action_resolver.gd), [interaction_control_focus.gd](content/services/interaction/interaction_control_focus.gd) |
| Interaction contracts | [interaction_action_choice.gd](content/contracts/interaction/interaction_action_choice.gd), [interaction_control_capture.gd](content/contracts/interaction/interaction_control_capture.gd) |
| Interaction definitions/data | [def_interaction_action.gd](content/definitions/interaction/def_interaction_action.gd), [c_interaction_action_set.gd](content/components/interaction/c_interaction_action_set.gd) |
| Physical props | [e_grabbable_body.gd](content/entities/props/e_grabbable_body.gd), [box.tscn](content/entities/props/box.tscn), [bucket.tscn](content/entities/props/bucket.tscn) |
| Attributes / health | [c_attribute.gd](content/components/gameplay/c_attribute.gd), [c_health.gd](content/components/gameplay/c_health.gd), [def_attribute.gd](content/definitions/gameplay/attributes/def_attribute.gd) |
| Damage | [o_damage.gd](content/observers/gameplay/o_damage.gd), [request service](content/services/damage/damage_request_service.gd), [damage_request.gd](content/contracts/damage/damage_request.gd), [damage_result.gd](content/contracts/damage/damage_result.gd) |
| Impact | [capture solver](content/services/damage/impact_capture_solver.gd), [s_impact.gd](content/systems/gameplay/s_impact.gd), [s_throw_lifetime.gd](content/systems/gameplay/s_throw_lifetime.gd); body inboxes, pair episodes and typed damage events |
| Day cycle | [s_day_phase.gd](content/systems/gameplay/s_day_phase.gd), [day_transition_request.gd](content/contracts/day/day_transition_request.gd), [day_phase_station.tscn](content/entities/stations/day_phase_station.tscn) |
| Package condition / opening | [damage/impact contract](docs/damage_impact.md), [manual checks](docs/r08_manual_validation.md), [package_opening.gd](content/services/packages/package_opening.gd), [s_liquid_tilt.gd](content/systems/gameplay/s_liquid_tilt.gd) |
| Package definition/state | [def_package.gd](content/definitions/gameplay/packages/def_package.gd), [c_package.gd](content/components/gameplay/c_package.gd), [c_package_state.gd](content/components/gameplay/c_package_state.gd) |
| Package physical entity | [e_package.gd](content/entities/packages/e_package.gd), [package.tscn](content/entities/packages/package.tscn) |
| Receiving | [s_receiving.gd](content/systems/gameplay/s_receiving.gd), [c_receiving.gd](content/components/gameplay/c_receiving.gd), [receiving_zone.tscn](content/entities/zones/receiving_zone.tscn) |
| Delivery data | [def_delivery.gd](content/definitions/gameplay/deliveries/def_delivery.gd), [def_delivery_morning_supply.tres](content/definitions/gameplay/deliveries/def_delivery_morning_supply.tres), [receiving_batch.gd](content/contracts/receiving/receiving_batch.gd) |
| Scanner | [e_scanner.gd](content/entities/tools/e_scanner.gd), [scanner.tscn](content/entities/tools/scanner.tscn), [def_scan_action.gd](content/definitions/interaction/def_scan_action.gd) |
| Marker / package ink | [s_marker.gd](content/systems/interaction/s_marker.gd), [marker.tscn](content/entities/tools/marker.tscn), [c_package_marks.gd](content/components/gameplay/c_package_marks.gd); contract: [package_marking.md](docs/package_marking.md) |
| Numbered storage | [numbered_shelves.tscn](content/entities/props/numbered_shelves.tscn); physical compartments 01–06, no Terminal shelf tracking |
| Registration | [package_registration_service.gd](content/services/packages/package_registration_service.gd), [package_registration_record.gd](content/contracts/packages/package_registration_record.gd), [package_scan_result.gd](content/contracts/packages/package_scan_result.gd) |
| Terminal | [e_terminal.gd](content/entities/stations/e_terminal.gd), [terminal.tscn](content/entities/stations/terminal.tscn), [terminal_panel.tscn](content/ui/terminal_panel.tscn) |

## Validation routes

Start with the narrowest relevant check.

- Deterministic repository structure/path check: `python utils/validate_project_structure.py`.
- GDScript formatting/lint: run the configured formatter/static check on changed project-owned `.gd` files only; `.pre-commit-config.yaml` provides the repository hook.
- Grab tests: [test_s_grab.gd](tests/gut/test_s_grab.gd).
- Cart transport smoke: `tests/smoke/cart_transport_smoke.tscn` (`--quit-after 2400`, require PASS without script/assertion errors).
- Jump tests: [test_s_jump.gd](tests/gut/test_s_jump.gd).
- Receiving/scan/number-reuse smoke: `tests/smoke/receiving_scan_smoke.tscn` (`--quit-after 360`, require PASS).
- Hands/Terminal capture smoke: `tests/smoke/interaction_actions_smoke.tscn` (`--quit-after 180`, require PASS).
- Day-cycle smoke: `tests/smoke/day_cycle_smoke.tscn`.
- Damage smoke: `tests/smoke/damage_smoke.tscn`.
- Marker/shelves smoke: `tests/smoke/marker_shelves_smoke.tscn` (`--quit-after 360`, require PASS).
- Always run `git diff --check` before a milestone commit.

## Dependency authority

| Dependency | Version/ref | Source |
| --- | --- | --- |
| Godot | 4.7 project feature | `project.godot` |
| GECS | 8.0.0, `release-v8.0.0`, commit `14d4282e5c1cb2713c187706ba2f5ff4e315d36e` | `.gitmodules`, local `addons/gecs/` |
| GUT | 9.7.1 | `addons/gut/plugin.cfg` |
| GDQuest formatter | 0.26.0 | `addons/GDQuest_GDScript_formatter/plugin.cfg` |

Update this file immediately when canonical paths move. Do not turn it into an asset manifest or duplicate subsystem design docs.

## Hazard mechanics (R09)

- Generic factory: `HazardSpawnService` / `O_HazardSpawn`, typed contracts in `content/contracts/hazards/`.
- Reusable producer: `C_HazardEmitter` / `HazardEmitter`; package-only adapters: `O_PackageHazardSetup`, `O_PackageHazard`.
- Definitions/prefabs: `content/definitions/gameplay/hazards/`, `content/entities/hazards/`.
- Hazard contracts/attachment/reset: [docs/hazards.md](docs/hazards.md).
- User-operated smoke: `utils/run_smoke.ps1 -Name hazards`; standalone fixture `tests/smoke/hazards_smoke.tscn`; [runner usage](docs/smoke_runner.md).

- Relationship types: `content/relationships/interaction/r_held_by.gd`, `r_pushed_by.gd`; `content/relationships/gameplay/r_hazard_follow.gd`. Follow uses direct owner-link state; HeldBy/PushedBy are GECS edge payloads.
