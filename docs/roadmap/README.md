# Roadmap: canonical IDs and execution map

This directory stores **design specifications**. Files named `XX_*.md` use the label `ТЗ XX` and describe gameplay/design contracts.

Implementation work uses a separate canonical ID:

- `Rxx` / `RMxx.x` = implementation task/order;
- `ТЗ xx` = source design specification;
- the numbers are **not required to match**.

Agents must never infer implementation order from a `ТЗ` number. Use this file, `agent_tasks/`, `task_history.md`, and `CURRENT_WORK.md`.

Completed implementation tasks are removed from `agent_tasks/` by project policy. Their durable contracts remain in roadmap/context docs and their completion is recorded in `task_history.md`.

## Canonical implementation order

| Implementation | Status | Main design sources |
| --- | --- | --- |
| R01 | completed | ТЗ 01 / 04 foundations |
| R02 | completed | ТЗ 02 |
| R03 | completed | ТЗ 03 |
| R04 | completed | ТЗ 10 foundation: common damage/health contract |
| R05 | completed | ТЗ 04 |
| R06 | completed | ТЗ 05: scanner / registration / terminal |
| RM06.1 | completed | [RM06.1](06_1_interaction_hands_carry_push.md) |
| R07 | completed | ТЗ 05: marker / shelves |
| R08 | planned | [ТЗ 06](06_package_damage_and_hazards.md): package damage/opening |
| R09 | planned | [ТЗ 06](06_package_damage_and_hazards.md): package hazards |
| R10 | planned | [ТЗ 07](07_customer_flow_and_delivery.md), ТЗ 14/15: wallet/results |
| R11 | planned | [ТЗ 07](07_customer_flow_and_delivery.md): customers/delivery/disputes |
| R11.1 | planned | [ТЗ 08.1](08_1_arrangement_extended_interactions.md): prolonged interactions, access, physical slots, placement/anchoring |
| R12 | planned | [ТЗ 09](09_dialogue_system.md): dialogue integration |
| R13 | planned | [ТЗ 13](13_environment_interactables.md) using R11.1 contracts |
| R14 | planned | [ТЗ 08](08_customer_challenge_framework.md): challenge lifecycle/light |
| R15 | planned | [ТЗ 08](08_customer_challenge_framework.md): gaze challenges |
| R16 | planned | [ТЗ 08](08_customer_challenge_framework.md): floor hazard challenge |
| R17 | planned | [ТЗ 10](10_combat_damage_health.md): combat/aggression; reuses R08 impact contract |
| R18 | planned | [ТЗ 11](11_hunger_system.md), ТЗ 09: hunger/perception |
| R19 | planned | [ТЗ 12](12_inventory_and_consumables.md), ТЗ 06/11: inventory/consumables |
| R20 | planned | [ТЗ 14](14_evening_meta_scaffold.md): evening/trader/orders/quest |
| R21 | planned | [ТЗ 15](15_night_save_next_day.md): persistence/next day |
| R22 | planned | [ТЗ 16](16_ui_and_feedback.md): HUD/feedback |
| R23 | planned | [ТЗ 17](17_vertical_slice_scenario.md): full vertical-slice validation |

## Cross-cutting design specs

Some ТЗ intentionally feed multiple implementation tasks:

- ТЗ 00 — overall prototype scope; final authority for R23 coverage.
- ТЗ 01 — GECS gameplay model used across all runtime tasks.
- ТЗ 02 — base interaction/physics contract reused by RM06.1, R11.1, R13 and R17.
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
- ТЗ 17 — scenario requirements feed multiple tasks and are fully validated by R23.
- ТЗ 18 — implementation-order guidance; this README is the canonical ID mapping when later insertions exist.

## Agent rule

When an implementation task says, for example, `R08`, open `agent_tasks/roadmap_08_*.md` first. Treat linked `ТЗ` files as source requirements, not as alternative task IDs.

If this mapping and an old prose reference disagree, this mapping plus the active task/checkpoint wins until the stale reference is corrected.
