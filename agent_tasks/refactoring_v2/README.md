# Refactoring v2 — полный Core Architecture + Code Style рефакторинг

Status: **IN_PROGRESS**

Task state lives in the linked owning files; this index does not assign a next task.

Рабочая ветка Phase 0: `dev`. Историческая подготовка: `chore/gdscript-human-first-style`; это не требование checkout.

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

## Preliminary Phase 0 + три implementation-фазы

### Phase 0 — Architecture Preflight

До любого implementation/refactor провести отдельный xhigh planning pass. Текущая target architecture считается сильным кандидатом, но её разрешено упрощать, дополнять или менять, если это делает ядро заметно удобнее для Godot, programmers, designers/content authors, debugging и AI-agent workflow.

1. [Architecture coherence audit](../completed/refactoring_v2/00_01_architecture_coherence_audit.md)
2. [Usability и content-authoring audit](../completed/refactoring_v2/00_02_usability_authoring_audit.md)
3. [Simplification / overengineering / reference audit](../completed/refactoring_v2/00_03_simplification_reference_audit.md)
4. [Migration / persistence / validation audit](../completed/refactoring_v2/00_04_migration_persistence_validation_audit.md)
5. [Preflight readiness gate](../completed/refactoring_v2/00_05_preflight_readiness_gate.md)

Phase 1 запрещено начинать до результата `READY_FOR_IMPLEMENTATION` в `00_05_preflight_readiness_gate.md`.

## Три implementation-фазы

1. **Закрепить архитектурные правила.**
   Сделать роли, ownership и validation guardrails однозначными до runtime migration.

2. **Полный рефакторинг архитектуры/core.**
   Исправить execution model, перейти на vertical domains, закрепить typed contracts, minimal Templates/Traits, scene-first authoring, Smart Objects, Schedule/goal selection/LimboAI, ACTIVE/DORMANT participation, Content Doctor, Game Time/randomness и Gameplay Debugger. GOAP, body detach и четыре LOD tiers отложены.

3. **Рефакторинг под Code Style.**
   Только после стабильной архитектуры пройти всю project-owned GDScript базу по human-first style и единому formatter/linter gate. New/materially changed code следует существующему gdscript-style и parser gates уже в Phase 2; поздний bulk style pass не разрешает писать нечитаемый или untyped implementation.

## Global constraints

- Godot 4.7, Forward Plus, Jolt, GECS v8, LimboAI и Dialogue Manager сохраняются.
- Third-party `addons/` не изменять; project-owned companion tooling подчиняется
  editor ownership, native extension APIs и обязательной проверке.
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

6. [Архитектурные роли и ownership](../completed/refactoring_v2/01_architecture_contract.md)
7. [Scheduled execution и Service boundaries](../completed/refactoring_v2/02_execution_ownership_rules.md)
8. [Architecture validation и service smells](../completed/refactoring_v2/03_architecture_validation.md)
9. [Identity, persistence и migration baseline](../completed/refactoring_v2/04_identity_persistence_contract.md)

Phase 2 начинается только после закрытия всех Phase 1 tasks.

### Phase 2A — Execution model cleanup

10. [Полный inventory сервисов](../completed/refactoring_v2/10_service_inventory.md)
11. [Typed Commands / Events](../completed/refactoring_v2/40_typed_commands_events.md)
12. [CustomerFlow: planning, arrival и day transitions](../completed/refactoring_v2/11_customer_flow_planning.md)
13. [CustomerFlow: активный lifecycle визита](../completed/refactoring_v2/12_customer_flow_runtime.md)
14. [Customer outcomes и settlement](../completed/refactoring_v2/13_customer_outcomes.md)
15. [District lifecycle и schedule](../completed/refactoring_v2/14_district_lifecycle.md)
16. [NPC brain, perception и traits](../completed/refactoring_v2/15_npc_brain.md)
17. [NPC route и service role](../completed/refactoring_v2/16_npc_route_service_role.md)
18. [Combat, attacks и projectiles](../completed/refactoring_v2/17_combat.md)
19. [Challenge lifecycle](../completed/refactoring_v2/18_challenges.md)
20. [Hunger и Quests](../completed/refactoring_v2/19_hunger_quests.md)
21. [Interaction input и action routing](../completed/refactoring_v2/20_interaction_input.md)
22. [Grab, Push, Carry и physical slots](../completed/refactoring_v2/21_grab_push_slots.md)
23. [Motion и physics boundaries](../completed/refactoring_v2/22_motion_physics.md)
24. [Hazards, receiving, loot и delivery runtime](../completed/refactoring_v2/23_hazards_receiving_loot.md)
25. [Economy, Inventory и Commerce](../completed/refactoring_v2/24_economy_inventory_commerce.md)
26. [Persistence и remaining services](../completed/refactoring_v2/25_persistence_remaining.md)
27. [Очистка execution graph](../completed/refactoring_v2/26_execution_graph_cleanup.md)
28. [Execution-model acceptance checkpoint](../completed/refactoring_v2/27_architecture_acceptance.md)

