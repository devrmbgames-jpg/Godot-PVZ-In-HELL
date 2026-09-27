# Project Index

Optional routing map. Do not read this file by default. Use it only when the task does not already identify the owning subsystem/path.

## Roots

| Area | Start here |
| --- | --- |
| Startup / scheduling | `content/scenes/main_level.gd`, `content/scenes/main_level.tscn` |
| Cross-system gameplay invariants | `content/CONTEXT.md` |
| Components | `content/components/` |
| Relationships | `content/relationships/` |
| Typed contracts | `content/contracts/` |
| Definitions/data | `content/definitions/` |
| Entities/authored scenes | `content/entities/` |
| Systems | `content/systems/` |
| Observers | `content/observers/` |
| Services/solvers | `content/services/` |
| UI | `content/ui/` |
| Tests | `tests/gut/`, `tests/smoke/` |
| Tooling | `utils/` |
| Docs | `docs/README.md` |
| Agent workflow | `AGENTS.md` |
| Code/resource naming | `docs/code_style.md` |

## Gameplay routes

| Concern | Start with |
| --- | --- |
| Character physics callback | `content/entities/characters/e_rigid_body_character.gd` |
| Raw input | `content/systems/input/s_player_input.gd`, `content/components/input/c_player_input_controller.gd` |
| Player intent | `content/systems/input/s_player_intent.gd`, `content/components/gameplay/c_controller.gd` |
| Motion | `content/services/motion/character_motion_solver.gd`, `content/components/motion/c_motion.gd` |
| Look | `content/services/motion/character_look_solver.gd`, `content/components/motion/c_look.gd` |
| Jump / crouch | `content/systems/motion/s_jump.gd`, `content/systems/motion/s_crouch.gd` |
| Targeting | `content/systems/interaction/s_interaction_targeting.gd`, `content/services/interaction/interaction_targeting_service.gd` |
| Highlight | `content/systems/interaction/s_interaction_highlight.gd` |
| Grab / Carry | `content/services/interaction/grab_service.gd`, `content/observers/interaction/o_grab_lifecycle.gd`, `docs/physical_grab.md` |
| Push | `content/services/interaction/push_service.gd`, `content/observers/interaction/o_push_lifecycle.gd` |
| Cart transport | `content/services/interaction/cart_transport_service.gd`, `content/entities/props/push_cart.tscn`, `docs/cart_transport.md` |
| Context actions / focus | `content/services/interaction/interaction_action_resolver.gd`, `interaction_control_focus.gd` |
| Marker | `content/systems/interaction/s_marker.gd`, `content/entities/tools/marker.tscn`, `docs/package_marking.md` |
| Attributes / Health | `content/components/gameplay/c_health.gd`, `content/definitions/gameplay/attributes/def_attr_health.tres` |
| Damage | `content/observers/gameplay/o_damage.gd`, `content/services/damage/damage_request_service.gd`, `docs/damage_impact.md` |
| Impact / throw attribution | `content/services/damage/impact_capture_solver.gd`, `content/systems/gameplay/s_impact.gd`, `content/services/damage/throw_context.gd` |
| Package data/state | `content/definitions/gameplay/packages/def_package.gd`, `content/components/gameplay/c_package.gd`, `c_package_state.gd` |
| Package physical scene | `content/entities/packages/e_package.gd`, `content/entities/packages/package.tscn` |
| Package destruction/debris | `content/components/gameplay/c_package_destruction.gd`, `c_package_debris.gd`, `content/observers/gameplay/o_package_destruction.gd` |
| Hazards | `content/services/hazards/hazard_spawn_service.gd`, `content/observers/gameplay/o_hazard_spawn.gd`, `docs/hazards.md` |
| Receiving | `content/systems/gameplay/s_receiving.gd`, `content/services/packages/receiving_package_factory.gd`, `content/entities/zones/receiving_zone.tscn` |
| Registration | `content/services/packages/package_registration_service.gd`, `content/contracts/packages/package_registration_record.gd` |
| Scanner | `content/entities/tools/scanner.tscn`, `content/definitions/interaction/def_scan_action.gd` |
| Terminal | `content/entities/stations/terminal.tscn`, `content/ui/terminal_panel.tscn` |
| Day cycle | `content/systems/gameplay/s_day_phase.gd`, `content/contracts/day/day_transition_request.gd` |

## Relevant regression surfaces

Use only the surface related to the edited contract.

| Area | Regression |
| --- | --- |
| Grab/input/Push | `tests/gut/test_s_grab.gd` |
| Jump | `tests/gut/test_s_jump.gd` |
| Main-scene grab wiring | `tests/gut/test_grab_main_scene.gd` |
| Cart | `tests/smoke/cart_transport_smoke.tscn` |
| Receiving/scan | `tests/smoke/receiving_scan_smoke.tscn` |
| Interaction actions | `tests/smoke/interaction_actions_smoke.tscn` |
| Day cycle | `tests/smoke/day_cycle_smoke.tscn` |
| Damage | `tests/smoke/damage_smoke.tscn` |
| Hazards | `tests/smoke/hazards_smoke.tscn` |
| Marker/shelves | `tests/smoke/marker_shelves_smoke.tscn` |

Validation cadence and commands belong in `AGENTS.md` / `docs/smoke_runner.md`, not here.

## Architecture tasks

- Active/planned task files: `agent_tasks/`.
- R22.5 router: `agent_tasks/roadmap_22_5_gecs_architecture_polish.md`; read only its current milestone file.
- GECS-specific workflow: `.agents/skills/gecs-v8/SKILL.md`.

## Dependencies

For version-sensitive APIs inspect the checked-out local dependency source. Do not preload dependency docs for ordinary project work.
