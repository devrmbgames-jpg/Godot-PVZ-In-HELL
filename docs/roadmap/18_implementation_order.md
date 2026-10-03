# ТЗ 18 — Порядок реализации

Номера `ТЗ xx` — номера design specifications. Implementation IDs — `Rxx` / `Rxx.x`. Этот документ хранит зависимости и рекомендуемый порядок, но **не live status**.

Текущее выполнение ведётся через Codex Plan + Goal. Если конкретной работе нужен durable cross-session checkpoint, его хранит единственный соответствующий файл в `agent_tasks/`.

## Foundation

1. R01 — Package/runtime foundation.
2. R02 — contextual interaction foundation.
3. R03 — day phase cycle.
4. R04 — common damage/health pipeline.
5. R05 — morning receiving.
6. R06 — scanner / registration / terminal.
7. R06.1 — inspector-first interaction, Carry/two hands, control capture and Push.
8. R07 — physical marker and numbered shelves.
9. R08 — package damage/opening on the common Impact/Health contract.
10. R09 — package hazards reusing the common damage pipeline.
11. R10 — wallet / daily results before Customer outcomes.
12. R11 — customer flow / delivery / disputes.
13. R11.1 — generic extended interaction / arrangement foundation.

## Feature dependencies

- **R12 Dialogue** uses [ТЗ 09](09_dialogue_system.md) and existing Customer/outcome contracts.
- **R13 Environment interactables** uses [ТЗ 13](13_environment_interactables.md) and must reuse R11.1 access/slot/placement contracts.
- **R14–R16 Challenges** use [ТЗ 08](08_customer_challenge_framework.md) and share one lifecycle.
- **R17 Combat** uses [ТЗ 10](10_combat_damage_health.md) and reuses R08 damage/impact.
- **R18 Hunger / perception** uses [ТЗ 11](11_hunger_system.md) plus dialogue/perception hooks.
- **R19 Inventory / consumables** uses [ТЗ 12](12_inventory_and_consumables.md); virtual inventory remains distinct from physical slots.
- **R20 Evening / trader / orders / quest** uses [ТЗ 14](14_evening_meta_scaffold.md).
- **R21 Persistence / next day** uses [ТЗ 15](15_night_save_next_day.md) and stable IDs rather than live Object/NodePath identity.
- **R22 HUD / feedback** uses [ТЗ 16](16_ui_and_feedback.md); presentation never becomes gameplay authority.
- **R22.5 GECS architecture polish** is a broad architecture pass and must not be performed opportunistically inside unrelated feature work.
- **R23 Vertical slice validation** uses [ТЗ 00](00_prototype_overview.md) + [ТЗ 17](17_vertical_slice_scenario.md) and validates the complete day loop without inventing new major mechanics.

## Cross-cutting rule

Design documents own product requirements, not implementation progress. Never add PLANNED/IN_PROGRESS/DONE tables here. Inspect current code and the exact active durable task, when one exists, instead of inferring status from roadmap prose.

Canonical design mapping: [README.md](README.md).
