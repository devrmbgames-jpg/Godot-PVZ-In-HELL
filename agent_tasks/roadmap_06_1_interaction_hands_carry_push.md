# R06.1 — Inspector-first компоненты, Carry/две руки и Push

Status: in progress
Зависимости: R02, R06
Ветка/base: master / ff2db865612e43c69742ca61bd91eb980e148342.
Источники: [RM06.1](../docs/roadmap/06_1_interaction_hands_carry_push.md), [ТЗ 02](../docs/roadmap/02_core_interaction_and_physics.md), [ТЗ 05](../docs/roadmap/05_scanner_terminal_marker.md), [контракт Grab](../docs/physical_grab.md).

## Цель

Перед R07 стабилизировать authoring и физическое взаимодействие: перенести сериализуемые Components в scene `component_resources`, сделать независимые `CARRY/LEFT_HAND/RIGHT_HAND` slots, state-aware E/F/G/LMB/RMB controls, per-item rotation policy и отдельный Push contract для тележек.

## Начать здесь

- [content/systems/interaction/s_grab.gd](../content/systems/interaction/s_grab.gd)
- [content/components/interaction/c_grabbable.gd](../content/components/interaction/c_grabbable.gd)
- [content/components/interaction/c_held_by.gd](../content/components/interaction/c_held_by.gd)
- [content/components/interaction/c_grab_control.gd](../content/components/interaction/c_grab_control.gd)
- [content/systems/interaction/interaction_actions.gd](../content/systems/interaction/interaction_actions.gd)
- [content/systems/input/s_player_input.gd](../content/systems/input/s_player_input.gd)
- [content/entities/e_rigid_body_character.tscn](../content/entities/e_rigid_body_character.tscn)
- [content/entities/props/scanner.tscn](../content/entities/props/scanner.tscn)

Сначала сверить текущий HEAD: RM06.1 добавлена после незавершенной переделки hand slots, поэтому не считать существующий `RIGHT_HAND` contract завершенным.

## Работы

- [ ] Проаудировать project-owned `define_components()`; сериализуемые/static Components и Actions перенести в scene `component_resources`. Оставить в коде только обоснованные runtime-specific данные и не дублировать Component двумя способами.
- [ ] Переделать ownership на три независимых runtime-slots: `CARRY`, `RIGHT_HAND`, `LEFT_HAND`. Relation хранит slot; holder cache раздельный и остается derived.
- [ ] Заменить жесткий hand slot предмета на allowed hand slots + runtime selection. Anchor/rotation/cleanup/release/throw должны использовать slot relation.
- [ ] Сохранить exclusive ownership объекта, но разрешить holder одновременно владеть Carry + Left + Right. Hand-items не блокируют pickup Carry и не занимают его capacity; заполненный Carry при этом временно suspend'ит hand control, не освобождая hand ownership.
- [ ] Ввести единый control-capture/focus contract для Carry, Push, Terminal/UI и будущих modal interactions. Пока capture активен, LEFT/RIGHT hand-items остаются в slots, anchors переводятся в lowered position за/ниже камеры, а конфликтующие hand-use/throw/rotation inputs не проходят на более низкий приоритет.
- [ ] Восстанавливать руки только после завершения последнего active control capture; вернуть обычные authored hand anchors и input mapping без повторного pickup/equip.
- [ ] Не реализовывать control capture как набор несогласованных boolean-флагов. Должен быть единый источник истины или эквивалентная модель, корректная при вложенных/перекрывающихся Carry/Push/UI состояниях.
- [ ] Реализовать state-aware E/F hand pickup/replacement и атомарную prevalidation замены согласно RM06.1.
- [ ] LMB/RMB направить в use-action правой/левой руки только когда hands active; Alt + LMB/RMB — throw соответствующей mapped hand при том же условии. Добавить `swap_hand_controls` и единый prompt mapping.
- [ ] Добавить `G`: short-drop одного объекта в порядке Carry → Left → Right; long-press suppresses drop и вызывает placeholder будущего context wheel.
- [ ] Добавить per-item rotation settings: enable/disable, axis constraint минимум FREE/Y_ONLY и reset rotation on pickup. Rotation не должен конкурировать с hand-use input.
- [ ] Реализовать Push как отдельный contract, не `C_Grabbable`: data-driven fixed push/turn speeds, только перед игроком, без pulling и без transform teleport.
- [ ] Мигрировать Scanner и другие затронутые props/scenes на новый authoring/slot contract; не менять authored ArmRSlot/ArmLSlot transforms без необходимости.
- [ ] Обновить `docs/controls.md`, `docs/physical_grab.md`, `content/CONTEXT.md` и `PROJECT_INDEX.md` только по реально реализованным контрактам.

## Критерии готовности

- Inspector показывает статические Components scene-authored Entity без поиска `define_components()`.
- Carry + две руки независимы по ownership; один holder может одновременно владеть тремя объектами по одному на slot.
- Carry/Push/Terminal control capture визуально опускает обе руки и блокирует конфликтующий hand input, но не освобождает LEFT/RIGHT slots; после последнего release руки восстанавливаются автоматически.
- E/F replacement, LMB/RMB use, Alt throws, swap-hand option и G priority совпадают с RM06.1.
- Rotation policies работают для Scanner/pistol-like, Y-only container и reset-on-pickup.
- Pushable cart имеет отдельный lifecycle и предсказуемые фиксированные скорости, сохраняя физические столкновения.
- Existing grab lifecycle/LOS/throw/collision cleanup не регрессируют.

## Проверки

Расширять прежде всего существующие `tests/gut/test_s_grab.gd` и существующие smoke checks; новые GUT suites не добавлять без отдельного разрешения пользователя. Проверить slot capacity/cleanup, replacement failure, input priority, nested/overlapping control capture, lowered-hand restore, отсутствие hand-use во время Carry/Push/Terminal, swap mapping, drop priority/long-press, rotation constraints/reset и физический Push. Обязательны formatter/static checks и `git diff --check`; запуск Godot — только согласно актуальным инструкциям пользователя/окружения.

## Границы

Без radial menu, полноценного оружия, Inventory и vehicle framework. Не менять `addons/`. Не хранить Node authority внутри Components, если ту же связь можно выразить Entity field/NodePath/relationship.

## Первый шаг

Прочитать RM06.1 и текущие Grab/Input/Interaction contracts, затем зафиксировать в WORK.md точную миграцию данных: какие существующие `define_components()` полностью уходят в scene, а какие runtime-поля остаются исключением. После этого менять slot data model до UI/input.
