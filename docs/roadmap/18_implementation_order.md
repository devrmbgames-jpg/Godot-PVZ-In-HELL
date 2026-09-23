# ТЗ 18 — Порядок реализации для ИИ агентов

> **Важно:** номера `ТЗ xx` — это номера design specifications, а не implementation-order.
> Канонические implementation IDs — `Rxx` / `Rxx.x`.
> Полная таблица соответствия: [Roadmap canonical map](README.md).

## Правило работы

Каждый implementation task должен давать маленький проверяемый gameplay result.

Порядок определяется этим документом + [README](README.md) + `agent_tasks/` + `task_history.md`, а не номером исходного ТЗ.

Завершённые task-файлы намеренно удаляются из `agent_tasks/`; их статус подтверждается `task_history.md`.

## Завершённый foundation

1. **R01** — Package/runtime foundation.
2. **R02** — contextual interaction foundation.
3. **R03** — day phase cycle.
4. **R04** — common damage/health pipeline.
5. **R05** — morning receiving.
6. **R06** — scanner / registration / terminal.
7. **R06.1** — Inspector-first components, Carry/two hands, control capture and Push.
8. **R07** — physical marker and numbered shelves.
9. **R08** — generic physical Impact, common Health/depletion, package durability and deliberate opening (accepted 2026-09-24).

Не создавать заново task-файлы этих этапов. Использовать durable contracts из roadmap/context и подтверждать завершение через `task_history.md`.

---

## R08 — Package Damage / Opening (completed)

Completed 2026-09-24; confirmed in [task_history.md](../../task_history.md). Durable contract: [damage_impact.md](../damage_impact.md). The completed task file was removed from `agent_tasks/`.

Основной источник: [ТЗ 06](06_package_damage_and_hazards.md).

Результат:
- physical impact → typed impact contract;
- Package HP/Integrity;
- weak/medium/strong severity;
- Fragile;
- Bubble Wrap protection state;
- Liquid tilt;
- opening;
- **обязательный M5.1 GECS architecture gate для `S_Damage` + `S_Impact` до начала M6**: убрать System→System coupling, `ECS.world.systems` service locator, разделить contact capture/resolution и перевести throw lifetime на specific query + `iterate()`.

---

## R09 — Package Hazards

Task: [roadmap_09_package_hazards.md](../../agent_tasks/roadmap_09_package_hazards.md)

Основной источник: [ТЗ 06](06_package_damage_and_hazards.md).

Результат:
- ToxicLeak;
- Explosion;
- оба эффекта используют общий damage pipeline.

---

## R10 — Wallet / Daily Results

Task: [roadmap_10_wallet_and_daily_results.md](../../agent_tasks/roadmap_10_wallet_and_daily_results.md)

Источники: [ТЗ 07](07_customer_flow_and_delivery.md), [ТЗ 14](14_evening_meta_scaffold.md), [ТЗ 15](15_night_save_next_day.md).

Результат:
- Money/Penalties;
- typed idempotent settlement operations;
- daily result contract.

R10 идёт **до R11**, потому что Customer outcome должен отправлять денежный результат в уже существующий authority, а не создавать деньги внутри Customer/UI.

---

## R11 — Customer Flow / Delivery / Disputes

Task: [roadmap_11_customer_flow_and_delivery.md](../../agent_tasks/roadmap_11_customer_flow_and_delivery.md)

Основной источник: [ТЗ 07](07_customer_flow_and_delivery.md).

Результат:
- Customer schedule/lifecycle;
- RequestedPackage;
- actual outcome отдельно от Terminal declaration;
- voluntary refusal / Player denial / Lost;
- Complaint/dispute;
- late Customer and long-lived Package.

---

## R11.1 — Extended Interaction / Arrangement

Task: [roadmap_11_1_extended_interactions_and_arrangement.md](../../agent_tasks/roadmap_11_1_extended_interactions_and_arrangement.md)

Основной источник: [ТЗ 08.1](08_1_arrangement_extended_interactions.md).

Результат:
- prolonged interaction + progress/reset policies;
- generic access requirements;
- physical storage/body slots;
- Carry PlacementArea;
- Hammer Fix/Unfix;
- support-neighbor unfix safety.

R11.1 — отдельный generic foundation. R13/R19 должны **переиспользовать** его, а не создавать параллельные Door/storage/placement systems.

---

## R12 — Dialogue Integration

Task: [roadmap_12_dialogue_integration.md](../../agent_tasks/roadmap_12_dialogue_integration.md)

Основной источник: [ТЗ 09](09_dialogue_system.md).

Результат:
- DialogueManager adapter;
- gameplay conditions/actions;
- package/customer/dispute integration;
- riddle/dialogue flow.

---

## R13 — Environment Interactables

Task: [roadmap_13_environment_interactables.md](../../agent_tasks/roadmap_13_environment_interactables.md)

Источники: [ТЗ 08.1](08_1_arrangement_extended_interactions.md), [ТЗ 13](13_environment_interactables.md).

Результат:
- Door;
- Window;
- Drawer;
- LightSwitch;
- применение generic contracts R11.1.

---

## R14–R16 — Customer Challenge Families

