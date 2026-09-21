# ТЗ 12 — Инвентарь и расходники

## Цель

Создать простой Inventory для небольших предметов.

## Граница

Inventory не заменяет физическое хранение крупных объектов.

Package, Furniture и другие крупные предметы остаются в мире.

Inventory предназначен для:

- Food;
- MedItem;
- небольших расходников;
- ключей;
- мелких utility items.

## Возможности MVP

- pickup;
- ownership;
- stack одинаковых Consumable;
- use;
- уменьшение quantity;
- простой UI.

## Обязательные Consumables

### Food

Уменьшает Hunger.

### MedItem

Восстанавливает Health.

## Ownership

У Inventory Item должен быть однозначный owner.

Эта модель позже должна использоваться:

- Trader;
- container;
- loot;
- quest item.

## Критерий готовности

Player может подобрать Food и MedItem, увидеть их в Inventory и использовать.
