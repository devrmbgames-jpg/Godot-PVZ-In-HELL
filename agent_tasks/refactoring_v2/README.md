# Refactoring v2 — полный Core Architecture + Code Style рефакторинг

Status: **PLANNED**

Базовая ветка: `chore/gdscript-human-first-style`.

Целевая архитектура: [Project Core Architecture](../../docs/project_core_architecture_proposal.md).

## Goal

Пока проект находится на ранней стадии, довести кодовую базу до устойчивого gameplay core, после которого новый контент в основном создаётся через сцены/ассеты, Definitions, Entity Templates/Traits, Smart Objects, Dialogue, AI profiles/schedules и настройки уровней.

Рефакторинг сохраняет текущее игровое поведение, если конкретная задача явно не вводит новый core capability. Изменения баланса, контента и UX не смешивать с архитектурной миграцией.

## Full-refactor invariant

Если выбран архитектурный scope, он доводится до целевого состояния полностью.

Не считать milestone завершённым, если внутри его scope остались permanent:
- старый и новый execution path одновременно;
- compatibility wrappers/aliases только ради старых callers;
- duplicate authority;
- renamed/moved files без изменения ownership;
- половина domain в новом layout, половина в legacy horizontal roots;
- бессрочный migration allowlist известных нарушений.

Temporary adapters допустимы только внутри незавершённого milestone и удаляются до DONE, если внешний compatibility contract не требует иного.

## Три фазы

1. **Закрепить архитектурные правила.**
   Сделать роли, ownership и validation guardrails однозначными до runtime migration.

2. **Полный рефакторинг архитектуры/core.**
   Исправить execution model, перейти на vertical domains, закрепить typed Commands/Events, Templates/Traits, scene-first authoring, Smart Objects, AI layering, Simulation LOD, Content Doctor, Game Time/deterministic randomness и Gameplay Debugger.

3. **Рефакторинг под Code Style.**
   Только после стабильной архитектуры пройти всю project-owned GDScript базу по human-first style и единому formatter/linter gate.

## Global constraints

- Godot 4.7, Forward Plus, Jolt, GECS v8, LimboAI и Dialogue Manager сохраняются.
- `addons/` не изменять.
- Components/Relationships остаются authoritative gameplay state.
- Systems владеют scheduled поведением; Observers — discrete reactions.
- Service не должен становиться скрытой System.
- UI — обычный Godot `Control`/glue layer, **не ECS**.
- Traits/Templates — authoring/compiler layer, не runtime scheduler и не mutable gameplay state.
- Визуальное scene authoring сохраняется: placed NPC/object должен оставаться видимым реальным объектом в Godot Editor.
- Placed и runtime-spawned Entity после materialization имеют один runtime contract.
- Не заменять большой Service одним гигантским System; делить по scheduling responsibility.
- Physics-callback solvers остаются вне Systems, если Godot/Jolt требует callback ownership.
- Субагенты, если используются, запускать только последовательно.
- Не запускать rendered gameplay автоматически; subjective visual/gameplay QA оформлять владельцу.
- После небольшого этапа — узкая проверка и отдельный coherent commit; broad smoke/suite — на milestone acceptance.

## Порядок выполнения

### Phase 1 — Architecture contract

1. [Архитектурные роли и ownership](01_architecture_contract.md)
2. [Scheduled execution и Service boundaries](02_execution_ownership_rules.md)
3. [Architecture validation и service smells](03_architecture_validation.md)

Phase 2 начинается только после закрытия всех Phase 1 tasks.

### Phase 2A — Execution model cleanup

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
21. [Execution-model acceptance checkpoint](27_architecture_acceptance.md)

### Phase 2B — Vertical domains

22. [Domain layout contract + validator](28_domain_layout_contract.md)
23. [Domains: NPC и Customers](29_domain_npc_customers.md)
24. [Domains: Interaction, Combat и Motion](30_domain_interaction_combat_motion.md)
25. [Domains: world gameplay](31_domain_world_economy_packages.md)
26. [Shared core + удаление horizontal roots](32_domain_shared_core.md)
27. [Domain dependency validation](33_domain_dependency_validation.md)

### Phase 2C — Core framework

28. [Typed Commands / Events](40_typed_commands_events.md)
29. [Entity Templates / Traits](41_entity_templates_traits.md)
30. [Visual Entity authoring](42_visual_entity_authoring.md)
31. [Smart Objects / Affordances / Reservations](43_smart_objects.md)
32. [Schedule → Utility → GOAP → LimboAI](44_ai_schedule_utility_goap.md)
33. [Simulation LOD](45_simulation_lod.md)
34. [Content Doctor](46_content_doctor.md)
35. [Unified Game Time + deterministic randomness](47_game_time_randomness.md)
36. [Gameplay Debugger](48_gameplay_debugger.md)
37. [Core architecture acceptance](49_core_architecture_acceptance.md)

### Phase 3 — Code Style refactor

38. [Formatter/linter как единый style gate](60_style_tooling.md)
39. [Systems, Observers, Components, Relationships](61_style_ecs_core.md)
40. [NPC и Customers](62_style_npc_customers.md)
41. [Interaction, Combat и Motion](63_style_interaction_combat_motion.md)
42. [Gameplay services, Economy, Inventory, Persistence](64_style_gameplay_services.md)
43. [Entities, UI, AI, scene scripts, tests и utils](65_style_remaining_code.md)
44. [Финальная приёмка Refactoring v2](66_final_acceptance.md)

## Current

План расширен до полного core refactor. Реализация runtime migration не начиналась.

Первое действие: выполнить только [01 — архитектурные роли и ownership](01_architecture_contract.md). Не начинать массовую runtime migration до фиксации rules/validation.

Domain structure guardrail уже подготовлен в transition mode:
`python utils/validate_domain_structure.py`.

После завершения vertical-domain migration обязательный gate:
`python utils/validate_domain_structure.py --strict`.

## Global acceptance

Refactoring v2 завершён, когда:

- execution graph читается по `S_*`, `O_*`, queries и `deps()`;
- Service не владеет скрытым регулярным scheduler lifecycle;
- vertical domains полностью заменили legacy horizontal gameplay roots;
- strict domain validator и dependency validator PASS;
- key cross-domain flows используют typed Commands/Events или stable APIs;
- Templates/Traits deterministic и не содержат runtime authority;
- placed Entity остаются полноценно видимыми/настраиваемыми в Godot Editor;
- Smart Objects/reservations имеют единый contract;
- macro AI разделён на Schedule/Utility/GOAP, realtime execution остаётся LimboAI/local systems;
- Simulation LOD не создаёт duplicate identity/state;
- Content Doctor ловит broken authored content headless;
- Game Time/random decisions имеют explicit reproducible contracts;
- Gameplay Debugger объясняет состояние выбранной Entity;
- вся project-owned GDScript база проходит formatter/linter/style gate;
- parser/static validation, профильные GUT/smoke и итоговая integration validation PASS;
- remaining subjective QA вынесена в `qa_tasks/`.

## Rule for continuing

На один рабочий запрос брать одну выбранную небольшую задачу. Читать этот README, выбранную задачу и только прямых владельцев кода/контрактов. После завершения обновлять Status/Current/Validation задачи и следующее действие здесь.
