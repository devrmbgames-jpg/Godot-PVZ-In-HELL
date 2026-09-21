# ТЗ 11 — Голод

## Цель

Создать базовый Hunger и заготовку под будущую монструозную сторону Player.

## Hunger State

Для прототипа достаточно tiers:

```text
Normal
Hungry
Starving
```

Числовой Hunger постепенно растет в активном игровом времени.

## Food

Consumable Food уменьшает Hunger.

## Gameplay Effects

Рост Hunger:

- увеличивает Player movement speed;
- увеличивает Player attack damage;
- меняет восприятие других персонажей.

Модификаторы не должны необратимо менять базовые характеристики.

## Starving Perception

В Starving:

- визуальное представление других персонажей заменяется/накладывается образом еды;
- Dialogue визуально превращается в варианты «Съешь меня»;
- реальная Customer Entity и ее gameplay state остаются прежними.

## Будущее расширение

Не реализовывать обязательно, но модель должна позволить позже:

- съесть Customer;
- получать специальные Dialogue choices;
- менять reputation/quests;
- открывать hunger abilities.

## Критерий готовности

Hunger растет, Food снижает его, высокое значение меняет speed/damage и восприятие NPC без разрушения Customer/Dialog logic.
