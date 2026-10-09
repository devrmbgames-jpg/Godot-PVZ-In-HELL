# Refactoring v2 — полный Core Architecture + Code Style рефакторинг

Status: **IN_PROGRESS**

Next task: `41_entity_templates_traits.md`

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

Phase 2A начата 2026-10-08: [10 — service inventory](10_service_inventory.md) **DONE**, static coverage 136/136; [полная классификация и bounded slices](service_inventory_result.md). [40 — typed Commands / Events](40_typed_commands_events.md) **DONE**: пять boundary slices, bounded diagnostic provider, reentrancy/deferred fixtures, final GUT 55/55 и parser 39 files PASS. [11 — CustomerFlow planning](11_customer_flow_planning.md) **DONE**: discrete planning/day/registration owner, scheduled arrival owner, typed receipts и current-format cache rebuild; core GUT 70/70, final owner GUT 34/34, parser 28 files PASS. [12 — active Customer lifecycle](12_customer_flow_runtime.md) **DONE**: separate phase/clock/presence owners, preserved district BT cadence, removed nested Service ticks; GUT 113/113 + 83/83, parser 31 files and actual main-level headless inspection smoke PASS. [13 — customer outcomes](13_customer_outcomes.md) **DONE**: discrete outcome/calendar/closure reactions, single settlement gate and reactive challenge bridge; GUT 134/134 + 92/92, parser 20 files and actual headless inspection smoke PASS. [14 — District lifecycle](14_district_lifecycle.md) **DONE**: reactive calendar/death/goal/preparation owner, native typed completion receipts and gated night capture; GUT 152/152 + 17/17, parser 21 files and actual main-level headless write/restore smoke PASS. [15 — NPC brain](15_npc_brain.md) **DONE**: explicit cadence/footstep/perception/trait/native-decision/noise owners, no brain Service scheduler; GUT 230/230 + 42/42, BT validator and parser 21 files, final actual main headless native inspection smoke PASS. [16 — NPC route/service role](16_npc_route_service_role.md) **DONE**: route clocks and fair queue/budget Systems, retained UID for NpcRouteSolver, no native-decision scheduler chain; GUT 264/264 + 44/44, parser 16 files and actual main-level headless native inspection smoke PASS. [17 — Combat](17_combat.md) **DONE**: four real scheduled owners, removed combat Service clocks, transient generation guards and presentation UID move; GUT 101/101 + final 30/30, parser 18 files and actual main-level headless combat/Jolt smoke PASS. [18 — Challenges](18_challenges.md) **DONE**: lifecycle and floor damage clocks in Systems, reactive activation setup, typed committed fact and Geometry UID moves; GUT 72/72, parser 17 files, actual headless combat/floor support and main cleanup smoke PASS. [19 — Hunger/Quests](19_hunger_quests.md) **DONE**: explicit growth/deadline owners and pure HungerRules, authored issuer variants/provider, schema 3 reject/current-format quest reload with exactly-once Wallet reward; GUT 76/76 + final 42/42, parser 28 files and actual main-level/Jolt headless hunger/carry/perception/combat smoke PASS. [20 — Interaction input](20_interaction_input.md) **DONE**: captured input arbitration/prolonged clocks in S_InteractionInput, marker/decay ownership, retained-UID geometry/rules/solver moves and committed light/noise consumers; GUT 200/200, parser 52 files and actual main-level/Jolt input/hands/carry/modal/throw smoke PASS. [21 — Grab/Push/Slots](21_grab_push_slots.md) **DONE**: real generic/push/anchor/cargo owners, frame/binding lifetime guards, explicit transactions and native callback solvers; GUT 170/170 plus final extended surfaces/main fixture PASS, parser 25 + final 3 files and actual Jolt cart/main interaction headless smokes PASS. [22 — Motion/physics](22_motion_physics.md) **DONE**: common MotionRules, independently composed native callback contributions and documented per-field route/input/physics ownership; GUT 137/137 + corrected district 54/54, parser 12 + 1 files and Jolt cart/main hunger headless smokes PASS. [23 — Hazards/receiving/loot/delivery](23_hazards_receiving_loot.md) **DONE**: captured bounded retry owner, restore-safe receiving/order/hazard commits and current authored geometry fixtures; GUT 105/105 + 62/62, parser 17 files, hazards/truck and two-process loot/furniture smokes PASS. [24 — Economy/Inventory/Commerce](24_economy_inventory_commerce.md) **DONE**: sole Trader Profile authority, retained-UID Rules/UI factory moves, explicit ledger/Inventory transactions and safe queued death completion; GUT 96/96, parser 21 + final smoke file, trader write/restore and main Inventory headless smokes PASS. [25 — Persistence/remaining services](25_persistence_remaining.md) **DONE**: explicit placed IDs/schema 4, prepare-once immutable Night retry/protected rejected slot, passive startup/recipe/link fixup and Component-owned schema contracts; inventory 136/136 final, GUT 54/54 + 82/82 + 111/111 + 20/20, parser 73 files, empty architecture baseline and actual two-process Night/loot smokes PASS. [26 — Execution graph cleanup](26_execution_graph_cleanup.md) **DONE**: WeakRef queued owners/exact Component and Relationship checks, retained terminal actor attribution and strict lifetime/System-call guard; GUT 80/80 + 125/125 + 112/112, parser 69 files, validators and hazards smoke PASS. [27 — execution-model checkpoint](27_architecture_acceptance.md) **DONE — PASS**: current connected manifest/Customer/Wallet/Inventory/damage/Night/fresh-startup smoke, native retained-disabled structural tracking, GUT 74/74 + 37/37, final parser 3 files, strict validators and two-process Night smoke PASS. [28 — vertical-domain layout](28_domain_layout_contract.md) **DONE — PASS**: approved 14 owners, full 1540-entry file/UID/asset map (1421 moves/751 native UIDs), explicit 719 public access edges/26 forbidden legacy decompositions, 13/13 validator fixtures and transition structure/preflight PASS. [33 — dependency enforcement](33_domain_dependency_validation.md) **DONE — PASS**: path/class-name/public-operation rights, bounded actual implementation graph, exact expiring frozen legacy baseline (88 edges/cycle cuts), 18/18 dependency fixtures (31/31 combined domain fixtures), transition structure/preflight PASS; enforcement active **до** moves. [29 — NPC/Customers](29_domain_npc_customers.md) **DONE — PASS**: 506 complete owner/UID/assets/context moves; all 68 task exemptions removed, native hierarchy/trees/lifecycle/facts and global dialogue composition decomposed without wrappers. Schema 5/native golden and closed guards updated; final parser 389 files, GUT 705/705 (5742 assertions), native save baseline 3/3, 9 trees/124 leaves, validators and actual main write/fresh restore smoke PASS. [30 — Interaction/Combat/Motion](30_domain_interaction_combat_motion.md) **DONE — PASS**: 486 owner/UID/asset moves, seven exact cycles removed through query/cache/release ownership; schema 6/native golden, final parser 334 files and negative syntax gate, GUT 259/259 (1934 assertions), validators and actual main write/fresh restore PASS. [31 — world gameplay domains](31_domain_world_economy_packages.md) **DONE — PASS**: 489 complete owner/UID/asset moves, nine dependency cuts removed; native UI/Night/receiving composition, schema 7/current golden and closed path guards updated. Cold-load access/slot cycle removed through pure ItemAccessRules. Final parser 275 files, GUT 485/485 (4173 assertions), validators and actual main/hazards/loot write/fresh-restore gates PASS. [32 — Shared core/root removal](32_domain_shared_core.md) **DONE — PASS**: 46 complete map entries, all 16 horizontal roots absent, shared identity projections without duplicate state, original dialogue import UIDs preserved, no migration exemptions/decomposition ledger. Schema 8/native golden, continuous strict structure/dependency, 33/33 validator fixtures, final parser 31 + 3 files/negative gates, GUT 614/614 (5330 assertions), actual main write/fresh restore and hazards PASS. **Phase 2B complete.** Владелец разрешил полный dependency-order проход 2A → 2B → 2C с отдельным coherent commit каждой завершённой задачи и остановкой после PASS 49; Phase 3 не начинать. Правило одной задачи на запрос ниже не ограничивает этот явно расширенный scope. Rendered gameplay и subjective visual QA запрещены; headless/parser/validators/GUT/smoke/save-load разрешены.

