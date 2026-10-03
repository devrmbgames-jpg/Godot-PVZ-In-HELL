# Roadmap — design map

This directory stores **design specifications**. It does not track live implementation status.

- `ТЗ xx` = product/design specification;
- `Rxx` / `Rxx.x` = implementation identifier;
- numbers are not required to match.

Live execution belongs to the current Codex Plan/Goal. If durable cross-session implementation state is needed, the exact file under `agent_tasks/` owns it. Completed implementation history belongs to Git. Do not add PLANNED/IN_PROGRESS/DONE columns here.

## Design → implementation mapping

| Implementation | Main design sources |
| --- | --- |
| R01 | ТЗ 01 / 04 foundations |
| R02 | ТЗ 02 |
| R03 | ТЗ 03 |
| R04 | ТЗ 10 foundation: common damage/health contract |
| R05 | ТЗ 04 |
| R06 | ТЗ 05: scanner / registration / terminal |
| R06.1 | [ТЗ 06.1](06_1_interaction_hands_carry_push.md) |
| R07 | ТЗ 05: marker / shelves |
| R08 | [ТЗ 06](06_package_damage_and_hazards.md), [damage contract](../damage_impact.md) |
| R09 | [ТЗ 06](06_package_damage_and_hazards.md) |
| R10 | [ТЗ 07](07_customer_flow_and_delivery.md), ТЗ 14/15 |
| R11 | [ТЗ 07](07_customer_flow_and_delivery.md) |
| R11.1 | [ТЗ 08.1](08_1_arrangement_extended_interactions.md) |
| R12 | [ТЗ 09](09_dialogue_system.md) |
| R13 | [ТЗ 13](13_environment_interactables.md) + R11.1 contracts |
| R14–R16 | [ТЗ 08](08_customer_challenge_framework.md) |
| R17 | [ТЗ 10](10_combat_damage_health.md) |
| R18 | [ТЗ 11](11_hunger_system.md) + ТЗ 09 |
| R19 | [ТЗ 12](12_inventory_and_consumables.md) + ТЗ 08.1 |
| R20 | [ТЗ 14](14_evening_meta_scaffold.md) |
| R21 | [ТЗ 15](15_night_save_next_day.md) |
| R22 | [ТЗ 16](16_ui_and_feedback.md) |
| R22.5 | GECS architecture polish using upstream/project contracts |
| R23 | [ТЗ 17](17_vertical_slice_scenario.md) + ТЗ 00 |

## Cross-cutting rules

Design specs can feed several implementation tasks. They remain durable requirements even after implementation files are removed.

When an exact `agent_tasks/*.md` file exists, it may point back to these requirements, but it must not copy them into a second roadmap status table. If an old prose reference conflicts with current code/contracts, inspect the current owner rather than inferring status from this roadmap.
