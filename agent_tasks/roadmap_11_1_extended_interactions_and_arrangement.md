# R11.1 — Расширенные взаимодействия, физические слоты и расстановка

Status: **IN_PROGRESS**

## Task state

### Goal
Add reusable prolonged interaction, access/open-close, physical slot/placement, and anchoring contracts that later environment/inventory tasks can reuse without ad-hoc systems.

### Constraints / acceptance
- Reuse R02/R06.1 interaction/control boundaries and the existing GECS ownership model.
- Relationships remain authority for live actor/source/target/session bindings.
- Physics placement/anchoring must preserve Godot body authority.
- This root file owns R11.1 status/current/next step; milestone files own only their bounded implementation evidence.

### Milestones
- [x] M1 — prolonged timing/progress/session foundation.
- [x] M2 — runtime resolver/input/focus/HUD integration and atomic completion/cleanup.
- [x] M3 — access requirements and common open/close/translate contract.
- [ ] M4 — physical slots and collision-validated Carry placement.
- [ ] M5 — hammer anchor/unfix, physics-state restore, support query, final validation.

### Decisions
One authoritative prolonged session per actor/target; progress readiness is not effect completion. Existing task body/design sources remain scope reference, not a parallel state tracker.

M4 clarification: user explicitly permits freezing/turning off physics for stored clothing/shelf items. Slots suspend simulation and collisions and attach the visible Entity to an authored anchor; removal restores its prior settings. Placement remains a one-time, collision-validated alignment with no storage ownership/freeze.

### Current
M1–M3 are implemented. M4 implementation is in progress: relationship-owned frozen slots, hand transfers, worn item access and swept Carry placement. Next: focused regression/physics validation and lifecycle review.

### Validation
User authorized selective GUT/smoke execution on 2026-09-29; avoid repeated/broad checks and request owner gameplay QA for complex or ambiguous scenarios. M1–M2 GUT: 18/18 passed. M3 GUT: 9/9 passed after correcting a fixture to read the live GECS component. Structure validation passed; optional formatter unavailable. Final physics integration checks remain for M4–M5.

### Owner QA / blockers
No blocker recorded. Owner visual/gameplay QA remains after runtime integration is complete.

---

Зависимости: R02, R06.1
Branch/base: master / 2d07761.
Источники: [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [R06.1](../docs/roadmap/06_1_interaction_hands_carry_push.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 13](../docs/roadmap/13_environment_interactables.md).

## Цель

Добавить reusable interaction-механику, которую затем используют окружение, мебель, physical storage и инструменты, не создавая отдельные ad-hoc системы под каждый объект.

Эта задача реализует generic contracts ТЗ 08.1. R13 должен применять их к Door/Window/Drawer/Light, а R19 — сохранять границу между физическими слотами и виртуальным stack Inventory.

## Начать здесь

- [interaction_action_resolver.gd](../content/services/interaction/interaction_action_resolver.gd)
- [def_interaction_action.gd](../content/definitions/interaction/def_interaction_action.gd)
- [s_interaction_targeting.gd](../content/systems/interaction/s_interaction_targeting.gd)
- [s_grab.gd](../content/systems/interaction/s_grab.gd)
- [e_grabbable_body.gd](../content/entities/props/e_grabbable_body.gd)

Затем читать только [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md) и прямые contracts, которые реально нужны выбранному milestone.

## Работы

- [ ] Добавить общий prolonged-interaction contract с progress, default duration 1.5 s и data-driven reset policy: DECAY / INSTANT / ON_COMPLETE / NEVER.
- [ ] Progress является gameplay state; HUD только отображает его. Прерывание target/control capture/недоступность объекта завершаются по выбранной reset policy без softlock.
- [ ] Добавить generic access requirement для interactable: required item ID/tag и явный результат allowed/denied. Не встраивать Inventory implementation в Door.
- [ ] Реализовать reusable open/close/translate state contract, достаточный для дверей и выдвижных элементов; физическое применение конкретных Door/Drawer остаётся R13.
- [ ] Добавить physical storage/body slots для конкретных Entity. Они отдельны от LEFT_HAND/RIGHT_HAND/CARRY и отдельны от будущего virtual stack Inventory R19.
- [ ] Добавить authored PlacementSlot/PlacementArea assist для аккуратной установки Carry-объекта. Placement не становится ownership authority и не телепортирует объект сквозь препятствия.
- [ ] Добавить data-driven возможность зафиксировать физический предмет/мебель в мире Hammer interaction: LMB фиксирует валидный неподвижный target; prolonged F с Hammer снимает фиксацию.
- [ ] Перед фиксацией требовать устойчивое/достаточно неподвижное физическое состояние; не фиксировать объект во время активного grab/push/control capture.
- [ ] При снятии фиксации проверить непосредственную поддержку/соседство одним коротким physics query (~0.05 m по фактическому направлению опоры), чтобы не оставлять очевидно зависимые объекты в некорректном состоянии.
- [ ] Сохранять исходные freeze/grab/physics параметры, нужные для обратимого unfix; не использовать набор несвязанных boolean flags.
- [ ] Поддержать свободную расстановку мебели/предметов без превращения PlacementArea в обязательную сетку.

## Критерии готовности

- Prolonged action показывает корректный progress и предсказуемо reset/decay по definition.
- Generic access requirement можно применить к Door в R13 без нового interaction framework.
- Physical slot хранит конкретный world Entity и не превращается в stack/quantity.
- Carry-object можно аккуратно поместить в authored placement area, сохранив physics/ownership authority.
- Hammer фиксирует только валидный неподвижный объект; prolonged unfix возвращает исходные физические/interaction свойства.
- Освобождение control focus/удаление target/смена сцены не оставляет interaction progress или object lock в подвешенном состоянии.

## Проверки

GUT: progress/reset policies, access predicate, physical slot ownership, placement validation, fix/unfix state restoration.

Physics integration: placement collision validity, неподвижность перед fix, support-neighbor query при unfix.

Использовать существующий interaction/grab regression surface; не создавать параллельный framework.

## Границы

- Без полноценного key/inventory UI: R19 реализует virtual Inventory/stack/consumable ownership.
- Без конкретного полного набора Door/Window/Drawer implementations: R13 применяет эти contracts.
- Без save/load реализации: R21 сохраняет уже существующее persistent world state.
- PlacementSlot помогает позиционированию, но не становится новым владельцем Entity.
- Hammer — инструмент поверх общего hand/action contract R06.1, не специальный input subsystem.
- Addons/GECS остаются read-only.

## Первый шаг

Проверить завершение R02/R06.1 по `task_history.md`, затем зафиксировать data model prolonged interaction + physical slot/placement ownership в WORK.md/CURRENT_WORK.md и реализовать только первый маленький milestone.

## Текущий этап

M1–M3 выполнены: prolonged foundation/runtime, access predicates и общий openable contract. Подробности: [M1](r11_1/milestone_1_prolonged_foundation.md), [M2](r11_1/milestone_2_prolonged_runtime.md), [M3](r11_1/milestone_3_access_openable.md). Следующий этап — M4. R11.1 остаётся открытой; physics integration и owner QA ещё впереди.