Phase 2C: [47 — Game Time/randomness foundation](47_game_time_randomness.md) **DONE — PASS**: isolated ECS-owned microsecond clock/remainder/world seed, player-driven calendar, persisted NPC cadence, canonical UTF-8/SHA-256 decision keys and pinned Godot RNG golden outputs; every existing gameplay random consumer migrated. Schema 9/current native Variant baseline, quantized gameplay groups and independent operational Storage retries. Final parser **72 files**, GUT **731/731** (**6549 assertions**), strict validators/33+5 tooling fixtures, actual main vertical slice, two-process Night clock/seed restore and native customer inspection **PASS with zero errors/warnings**. Query caches release at World exit. **41 — Entity Templates / Traits IN_PROGRESS**: common pure compiler, scene-owned authoring, whole-placed provider/identity/endpoint validation and registration-once are active. Production package Template/ET_PackageState is attached; old condition observer/service and contents installer removed. Fresh restore compilation/saved overlays precede live mutation/native publication. Package activation all-script native GUT **96 scripts / 1346/1346 executed tests / 11086 assertions PASS**, parser **8 files** and strict validators PASS. Latest enumerated factory fields GUT **116/116 / 984 assertions PASS**; shipment fields precede publication, undeclared/conflicting/wrong-type inputs reject. Current main and two-process Night/loot smoke PASS with zero diagnostics. Cold parsing of ReceivingDeliveryService compiles but retains resources at shutdown; exact-owner HEAD comparison reproduces it, no exemption adopted (details in 41). Address factory now validates a detached whole batch and publishes complete instance IDs; parser **3 files**, district/address GUT **104/104 / 1002 assertions** and latest actual main/Night write/restore PASS. Manifest **8/72 resolved**; NPC fresh/saved roster, placed merchant identity/Profile and fresh body reconstruction now compile before native publication; parser **10 files**, coupled district/BT/save GUT **140/140 / 1369 assertions** and latest actual main/Night PASS with zero diagnostics. NPC identity batch all-script GUT **98 scripts / 1359/1359 / 11169 assertions PASS**. Brain/immunity/combat defaults now compile in ET_NpcBrainState; old installers and cadence repair removed, retained transient reset rejects old queued AI generations. Latest parser **15 files**, GUT **126/126 / 1208 assertions** and actual main/Night PASS with zero diagnostics. NPC inventory/hunger/actions/merchant defaults now compile in ET_NpcRoles; explicit flat placed-Trader variant preserves scene providers and old role installer is removed. Role-first GUT **125/125 / 1276 assertions**, owner parser **5 files** and main/Night PASS with zero diagnostics. Reverse fixture order and cold inherited snapshot parser reproduce shutdown retention, unresolved final gate (details in 41). Whole population transaction, customer/remaining providers and complete ready barrier remain pending. Next: complete **41**, then 42→43→44→45→46→48→49; stop only after PASS 49 or an authorized exceptional gate, never start Phase 3.