Tasks:
- [R14](../../agent_tasks/roadmap_14_challenge_framework_and_lights.md) — shared Challenge lifecycle + Light;
- [R15](../../agent_tasks/roadmap_15_gaze_challenges.md) — Don't Look / Keep Looking;
- [R16](../../agent_tasks/roadmap_16_floor_hazard_challenge.md) — Floor Hazard.

Основной источник: [ТЗ 08](08_customer_challenge_framework.md).

Результат: минимум три разные challenge families используют общий lifecycle.

---

## R17 — Combat / Aggressive Customer

Task: [roadmap_17_combat_and_impact_damage.md](../../agent_tasks/roadmap_17_combat_and_impact_damage.md)

Основной источник: [ТЗ 10](10_combat_damage_health.md).

Результат:
- melee;
- Aggressive Customer;
- combat cleanup/reasons;
- physical impact damage **переиспользует R08 contract**, а не создаёт вторую формулу.

---

## R18 — Hunger / Perception

Task: [roadmap_18_hunger_and_perception.md](../../agent_tasks/roadmap_18_hunger_and_perception.md)

Источники: [ТЗ 11](11_hunger_system.md), [ТЗ 09](09_dialogue_system.md).

Результат:
- Hunger;
- modifiers;
- perception/dialogue distortion без изменения gameplay identity.

---

## R19 — Inventory / Consumables

Task: [roadmap_19_inventory_and_consumables.md](../../agent_tasks/roadmap_19_inventory_and_consumables.md)

Источники: [ТЗ 12](12_inventory_and_consumables.md), [ТЗ 08.1](08_1_arrangement_extended_interactions.md).

Результат:
- virtual small-item Inventory;
- stack/use;
- Food/MedItem/Bubble Wrap;
- virtual Inventory остаётся отдельным от physical slots R11.1.

---

## R20 — Evening / Trader / Orders / Quest

Task: [roadmap_20_evening_trader_orders_and_quest.md](../../agent_tasks/roadmap_20_evening_trader_orders_and_quest.md)

Основной источник: [ТЗ 14](14_evening_meta_scaffold.md).

Результат:
- Trader;
- next-day order;
- Package quest;
- data-defined prices/upgrades.

---

## R21 — Persistence / Next Day

Task: [roadmap_21_night_persistence_next_day.md](../../agent_tasks/roadmap_21_night_persistence_next_day.md)

Основной источник: [ТЗ 15](15_night_save_next_day.md).

Результат:
- Night transaction;
- Save/Load;
- PendingDelivery;
- active Packages/disputes/late Customers across days;
- persistent world arrangement from R11.1 where applicable.

---

## R22 — HUD / World Feedback

Task: [roadmap_22_hud_and_world_feedback.md](../../agent_tasks/roadmap_22_hud_and_world_feedback.md)

Основной источник: [ТЗ 16](16_ui_and_feedback.md).

Результат:
- финальная читаемость существующих systems;
- feedback не становится gameplay authority.

---

## R22.5 — GECS Architecture Polish

Task: [roadmap_22_5_gecs_architecture_polish.md](../../agent_tasks/roadmap_22_5_gecs_architecture_polish.md)

Источник: upstream GECS `BEST_PRACTICES.md` + project `.agents/skills/gecs-v8/SKILL.md`.

Результат:
- полный disposition-аудит всех текущих `S_*`: keep / split / reclassify / remove;
- atomic Systems/sub-systems with single responsibility;
- no direct System-to-System service calls or `ECS.world.systems` service-locator pattern;
- hot-path Components supplied through specific queries + `iterate()`;
- Cart/Push/Grab/Input decomposition plus Receiving/DayPhase/Marker/Targeting cleanup; Damage/Impact здесь только regression-audit, потому что их cleanup выполняется в R08 M5.1;
- presentation separated from gameplay authority, including Crouch camera vs collision/state;
- static physics-only/pseudo-System classes reclassified as independent solvers/helpers and stale System nodes removed;
- empty/obsolete System shells such as `S_Door` re-verified and removed if still unused;
- SystemGroups/`deps()` express ordering;
- gameplay behavior preserved.

R22.5 intentionally runs late. Do not perform this broad refactor opportunistically during R08–R22 while feature contracts are still changing.

Damage/Impact cleanup выполнен в R08 M5.1; в R22.5 остаётся только регрессионный аудит этих подсистем.

---

## R23 — Vertical Slice Validation

Task: [roadmap_23_vertical_slice_validation.md](../../agent_tasks/roadmap_23_vertical_slice_validation.md)

Источники: [ТЗ 00](00_prototype_overview.md), [ТЗ 17](17_vertical_slice_scenario.md).

На этом этапе **не добавлять новые крупные mechanics**. Исправлять только разрывы уже реализованных contracts/core loop.

Финальный маршрут:

```text
Morning Receiving
→ Package Handling / Arrangement
→ Day Customer Service + Horror Events
→ Evening Preparation
→ Night Sleep / Save
→ Next Morning
```

## Финальный критерий

Игрок способен пройти полный цикл без debug-команд, а все игровые решения проходят через единый physical world + GECS gameplay state.

Если старый roadmap-текст противоречит этому implementation-order по номеру задачи, использовать канонический mapping из [README](README.md) и исправить stale reference вместо догадки.
