# R11.1 — Расширенные взаимодействия, физические слоты и расстановка

Status: planned
Зависимости: R02, RM06.1
Ветка/base: зафиксировать при начале реализации.
Источники: [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [RM06.1](../docs/roadmap/06_1_interaction_hands_carry_push.md), [ТЗ 08.1](../docs/roadmap/08_1_arrangement_extended_interactions.md), [ТЗ 12](../docs/roadmap/12_inventory_and_consumables.md), [ТЗ 13](../docs/roadmap/13_environment_interactables.md).

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
- Hammer — инструмент поверх общего hand/action contract RM06.1, не специальный input subsystem.
- Addons/GECS остаются read-only.

## Первый шаг

Проверить завершение R02/RM06.1 по `task_history.md`, затем зафиксировать data model prolonged interaction + physical slot/placement ownership в WORK.md/CURRENT_WORK.md и реализовать только первый маленький milestone.