Old-save migration исключена владельцем; changed formats versioned/rejected, current-format roundtrip обязателен. GOAP/body detach/четыре tiers deferred; baseline ACTIVE/DORMANT with retained physical-root Entity and ECS-owned population records. Population/district schedules belong to npc, without separate district domain. Known structure failures (31, smoke reference/R26 metadata) устранены в 03.

Ни Phase 1, ни runtime migration не начинать до `READY_FOR_IMPLEMENTATION` в [00.05 — preflight readiness gate](00_05_preflight_readiness_gate.md).

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

На один рабочий запрос брать одну выбранную небольшую задачу. Читать этот README, выбранную задачу и только прямых владельцев кода/контрактов. После завершения обновлять Status/Current/Validation задачи и следующее действие здесь.

Physical-slot initial binding milestone: on_ready installer removed; shared ancestor endpoint capture and validated flat Template/fixup. Current task-41 worktree GUT 94/94 / 662 assertions, parser 6+1 files and main/placement/inspection/Night write+restore PASS. Task 41 remains IN_PROGRESS; no Phase 3.


Additional task-41 initial provider: package carry Profile defaults now compile through
ET_PackageState; receiving factory no longer rewrites carry recipes. Native parser 3 files and
GUT 71/71 PASS; actual truck write/restore PASS. Runner restart registration fixed in e15b66ae.
This milestone does not close task 41; readiness, complete manifest and cold retention remain open.


Task-41 global startup readiness milestone: all native/late Observers suspend until ready;
first System tick waits, membership reconstructs silently and structural NPC participation matches
saved/default placement. Morning work stays in its scheduled owner and dispatches after ready.
Final native GUT 35/35 / 356 and parser PASS; actual main/Night restart PASS. Per-Entity ready,
remaining manifest and cold retention remain required; task 41 stays IN_PROGRESS.

