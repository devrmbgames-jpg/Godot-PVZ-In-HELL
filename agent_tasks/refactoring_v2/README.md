# Refactoring v2 — полный архитектурный и Code Style рефакторинг

Status: **PLANNED**

Базовая ветка: `chore/gdscript-human-first-style`.

## Goal

Пока проект находится на ранней стадии, привести кодовую базу к одной прозрачной архитектуре: ECS graph должен описывать реальное scheduled-поведение, сервисный слой не должен быть скрытым вторым scheduler'ом, а весь project-owned GDScript после архитектурной миграции должен соответствовать human-first Code Style.

Рефакторинг сохраняет текущее игровое поведение. Изменения механик, баланса, контента и UX не входят в эту работу, кроме минимальных исправлений, без которых невозможно сохранить существующий контракт.

## Три фазы

1. **Закрепить архитектурные правила.**
   Сначала сделать границы `System / Observer / Service / Solver / Rules / Geometry / Factory / Presentation` явным проектным контрактом и добавить автоматические проверки архитектурных запахов.

2. **Рефакторинг архитектуры.**
   Убрать скрытые Systems из сервисов, вернуть scheduled/time-based orchestration в `S_*`, дискретные переходы — в `O_*`, оставить сервисам явные синхронные domain-операции, а чистые алгоритмы — Rules/Calculation/Solver/Geometry.

3. **Рефакторинг под Code Style.**
   После стабилизации архитектуры пройти всю project-owned GDScript базу по `.agents/skills/gdscript-style/SKILL.md`, formatter/linter и human-first требованиям без повторного изменения архитектуры.

## Global constraints

- Godot 4.7, Forward Plus, Jolt, GECS v8 и текущий LimboAI сохраняются.
- `addons/` не изменять.
- Поведение сохранять; архитектурную миграцию не смешивать с feature work.
- Components остаются данными/состоянием; Relationships — authoritative live Entity-to-Entity bindings.
- Systems владеют scheduled поведением и порядком выполнения. Observers владеют дискретными реакциями.
- Service не должен становиться скрытой System.
- Не переносить код механически только ради уменьшения числа файлов. Граница определяется ownership и временем исполнения.
- Physics-callback solvers вроде `CharacterMotionSolver` могут оставаться вне Systems, если движок требует исполнения внутри physics callback.
- Не делать один гигантский `S_*` вместо гигантского Service: делить по независимым scheduling responsibilities.
- После каждого небольшого этапа — узкая проверка и отдельный связный commit. Полные suite/runtime проверки — на приёмочных этапах, а не после каждой правки.
- Не запускать rendered gameplay автоматически. Если после крупного этапа нужна визуальная/gameplay QA — оформить owner QA.
- Субагенты, если используются, запускать только последовательно.

## Порядок выполнения

### Phase 1 — Architecture contract

1. [Архитектурные роли и ownership](01_architecture_contract.md)
2. [Правила scheduled execution и Service boundaries](02_execution_ownership_rules.md)
3. [Architecture validation и service smells](03_architecture_validation.md)

Phase 2 начинается только после закрытия всех трёх задач Phase 1.

### Phase 2 — Architecture refactor

4. [Полный inventory сервисов](10_service_inventory.md)
5. [CustomerFlow: planning, arrival и day transitions](11_customer_flow_planning.md)
6. [CustomerFlow: активный lifecycle визита](12_customer_flow_runtime.md)
7. [Customer outcomes и settlement](13_customer_outcomes.md)
8. [District lifecycle и schedule](14_district_lifecycle.md)
9. [NPC brain, perception и traits](15_npc_brain.md)
10. [NPC route и service role](16_npc_route_service_role.md)
11. [Combat, attacks и projectiles](17_combat.md)
12. [Challenge lifecycle](18_challenges.md)
13. [Hunger и Quests](19_hunger_quests.md)
14. [Interaction input и action routing](20_interaction_input.md)
15. [Grab, Push, Carry и physical slots](21_grab_push_slots.md)
16. [Motion и physics boundaries](22_motion_physics.md)
17. [Hazards, receiving, loot и delivery runtime](23_hazards_receiving_loot.md)
18. [Economy, Inventory и Commerce](24_economy_inventory_commerce.md)
19. [Persistence и remaining services](25_persistence_remaining.md)
20. [Очистка execution graph](26_execution_graph_cleanup.md)
21. [Архитектурная приёмка Phase 2](27_architecture_acceptance.md)

### Phase 3 — Code Style refactor

22. [Formatter/linter как единый style gate](30_style_tooling.md)
23. [Systems, Observers, Components, Relationships](31_style_ecs_core.md)
24. [NPC и Customers](32_style_npc_customers.md)
25. [Interaction, Combat и Motion](33_style_interaction_combat_motion.md)
26. [Gameplay services, Economy, Inventory, Persistence](34_style_gameplay_services.md)
27. [Entities, UI, AI tasks, scenes scripts, tests и utils](35_style_remaining_code.md)
28. [Финальная приёмка Refactoring v2](36_final_acceptance.md)

## Current

План создан. Реализация не начиналась.

Первое действие: выполнить только [01 — архитектурные роли и ownership](01_architecture_contract.md). Не начинать массовую миграцию кода до фиксации правил и validation guardrails.

## Global acceptance

Refactoring v2 считается завершённым, когда:

- execution graph можно понять по `S_*`, `O_*`, их queries и `deps()`, без поиска регулярных `Service.tick()`;
- project-owned Service не владеет регулярным frame/physics tick, кроме явно документированных engine-bound adapter/solver исключений;
- thin System, единственная обязанность которой — вызвать `SomeService.tick/process/update`, отсутствует либо имеет документированное исключение;
- broad per-frame ECS iteration не спрятан в Service;
- дискретные lifecycle transitions не polling'уются каждый кадр без необходимости;
- сервисы имеют явные domain API (`submit`, `start`, `finish`, `bind`, `resolve`, `spawn`, `calculate` и т. п.);
- вся project-owned GDScript база проходит утверждённый formatter/linter/style gate;
- parser/static validation, структура, профильные GUT/smoke и итоговая интеграционная проверка проходят;
- оставшаяся ручная визуальная/gameplay QA вынесена в `qa_tasks/`.

## Rule for continuing

На один рабочий запрос брать одну задачу из списка. Читать этот README, выбранную задачу и только прямые владельцы затрагиваемого кода. После завершения обновлять Status/Current/Validation выбранной задачи и следующее действие здесь.