### Phase 2B — Contracts и vertical domains

Typed contracts уже закреплены задачей 40 перед execution migration. Здесь переносится завершённый execution model; dependency guardrail появляется до первого domain move.

29. [Domain layout contract + validator](../completed/refactoring_v2/28_domain_layout_contract.md)
30. [Domain dependency validation — transition gate](../completed/refactoring_v2/33_domain_dependency_validation.md)
31. [Domains: NPC и Customers](../completed/refactoring_v2/29_domain_npc_customers.md)
32. [Domains: Interaction, Combat и Motion](../completed/refactoring_v2/30_domain_interaction_combat_motion.md)
33. [Domains: world gameplay](../completed/refactoring_v2/31_domain_world_economy_packages.md)
34. [Shared core + удаление horizontal roots](../completed/refactoring_v2/32_domain_shared_core.md)

После 32 обязателен strict rerun dependency validator задачи 33 без migration baseline.

### Phase 2C — Core framework

35. [Unified Game Time + deterministic randomness — foundation](../completed/refactoring_v2/47_game_time_randomness.md)
36. [Entity Templates / Traits](../completed/refactoring_v2/41_entity_templates_traits.md)
37. [Visual Entity authoring](../completed/refactoring_v2/42_visual_entity_authoring.md)
38. [Smart Objects / Affordances / Reservations](../completed/refactoring_v2/43_smart_objects.md)
39. [Schedule / goal selection / LimboAI; GOAP deferred](../completed/refactoring_v2/44_ai_schedule_utility_goap.md)
40. [Simulation LOD](../completed/refactoring_v2/45_simulation_lod.md)
41. [Content Doctor](../completed/refactoring_v2/46_content_doctor.md)
42. [Gameplay Debugger](../completed/refactoring_v2/48_gameplay_debugger.md)
43. [Core architecture acceptance](../completed/refactoring_v2/49_core_architecture_acceptance.md)

### Phase 3 — Code Style refactor

44. [Formatter/linter как единый style gate](../completed/refactoring_v2/60_style_tooling.md)
45. [Systems, Observers, Components, Relationships](../completed/refactoring_v2/61_style_ecs_core.md)
46. [NPC и Customers](../completed/refactoring_v2/62_style_npc_customers.md)
47. [Interaction, Combat и Motion](../completed/refactoring_v2/63_style_interaction_combat_motion.md)
48. [Gameplay services, Economy, Inventory, Persistence](../completed/refactoring_v2/64_style_gameplay_services.md)
49. [Entities, UI, AI, scene scripts, tests и utils](../completed/refactoring_v2/65_style_remaining_code.md)
50. [Финальная приёмка Refactoring v2](66_final_acceptance.md)

## Current

Authorization: complete Refactoring v2 through66 in dependency order. Phase0, Phase1,
Phase2A/2B/2C and core gate49 are DONE; their owning records are archived.
Owner explicitly accepted current Inspector/Direct Traits and Gameplay Debugger on
2026-10-10. Tasks42/48 and direct Traits have passed implementation, review and acceptance.
Gate49: current core GUT220/2373, full tooling134/134, Content Doctor92 scenes/three dialogues,
strict architecture/domain/dependency, native parser, persistence and package smokes PASS.
Native Inspector signal regression: live MCP9/9, source controls survive their signals,
Inspector restored, authored content unchanged. Independent current repair review PASS.

