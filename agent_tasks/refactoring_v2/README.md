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
37. [Visual Entity authoring](42_visual_entity_authoring.md)
38. [Smart Objects / Affordances / Reservations](../completed/refactoring_v2/43_smart_objects.md)
39. [Schedule / goal selection / LimboAI; GOAP deferred](../completed/refactoring_v2/44_ai_schedule_utility_goap.md)
40. [Simulation LOD](../completed/refactoring_v2/45_simulation_lod.md)
41. [Content Doctor](../completed/refactoring_v2/46_content_doctor.md)
42. [Gameplay Debugger](48_gameplay_debugger.md)
43. [Core architecture acceptance](49_core_architecture_acceptance.md)

### Phase 3 — Code Style refactor

44. [Formatter/linter как единый style gate](60_style_tooling.md)
45. [Systems, Observers, Components, Relationships](61_style_ecs_core.md)
46. [NPC и Customers](62_style_npc_customers.md)
47. [Interaction, Combat и Motion](63_style_interaction_combat_motion.md)
48. [Gameplay services, Economy, Inventory, Persistence](64_style_gameplay_services.md)
49. [Entities, UI, AI, scene scripts, tests и utils](65_style_remaining_code.md)
50. [Финальная приёмка Refactoring v2](66_final_acceptance.md)

## Current

Active Goal authorization (2026-10-10): complete the entire Refactoring v2 plan through
task **66**, including Phase 3 after the Phase-2 acceptance gate. This supersedes historical
session limits below that stopped at 49 or excluded Phase 3. The dependency order and
required acceptance remain in force; task 41 is DONE, with shutdown-only retention deferred.
Completed tasks move to `agent_tasks/completed/refactoring_v2/`; rendered gameplay and
subjective visual QA remain owner acceptance. Task42 code/review passes with OWNER_QA_PENDING;
Tasks43–45 runtime/schema are DONE. Continue 48–49 and 60–66 with required gates intact.

Phase 1 **DONE**: задачи 01–03 завершены 2026-10-07, 04 — 2026-10-08. Canonical roles/service smells/request timing, architecture guardrail, full structure repair и isolated identity/persistence baseline завершены. Phase 1 acceptance gate достигнут; runtime migration не начиналась.

Повторный Phase 0 pass завершён 2026-10-07 строго последовательно, с отдельным coherent commit каждой 00_задачи. Final full review [00_05](../completed/refactoring_v2/00_05_preflight_readiness_gate.md): **READY_FOR_IMPLEMENTATION**. Этот исторический gate разрешил Phase 1; его preflight pass завершён до реализации 01.

Phase 2A и 2B **DONE**. Execution ownership, typed contracts, all vertical-domain moves and removal of horizontal roots are complete; immutable checkpoints, reviews and acceptance evidence live in the linked archived owning tasks above.

Phase 2C: tasks 41, 43, 44, 45 and 47 are **DONE**, with evidence in their archived owning files. [42 — visual Entity authoring](42_visual_entity_authoring.md) is OWNER_QA_PENDING after implementation/re-review PASS. [46 — Content Doctor](../completed/refactoring_v2/46_content_doctor.md) is DONE after repaired immutable review. [48 — Gameplay Debugger](48_gameplay_debugger.md) is OWNER_QA_PENDING after implementation, review and headless gates PASS. Continue 48–49, then 60–66 after the core acceptance gate; mandatory owner acceptance remains open.

Old-save migration исключена владельцем; changed formats versioned/rejected, current-format roundtrip обязателен. GOAP/body detach/четыре tiers deferred; baseline ACTIVE/DORMANT with retained physical-root Entity and ECS-owned population records. Population/district schedules belong to npc, without separate district domain. Known structure failures (31, smoke reference/R26 metadata) устранены в 03.

Ни Phase 1, ни runtime migration не начинать до `READY_FOR_IMPLEMENTATION` в [00.05 — preflight readiness gate](../completed/refactoring_v2/00_05_preflight_readiness_gate.md).

Execution guardrail: `python utils/validate_architecture.py`; fixtures: `python -m unittest discover -s tests/tools -p test_validate_architecture.py`. Symbol/occurrence migration baseline хранится в `utils/architecture_baseline.json`, сокращается при каждом owning migration и обнуляется в 26. Gate 27: `python utils/validate_architecture.py --strict`. Infrastructure diagnostics (31, smoke reference/R26 metadata) устранены в 03: full structure PASS.

Identity/persistence baseline: `python utils/validate_persistence_baseline.py`; fixtures: `python -m unittest discover -s tests/tools -p test_validate_persistence_baseline.py`. Engine fixture: headless GUT `-gtest=res://tests/gut/test_refactoring_v2_persistence_baseline.gd -gexit`. `docs/persistence.md` owns identity/version/path contracts; 25 removes path matching and versions incompatible changes before 28–32.

Domain structure guardrail уже подготовлен в transition mode:
`python utils/validate_domain_structure.py`.

После завершения vertical-domain migration обязательные gates:
`python utils/validate_domain_structure.py --strict` и
`python utils/validate_domain_dependencies.py --strict`.

Dependency enforcement уже включён в structure gate: `python utils/validate_domain_dependencies.py`. Frozen exact baseline `utils/domain_dependency_baseline.json` может только сокращаться; owning-task DONE запрещает её exemption. `--prune-resolved` удаляет только resolved edges, never grants access.

Текущие roadmap links/dependencies/encoding: `python utils/validate_refactoring_preflight.py`.
Frozen Phase 0 docs gate: `python utils/validate_refactoring_preflight.py --require-gate` (проверяет состояние до implementation: все будущие tasks PLANNED и next01; после старта Phase 1 неприменим к текущему task state).
Fixtures: `python -m unittest discover -s tests/tools -p test_validate_refactoring_preflight.py`.

Phase 0 commit footprint: `python utils/validate_refactoring_preflight.py --phase0-commit <commit-id>`; repeat flag for each commit. Index before commit: `--check-staged-scope`. These checks include only owned committed/staged paths, preserving unrelated unstaged config/addon changes.

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