Task 41 placed saved-state milestone: saved fields, opaque Entity IDs and physical pose now precede
pinned native initialization; incompatible saved physical owners reject before registration. Native
parser 4 files PASS, focused GUT 34/34 PASS (394 assertions), actual Night two-process write/restore
PASS, strict/static contracts and local Formatter PASS. Task 41 remains IN_PROGRESS; endpoint/
per-Entity readiness and full provider migration acceptance remain open. Phase 42/3 not started.

Task 41 ready milestone: runtime factory Observer callbacks wait for complete initial bindings and
preserve native initial event counts; placed/restore completion publishes per-Entity readiness.
Fresh restored body pose now precedes native registration. Parser 7 files PASS; focused GUT 58/58
(679 assertions) and lifecycle GUT 19/19 (133 assertions) PASS; actual vertical slice and two-process
Night write/restore PASS, strict/static contracts and local Formatter PASS. Task 41 remains open
for complete manifest migration/audit and acceptance. No Phase 42 or Phase 3 started.

Task 41 receiving_scan acceptance tooling migrated to current actual main contracts: 5-box supply,
arrival receipts, CharacterBody player, real unload/shift/sleep/next-truck block/resume, scanner
reacquisition after Night reset and stable number reuse. Headless receiving_scan PASS with clean
runtime log; parser, local Formatter and structure PASS. Previously recorded legacy receiving_scan
failure is resolved. Task 41 remains IN_PROGRESS for the full provider audit and acceptance.

Session capability milestone (task 41 remains IN_PROGRESS):
- Shared boundary_trace and package session_loot_queue Traits compile fresh mutable Components
  before native publication in actual main and primitive levels. MainLevel asserts its required
  diagnostic recipe; LootDropService.current reads its required queue without a lazy installer.
- Native GUT 34/34 PASS / 393 assertions proves actual-level prepublication, withheld readiness,
  repeated reads without component events and isolation of trace history and queue runtime state.
  Parser 2 changed scripts PASS. Logs: tests/artifacts/refactoring_v2_41_bootstrap_trace_gut.log
  and tests/artifacts/refactoring_v2_41_bootstrap_trace_parser.log.
- Actual vertical_slice PASS (vertical_slice-20261009-173207325.log); Night write/restore PASS in
  two new processes (night_persistence-write-20261009-173218495.log /
  night_persistence-restore-20261009-173227628.log). Native gates have zero warnings/errors.
- Local .bin/gdscript-formatter.exe is available: actual incremental formatter/lint PASS for
  40 changed GDScript files, no NOT_RUN. Project/domain/map/strict dependencies/architecture,
  persistence baseline and refactoring preflight PASS.
Provider manifest now 16/72 resolved in the ongoing worktree. Complete provider migration/audit
plus remaining native shutdown acceptance failures still require work; 42 and Phase 3 not started.

Physical/package/customer capability milestone (task 41 remains IN_PROGRESS):
- Physical impact inboxes now come from one immutable Trait in authored flat Templates;
  S_Impact binds native reporting to required existing data. Duplicate receiver/inbox providers
  are removed while retained authored Profiles remain the tuning owner.
- Eight package-content variants compile fresh impact/hazard data from scene exports before
  publication; the old Entity define_components provider is removed. Loot preflight rejects
  incomplete recipes before committing the source manifest.
- Standalone customers and district role action sets use authored immutable action Definitions.
  CustomerActionRecipe and its late installers are deleted; entering a transient resident visit
  preserves the compiled action aggregate. Failed customer builds leave visit/history untouched.
- Native production/helper parser 11 files PASS; actual content/registration/loot GUT 53/53 PASS
  / 669 assertions and NPC/customer role GUT 78/78 PASS / 517 assertions, with zero native diagnostics.
  Logs: tests/artifacts/refactoring_v2_41_capability_owners_parser.log,
  ...capability_content_gut.log and ...capability_roles_gut.log. Actual main/Night restart smoke
  for this unchanged implementation batch already PASS in the preceding session milestone.
- Local Formatter PASS for 38 changed GDScript files; project/map/strict dependency/architecture
  and staged agent checks PASS. Native user UID/serialization edits remain unstaged and preserved.