Phase3 tasks60–66 are now permitted by the archived gate49. See the individual owning
files for their actual implementation status; no remaining Phase2 owner approval blocks them.
Tasks60–65 and the native diagnostics self-compilation defect are archived DONE after
independent immutable review. Manifest native checks cover309+163+106+72+330=980 scripts;
task65's six mandatory enum callers were checked again with MCP at final acceptance.
Full formatter/linter covers all980; strict structure/domain/dependency gates pass.
Task66 owns final all-suite GUT, connected/save-restore smokes, Windows export and review.
Task62's independently evidenced schedule-completion cycle is repaired.
General CLI runner reports shutdown-retention FAIL for a lifecycle fixture; actual isolated
compiler PASS,exit0. This remains owner-deferred engine retention, with logs preserved.
Phase3 manifest owns980 authored scripts exactly once and excludes generated artifacts.
Old-save conversion is excluded; current schema10 roundtrip remains mandatory.
GOAP/body detach/four LOD tiers remain deferred. Shutdown-only4.7.1 retention remains
KNOWN_ENGINE_LIMITATION / DEFERRED; runtime ownership defects are not waived.
Existing owner worktree changes are preserved. No agent rendered gameplay/visual run is claimed.

Validation: `python utils/validate_project_structure.py`,
`python -B utils/validate_architecture.py --strict`,
`python utils/validate_domain_structure.py --strict`,
`python utils/validate_domain_dependencies.py --strict`.
Frozen Phase0 `--require-gate` is historical and inapplicable after implementation starts.
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
- macro obligations/goal selection и realtime LimboAI/local execution имеют один state owner; GOAP не mandatory;
- ACTIVE/DORMANT participation сохраняет physical-root Entity и explicit per-field aggregate/actor authority; body detach/четыре tiers не mandatory;
- Content Doctor ловит broken authored content headless;
- Game Time/random decisions имеют explicit reproducible contracts;
- Gameplay Debugger объясняет состояние выбранной Entity;
- вся project-owned GDScript база проходит formatter/linter/style gate;
- parser/static validation, профильные GUT/smoke и итоговая integration validation PASS;
- remaining subjective QA вынесена в `qa_tasks/`.

## Recommended GPT-6.1 Sol reasoning

Use `gpt-6.1-sol` throughout Refactoring v2 and change reasoning effort by task type rather than switching model families.

- **high** — normal implementation default: bounded domain refactors, moving ownership, writing Systems/Observers, tests, validators, Traits, Smart Objects and ordinary bug fixing.
- **xhigh** — весь Phase 0 Architecture Preflight и дальнейшие planning/architecture/review задачи: Phase 1 rules, service inventory classification, execution-graph design, vertical-domain boundaries, Commands/Events contract, Traits architecture, GOAP/LOD design, difficult debugging, migration planning and milestone review.
- **max** — rare architecture gates only: resolving a genuinely ambiguous cross-domain design, reviewing a large completed architectural milestone, or final Phase 2 / Refactoring v2 acceptance when a missed flaw would propagate through the whole project.
- **medium** — mechanical work after architecture is already decided: straightforward path/resource updates, repetitive file moves, simple fixtures, generated migration edits, documentation synchronization and low-risk Code Style batches.
- **low** — only for trivial mechanical edits with a completely explicit transformation. Do not use it for ownership decisions, architecture classification, physics, persistence, AI planning, or review.

Practical default for Codex configuration:

```toml
model = "gpt-6.1-sol"
model_reasoning_effort = "high"
plan_mode_reasoning_effort = "xhigh"
```

Escalate an individual task to `max` only when the task itself is an architecture/final-review gate. Do not run the whole refactor at `max`: most implementation work gains little from paying the maximum reasoning budget continuously.

## Rule for continuing

Внутри активного Goal выполнять задачи последовательно с отдельными coherent checkpoints, соблюдать зависимости и acceptance. Читать выбранную задачу и прямых владельцев; после завершения обновлять owning state и ссылки. Текущий Goal явно разрешает весь план до 66.
