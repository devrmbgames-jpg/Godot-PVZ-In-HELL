# ТЗ 15 — Ночь, завершение дня и следующий цикл

## Цель

Замкнуть core loop в повторяемый игровой цикл.

## Sleep

В Evening Player использует SleepPoint.

Перед переходом:

- завершается текущий день;
- фиксируются Money/Penalties;
- сохраняется persistent state;
- обрабатываются PendingDeliveries;
- увеличивается DayIndex;
- очищаются daily states;
- создается новый Morning.

## Daily Reset

Сбрасываются:

- Customer Event Schedule;
- временные Challenge states;
- дневные Dialogue states;
- временные Hazards, если не помечены persistent;
- временные interaction reservations.

Не сбрасываются без отдельного правила:

- Money;
- Health;
- Hunger;
- purchases;
- upgrades;
- quest flags;
- PendingDeliveries;
- persistent world consequences.

## Next Morning Delivery

Заказанные ранее предметы появляются утром как физическая доставка/контейнер поставки.

## Save MVP

Достаточно одного autosave slot.

Минимально сохранять:

- DayIndex;
- Money;
- Health;
- Hunger;
- purchased/unlocked upgrades;
- PendingDeliveries;
- Quest Flags.

## Критерий готовности

Player заканчивает Evening, ложится спать и начинает следующий Morning с сохраненными состояниями и заказанной доставкой.
