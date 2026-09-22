# ТЗ 08 — Framework опасных клиентов

## Цель

Создать data-driven framework специальных правил Customer.

Не помещать все monster behavior в один Customer System.

## Challenge Lifecycle

```text
Inactive
→ Armed
→ Active
→ Success / Failure
→ Cleanup
```

Challenge должен определять:

- trigger condition;
- rules;
- success condition;
- fail condition;
- optional timeout;
- escalation;
- cleanup;
- последствия.

## Challenge 1 — Light Off

Customer требует выключить свет.

После реплики:

- запускается ограниченное окно времени;
- Player должен физически использовать LightSwitch;
- success — нужная группа света выключена;
- fail — Satisfaction падает или запускается aggression/escalation.

## Challenge 2 — Light On

Та же система, обратное требование.

Это должна быть конфигурация общей механики, а не полностью отдельная логика.

## Challenge 3 — Don't Look

Player не должен смотреть на Customer слишком долго.

Система измеряет непрерывное время внимания.

При приближении к fail:

- усиливаются визуальные искажения;
- Customer меняет поведение.

При полном fail:

- aggression;
- damage;
- иной horror consequence.

## Challenge 4 — Keep Looking

Player не должен отводить взгляд слишком долго.

Использует ту же базовую систему gaze tracking с обратным условием.

## Challenge 5 — Floor Hazard

Customer запускает опасную поверхность/лаву.

Игрок должен решать ситуацию физически:

- коробками;
- стульями;
- мебелью;
- безопасными участками.

Не использовать отдельный QTE.

## Будущие типы

Архитектура должна позволять добавить:

- don't move;
- silence;
- riddles;
- hide;
- feed customer;
- close/open window;
- lock/unlock door через access/door contract ТЗ 08.1;
- sacrifice specific Package;
- place object at target через PlacementArea/physical placement contract ТЗ 08.1.

## Критерий готовности

Минимум три разных Customer используют общий challenge lifecycle и отличаются данными/условиями, а не копией всей customer logic.
