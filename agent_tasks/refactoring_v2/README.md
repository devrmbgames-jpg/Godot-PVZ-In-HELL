# Refactoring v2 — полный Core Architecture + Code Style рефакторинг

Status: **IN_PROGRESS**

Next task: `25_persistence_remaining.md`

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

1. [Architecture coherence audit](00_01_architecture_coherence_audit.md)
2. [Usability и content-authoring audit](00_02_usability_authoring_audit.md)
3. [Simplification / overengineering / reference audit](00_03_simplification_reference_audit.md)
4. [Migration / persistence / validation audit](00_04_migration_persistence_validation_audit.md)
5. [Preflight readiness gate](00_05_preflight_readiness_gate.md)

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

6. [Архитектурные роли и ownership](01_architecture_contract.md)
7. [Scheduled execution и Service boundaries](02_execution_ownership_rules.md)
8. [Architecture validation и service smells](03_architecture_validation.md)
9. [Identity, persistence и migration baseline](04_identity_persistence_contract.md)

Phase 2 начинается только после закрытия всех Phase 1 tasks.

### Phase 2A — Execution model cleanup

10. [Полный inventory сервисов](10_service_inventory.md)
11. [Typed Commands / Events](40_typed_commands_events.md)
12. [CustomerFlow: planning, arrival и day transitions](11_customer_flow_planning.md)
13. [CustomerFlow: активный lifecycle визита](12_customer_flow_runtime.md)
14. [Customer outcomes и settlement](13_customer_outcomes.md)
15. [District lifecycle и schedule](14_district_lifecycle.md)
16. [NPC brain, perception и traits](15_npc_brain.md)
17. [NPC route и service role](16_npc_route_service_role.md)
18. [Combat, attacks и projectiles](17_combat.md)
19. [Challenge lifecycle](18_challenges.md)
20. [Hunger и Quests](19_hunger_quests.md)
21. [Interaction input и action routing](20_interaction_input.md)
22. [Grab, Push, Carry и physical slots](21_grab_push_slots.md)
23. [Motion и physics boundaries](22_motion_physics.md)
24. [Hazards, receiving, loot и delivery runtime](23_hazards_receiving_loot.md)
25. [Economy, Inventory и Commerce](24_economy_inventory_commerce.md)
26. [Persistence и remaining services](25_persistence_remaining.md)
27. [Очистка execution graph](26_execution_graph_cleanup.md)
28. [Execution-model acceptance checkpoint](27_architecture_acceptance.md)

### Phase 2B — Contracts и vertical domains

Typed contracts уже закреплены задачей 40 перед execution migration. Здесь переносится завершённый execution model; dependency guardrail появляется до первого domain move.

29. [Domain layout contract + validator](28_domain_layout_contract.md)
30. [Domain dependency validation — transition gate](33_domain_dependency_validation.md)
31. [Domains: NPC и Customers](29_domain_npc_customers.md)
32. [Domains: Interaction, Combat и Motion](30_domain_interaction_combat_motion.md)
33. [Domains: world gameplay](31_domain_world_economy_packages.md)
34. [Shared core + удаление horizontal roots](32_domain_shared_core.md)

После 32 обязателен strict rerun dependency validator задачи 33 без migration baseline.

### Phase 2C — Core framework

35. [Unified Game Time + deterministic randomness — foundation](47_game_time_randomness.md)
36. [Entity Templates / Traits](41_entity_templates_traits.md)
37. [Visual Entity authoring](42_visual_entity_authoring.md)
38. [Smart Objects / Affordances / Reservations](43_smart_objects.md)
39. [Schedule / goal selection / LimboAI; GOAP deferred](44_ai_schedule_utility_goap.md)
40. [Simulation LOD](45_simulation_lod.md)
41. [Content Doctor](46_content_doctor.md)
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

Phase 1 **DONE**: задачи 01–03 завершены 2026-10-07, 04 — 2026-10-08. Canonical roles/service smells/request timing, architecture guardrail, full structure repair и isolated identity/persistence baseline завершены. Phase 1 acceptance gate достигнут; runtime migration не начиналась.

Повторный Phase 0 pass завершён 2026-10-07 строго последовательно, с отдельным coherent commit каждой 00_задачи. Final full review [00_05](00_05_preflight_readiness_gate.md): **READY_FOR_IMPLEMENTATION**. Этот исторический gate разрешил Phase 1; его preflight pass завершён до реализации 01.

