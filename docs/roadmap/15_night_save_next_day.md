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
- активные/невыданные Package и их регистрационные номера;
- Package actual outcome / Terminal declaration, пока lifecycle/dispute не закрыт;
- Complaint/dispute records;
- поздние Customer arrivals, включая Customer, который может прийти через 10+ дней;
- justified retaliation window после подтвержденной ложной Complaint;
- persistent world consequences.

Package не должна исчезать или освобождать номер только потому, что прошла ночь.

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
- Quest Flags;
- активные Package identity, runtime number, physical/persistent state и ownership;
- Customer ↔ RequestedPackage stable identity;
- actual delivery outcome отдельно от Terminal declaration;
- unresolved Complaints/disputes и уже примененные settlement operation IDs;
- future Reputation reason records, необходимые для 7-day retaliation window.

## Критерий готовности

Player заканчивает Evening, ложится спать и начинает следующий Morning с сохраненными состояниями и заказанной доставкой.