This commits the four previously pending manifest resolutions: committed coverage is now 16/72.
Task-level cold parser/golden shutdown failures remain open: exact cold remains round-trip plus
its setup reproduces retention, while GUT base, individual dependencies and other test functions
compile cleanly. No warning exemption, addon edit or load-order workaround added. Complete provider
audit, address persistence batch and full acceptance are still required before task 42.

Stable address persistence milestone (task 41 remains IN_PROGRESS):
- Schema 10 serializes only C_NpcAddress.address_id and rejects empty, duplicate, unknown or
  non-home keys before live mutation. Detached restoration compiles the saved key and rebuilds
  its authored label before native publication; the population factory shares these operations.
- Current native snapshot/codec inventory and durable persistence documentation are updated.
  Unsupported old versions remain protected; no old-save migration is implemented.
- Actual production parser 7 files PASS, log
  tests/artifacts/refactoring_v2_41_address_owners_parser.log. District/snapshot/codec/golden GUT
  has 49/49 functional tests / 777 assertions, but OVERALL FAIL: native shutdown reports 683
  ObjectDB / 508 resources, Jolt/render/font RIDs and allocator pages. Log
  tests/artifacts/refactoring_v2_41_address_persistence_gut.log. This is not an acceptance PASS.
- Cold failure is localized to the remains save/load function combined with setup. Minimal GUT
  base, direct owners, each direct global class, individual setup constructors, other test functions
  and the snapshot call alone compile cleanly. Uncached fixture loading and codec static_unload
  do not fix it. Transient codec schema lookup reduces retention but still FAILs (359/249).
  All temporary owner edits were reverted to exact pre-trial bytes; no production workaround added.
Remaining: complete provider audit and native shutdown acceptance fixes. Task 41 and the goal
through PASS49 remain active; task 42/Phase 3 and rendered gameplay/visual QA have not started.

Initial NPC route capability milestone (task 41 remains IN_PROGRESS):
- Provider audit found S_NpcRoute._progress_route incorrectly classified as a runtime transition:
  it installed C_NpcRoute on the first scheduled tick. The existing NPC brain Trait now provides
  a fresh route before native publication; scheduled progression only uses required existing data.
- District brain reset previously removed the route. It now clears derived paths/map/clock fields
  on the same Component, retaining the construction contract through participation and restore.
  Native brain binding requires it. Queued-route fixture checks post-departure state and identity.
- Native changed parser 7 files PASS; GUT 123/123 / 777 assertions PASS across identity/publication,
  scheduling, actual native route budgets and district planning. New fixtures prove private route
  buffers and reset without Component-added/removed events. Logs:
  tests/artifacts/refactoring_v2_41_route_final_parser.log / ...route_final_gut.log.
- Actual vertical_slice PASS (vertical_slice-20261009-183213885.log); Night write/restore in two
  new processes PASS (night_persistence-write-20261009-183225053.log /
  night_persistence-restore-20261009-183234225.log). All final native gates have zero diagnostics.
- Local Formatter 7 files PASS and strict dependencies PASS. Manifest is now 17/72 resolved.
Full factory/runtime provider closure and native cold/golden shutdown failures remain required
for task-41 acceptance; task 42 and Phase 3 have not started.


Task 41 physical-stack rejection audit (2026-10-09): wrong prefab root/body, missing stack recipe
and missing resource now free all detached instances and preserve owned inventory/pending orders.
Native publication receives complete death-drop data before source removal. Final parser **4 files**,
local Formatter **4 files**, GUT **28/28 / 488 assertions**, inventory and independent furniture
arrival write/restore headless smokes PASS with zero diagnostics. Manifest **20/72** closed;
41 remains IN_PROGRESS with full provider/cold-shutdown acceptance pending. Next remains 41,
then 42→43→44→45→46→48→49; no Phase 3.


Task 41 saved marker milestone (2026-10-09): death/ink/anchor/completed NEVER progress now overlay
compiled private recipes before native registration/on_ready; fresh restore retains marker identity
and applies physical anchor freeze before publication. Final parser **4 files**, Formatter **4 files**,
native GUT **81/81 / 795 assertions** and independent Night write/restore PASS, zero diagnostics.
Saved-state/bootstrap/authoring provider audit closes four more rows; manifest **24/72**. Full
remaining-provider/cold-shutdown acceptance is pending, so 41 remains IN_PROGRESS; no Phase 3.
