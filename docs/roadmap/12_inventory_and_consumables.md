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

### Bubble Wrap

Небольшой расходник для Package.

Одно использование на валидной коробке:

- применяет к Package protection modifier, определенный в [ТЗ 06](06_package_damage_and_hazards.md);
- выполняется одним действием, без отдельного мини-режима обмотки;
- уменьшает quantity на один только после успешного применения.

Damage reduction и weak/medium/strong protection tiers принадлежат Package Damage system; Inventory не дублирует эту логику.

## Ownership

У Inventory Item должен быть однозначный owner.

Эта модель позже должна использоваться:

- Trader;
- container;
- loot;
- quest item.

## Критерий готовности

Player может подобрать Food, MedItem и Bubble Wrap, увидеть их в Inventory и использовать; Bubble Wrap одним действием применяет защиту к выбранной Package.