Phase 2A начата 2026-10-08: [10 — service inventory](10_service_inventory.md) **DONE**, static coverage 136/136; [полная классификация и bounded slices](service_inventory_result.md). [40 — typed Commands / Events](40_typed_commands_events.md) **DONE**: пять boundary slices, bounded diagnostic provider, reentrancy/deferred fixtures, final GUT 55/55 и parser 39 files PASS. [11 — CustomerFlow planning](11_customer_flow_planning.md) **DONE**: discrete planning/day/registration owner, scheduled arrival owner, typed receipts и current-format cache rebuild; core GUT 70/70, final owner GUT 34/34, parser 28 files PASS. [12 — active Customer lifecycle](12_customer_flow_runtime.md) **DONE**: separate phase/clock/presence owners, preserved district BT cadence, removed nested Service ticks; GUT 113/113 + 83/83, parser 31 files and actual main-level headless inspection smoke PASS. [13 — customer outcomes](13_customer_outcomes.md) **DONE**: discrete outcome/calendar/closure reactions, single settlement gate and reactive challenge bridge; GUT 134/134 + 92/92, parser 20 files and actual headless inspection smoke PASS. [14 — District lifecycle](14_district_lifecycle.md) **DONE**: reactive calendar/death/goal/preparation owner, native typed completion receipts and gated night capture; GUT 152/152 + 17/17, parser 21 files and actual main-level headless write/restore smoke PASS. [15 — NPC brain](15_npc_brain.md) **DONE**: explicit cadence/footstep/perception/trait/native-decision/noise owners, no brain Service scheduler; GUT 230/230 + 42/42, BT validator and parser 21 files, final actual main headless native inspection smoke PASS. [16 — NPC route/service role](16_npc_route_service_role.md) **DONE**: route clocks and fair queue/budget Systems, retained UID for NpcRouteSolver, no native-decision scheduler chain; GUT 264/264 + 44/44, parser 16 files and actual main-level headless native inspection smoke PASS. [17 — Combat](17_combat.md) **DONE**: four real scheduled owners, removed combat Service clocks, transient generation guards and presentation UID move; GUT 101/101 + final 30/30, parser 18 files and actual main-level headless combat/Jolt smoke PASS. [18 — Challenges](18_challenges.md) **DONE**: lifecycle and floor damage clocks in Systems, reactive activation setup, typed committed fact and Geometry UID moves; GUT 72/72, parser 17 files, actual headless combat/floor support and main cleanup smoke PASS. [19 — Hunger/Quests](19_hunger_quests.md) **DONE**: explicit growth/deadline owners and pure HungerRules, authored issuer variants/provider, schema 3 reject/current-format quest reload with exactly-once Wallet reward; GUT 76/76 + final 42/42, parser 28 files and actual main-level/Jolt headless hunger/carry/perception/combat smoke PASS. [20 — Interaction input](20_interaction_input.md) **DONE**: captured input arbitration/prolonged clocks in S_InteractionInput, marker/decay ownership, retained-UID geometry/rules/solver moves and committed light/noise consumers; GUT 200/200, parser 52 files and actual main-level/Jolt input/hands/carry/modal/throw smoke PASS. [21 — Grab/Push/Slots](21_grab_push_slots.md) **DONE**: real generic/push/anchor/cargo owners, frame/binding lifetime guards, explicit transactions and native callback solvers; GUT 170/170 plus final extended surfaces/main fixture PASS, parser 25 + final 3 files and actual Jolt cart/main interaction headless smokes PASS. [22 — Motion/physics](22_motion_physics.md) **DONE**: common MotionRules, independently composed native callback contributions and documented per-field route/input/physics ownership; GUT 137/137 + corrected district 54/54, parser 12 + 1 files and Jolt cart/main hunger headless smokes PASS. [23 — Hazards/receiving/loot/delivery](23_hazards_receiving_loot.md) **DONE**: captured bounded retry owner, restore-safe receiving/order/hazard commits and current authored geometry fixtures; GUT 105/105 + 62/62, parser 17 files, hazards/truck and two-process loot/furniture smokes PASS. [24 — Economy/Inventory/Commerce](24_economy_inventory_commerce.md) **DONE**: sole Trader Profile authority, retained-UID Rules/UI factory moves, explicit ledger/Inventory transactions and safe queued death completion; GUT 96/96, parser 21 + final smoke file, trader write/restore and main Inventory headless smokes PASS. Далее [25 — Persistence/remaining services](25_persistence_remaining.md). Владелец разрешил полный dependency-order проход 2A → 2B → 2C с отдельным coherent commit каждой завершённой задачи и остановкой после PASS 49; Phase 3 не начинать. Правило одной задачи на запрос ниже не ограничивает этот явно расширенный scope. Rendered gameplay и subjective visual QA запрещены; headless/parser/validators/GUT/smoke/save-load разрешены.

Old-save migration исключена владельцем; changed formats versioned/rejected, current-format roundtrip обязателен. GOAP/body detach/четыре tiers deferred; baseline ACTIVE/DORMANT with retained physical-root Entity and ECS-owned population records. Population/district schedules belong to npc, without separate district domain. Known structure failures (31, smoke reference/R26 metadata) устранены в 03.

Ни Phase 1, ни runtime migration не начинать до `READY_FOR_IMPLEMENTATION` в [00.05 — preflight readiness gate](00_05_preflight_readiness_gate.md).

Execution guardrail: `python utils/validate_architecture.py`; fixtures: `python -m unittest discover -s tests/tools -p test_validate_architecture.py`. Symbol/occurrence migration baseline хранится в `utils/architecture_baseline.json`, сокращается при каждом owning migration и обнуляется в 26. Gate 27: `python utils/validate_architecture.py --strict`. Infrastructure diagnostics (31, smoke reference/R26 metadata) устранены в 03: full structure PASS.

Identity/persistence baseline: `python utils/validate_persistence_baseline.py`; fixtures: `python -m unittest discover -s tests/tools -p test_validate_persistence_baseline.py`. Engine fixture: headless GUT `-gtest=res://tests/gut/test_refactoring_v2_persistence_baseline.gd -gexit`. `docs/persistence.md` owns identity/version/path contracts; 25 removes path matching and versions incompatible changes before 28–32.

Domain structure guardrail уже подготовлен в transition mode:
`python utils/validate_domain_structure.py`.

После завершения vertical-domain migration обязательный gate:
`python utils/validate_domain_structure.py --strict`.

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

На один рабочий запрос брать одну выбранную небольшую задачу. Читать этот README, выбранную задачу и только прямых владельцев кода/контрактов. После завершения обновлять Status/Current/Validation задачи и следующее действие здесь.
