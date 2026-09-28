# Roadmap: canonical IDs and execution map

This directory stores **design specifications**. Files named `XX_*.md` use the label `ТЗ XX` and describe gameplay/design contracts.

Implementation work uses a separate canonical ID:

- `Rxx` / `Rxx.x` = canonical implementation task/order;
- `ТЗ xx` = source design specification;
- the numbers are **not required to match**.

Agents must never infer implementation order from a `ТЗ` number. Use this file for ID mapping, `agent_tasks/CONTEXT.md` for the live queue/status, the exact task/router for Current/Next, and `task_history.md` for completed history. `CURRENT_WORK.md` is only the current execution pointer. If a human says `RM08`, normalize it to canonical repository ID `R08`; do not create a parallel RM-prefixed task.

Design specs in this directory do not own implementation status. Completed implementation tasks may be removed from `agent_tasks/`; their durable product contracts remain in roadmap/subsystem docs and completion is recorded in `task_history.md`.

## Canonical implementation order

| Implementation | Status | Main design sources |
| --- | --- | --- |
| R01 | completed | ТЗ 01 / 04 foundations |
| R02 | completed | ТЗ 02 |
| R03 | completed | ТЗ 03 |
| R04 | completed | ТЗ 10 foundation: common damage/health contract |
| R05 | completed | ТЗ 04 |
| R06 | completed | ТЗ 05: scanner / registration / terminal |
| R06.1 | completed | [R06.1](06_1_interaction_hands_carry_push.md) |
| R07 | completed | ТЗ 05: marker / shelves |
| R08 | completed | [ТЗ 06](06_package_damage_and_hazards.md): generic Health/Impact foundation + package damage/opening; [durable contract](../damage_impact.md) |
| R09 | completed | [ТЗ 06](06_package_damage_and_hazards.md): package hazards |
| R10 | completed | [ТЗ 07](07_customer_flow_and_delivery.md), ТЗ 14/15: wallet/results |
| R11 | completed | [ТЗ 07](07_customer_flow_and_delivery.md): customers/delivery/disputes |
| [R11.1](../../agent_tasks/roadmap_11_1_extended_interactions_and_arrangement.md) | IN_PROGRESS | [ТЗ 08.1](08_1_arrangement_extended_interactions.md): prolonged interactions, access, physical slots, placement/anchoring |
| [R12](../../agent_tasks/roadmap_12_dialogue_integration.md) | PLANNED | [ТЗ 09](09_dialogue_system.md): dialogue integration |
| [R13](../../agent_tasks/roadmap_13_environment_interactables.md) | PLANNED | [ТЗ 13](13_environment_interactables.md) using R11.1 contracts |
| [R14](../../agent_tasks/roadmap_14_challenge_framework_and_lights.md) | PLANNED | [ТЗ 08](08_customer_challenge_framework.md): challenge lifecycle/light |
| [R15](../../agent_tasks/roadmap_15_gaze_challenges.md) | PLANNED | [ТЗ 08](08_customer_challenge_framework.md): gaze challenges |
| [R16](../../agent_tasks/roadmap_16_floor_hazard_challenge.md) | PLANNED | [ТЗ 08](08_customer_challenge_framework.md): floor hazard challenge |
| [R17](../../agent_tasks/roadmap_17_combat_and_impact_damage.md) | PLANNED | [ТЗ 10](10_combat_damage_health.md): combat/aggression; reuses R08 impact contract |
| [R18](../../agent_tasks/roadmap_18_hunger_and_perception.md) | PLANNED | [ТЗ 11](11_hunger_system.md), ТЗ 09: hunger/perception |
| [R19](../../agent_tasks/roadmap_19_inventory_and_consumables.md) | PLANNED | [ТЗ 12](12_inventory_and_consumables.md), ТЗ 06/11: inventory/consumables |
| [R20](../../agent_tasks/roadmap_20_evening_trader_orders_and_quest.md) | PLANNED | [ТЗ 14](14_evening_meta_scaffold.md): evening/trader/orders/quest |
| [R21](../../agent_tasks/roadmap_21_night_persistence_next_day.md) | PLANNED | [ТЗ 15](15_night_save_next_day.md): persistence/next day |
| [R22](../../agent_tasks/roadmap_22_hud_and_world_feedback.md) | PLANNED | [ТЗ 16](16_ui_and_feedback.md): HUD/feedback |
| [R22.5](../../agent_tasks/roadmap_22_5_gecs_architecture_polish.md) | DEFERRED | GECS upstream best practices + project architecture polish |
| [R23](../../agent_tasks/roadmap_23_vertical_slice_validation.md) | PLANNED | [ТЗ 17](17_vertical_slice_scenario.md): full vertical-slice validation |

## Cross-cutting design specs

Some ТЗ intentionally feed multiple implementation tasks:

- ТЗ 00 — overall prototype scope; final authority for R23 coverage.
- ТЗ 01 — GECS gameplay model used across all runtime tasks.
- ТЗ 02 — base interaction/physics contract reused by R06.1, R11.1, R13 and R17.
- ТЗ 04 — receiving/package foundation reused by R05, R08 and R21.
- ТЗ 05 — scanner/terminal/marker/shelves split across R06, R07, R20 and R22.
- ТЗ 06 — package damage/hazards split across R08, R09, R19 and R22.
- ТЗ 07 — customer outcomes/economy/disputes split across R10, R11, R12, R17, R20 and R23.
- ТЗ 08 — challenge framework split across R14, R15 and R16.
- ТЗ 08.1 — generic extended-interaction foundation is R11.1; R13/R19 consume it.
- ТЗ 09 — dialogue integration is R12; perception hooks are consumed by R18.
- ТЗ 10 — common combat contract is R17 on top of completed R04 damage foundation.
- ТЗ 11 — Hunger is R18; Food inventory/use is R19.
- ТЗ 12 — small Inventory is R19; Trader consumption is R20.
- ТЗ 13 — environment interactables are R13 and must reuse R11.1.
- ТЗ 14 — economy/evening contracts are split across R10, R20 and R21.
- ТЗ 15 — persistence/next-day transaction is R21.
- ТЗ 16 — presentation requirements are implemented incrementally and finalized by R22.
- GECS architecture polish — R22.5 runs after feature work and before R23; it must preserve gameplay while removing System coupling and query anti-patterns.
- ТЗ 17 — scenario requirements feed multiple tasks and are fully validated by R23.
- ТЗ 18 — implementation-order guidance; this README is the canonical ID mapping when later insertions exist.

## Agent rule

When an implementation task exists, its `Task state` is authoritative for status/current/next. Treat linked `ТЗ` files as source requirements, not alternative task IDs or parallel progress trackers. Use `agent_tasks/CONTEXT.md` to find the current task/router.

If this mapping and an old prose reference disagree, this mapping plus the active task/checkpoint wins until the stale reference is corrected.
