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
5. [Customer Flow orchestration](11_customer_flow.md)
6. [Customer supporting services](12_customer_services.md)
7. [NPC brain, perception и schedule](13_npc_brain_schedule.md)
8. [NPC route, service role и district lifecycle](14_npc_route_service_role.md)
9. [Combat и projectiles](15_combat.md)
10. [Challenges, Hunger и Quests](16_challenges_hunger_quests.md)
11. [Interaction и input orchestration](17_interaction.md)
12. [Motion и physics boundaries](18_motion_physics.md)
13. [Hazards, receiving, loot и delivery](19_hazards_receiving_loot.md)
14. [Economy, inventory, persistence и remaining services](20_economy_inventory_persistence.md)
15. [Удаление shell Systems и скрытого execution graph](21_execution_graph_cleanup.md)
16. [Архитектурная приёмка Phase 2](22_architecture_acceptance.md)

### Phase 3 — Code Style refactor

17. [Formatter/linter как единый style gate](30_style_tooling.md)
18. [Systems, Observers, Components, Relationships](31_style_ecs_core.md)
19. [NPC и Customers](32_style_npc_customers.md)
20. [Interaction, Combat и Motion](33_style_interaction_combat_motion.md)
21. [Gameplay services, Economy, Inventory, Persistence](34_style_gameplay_services.md)
22. [Entities, UI, AI tasks, scenes scripts, tests и utils](35_style_remaining_code.md)
23. [Финальная приёмка Refactoring v2](36_final_acceptance.md)

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
