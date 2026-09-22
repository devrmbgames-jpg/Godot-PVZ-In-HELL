# ТЗ 14 — Вечер и заготовка мета-механики

## Цель

Создать минимальный слой долгосрочных решений между сменами.

## Evening

После завершения Day Player получает свободное время.

Доступно:

- исследовать ПВЗ;
- выйти в маленькую внешнюю зону;
- посетить Trader;
- взять Quest;
- купить расходники;
- оформить доставку;
- подготовить помещение.

## Persistent Economy

Минимальные значения:

- Money;
- Penalties;
- CompletedDays;
- Purchased/Unlocked Upgrades;
- Active Quest Flags;
- Pending Deliveries;
- typed Package settlement/dispute records;
- future Reputation hooks/reasons без необходимости реализовывать полный Reputation score в MVP.

## Package Value / Settlements

Каждая Package, участвующая в Customer service, имеет учетную стоимость, отображаемую в Terminal.

Эта стоимость является базой для:

- добровольного выкупа отказной Package — 100%;
- `LOST` — 120%;
- явного отказа Player — 150%;
- подтвержденного скрытого/мошеннического отказа — 200%.

Коэффициенты должны быть data-driven и операции идемпотентны.

Учётная стоимость и рыночная цена содержимого у Trader могут отличаться. Это намеренно создает ситуации, где Player может захотеть присвоить Package ради выгодного содержимого.

Экономическая система должна различать:

- purchase/buyout;
- penalty;
- reward/payment;
- complaint settlement;

чтобы UI, история и будущая Reputation могли понимать причину изменения Money.

## Future Reputation scaffold

Полную Reputation систему можно реализовать позже, но уже сейчас финансовые/Customer outcomes должны выдавать typed reputation reasons.

Минимум различать:

- корректную выдачу;
- Player refusal;
- Lost admission;
- discovered false `TAKEN`;
- voluntary Customer refusal;
- wrongful Customer complaint;
- combat inside/outside justified retaliation window.

## Trader

Один NPC Trader продает:

- Food;
- MedItem;
- один utility consumable.

## Terminal Order

Через Terminal Player может оформить заказ на следующую доставку.

Покупка:

1. проверяет стоимость;
2. списывает/резервирует Money;
3. создает PendingDelivery;
4. предмет появляется в следующем Morning.

## Future Upgrades

Создать data-заготовки:

```text
LabelPrinter
Cart
BetterScanner
StorageUpgrade
```

Полностью реализовывать все upgrades в vertical slice не требуется.

## Quest MVP

Один Quest:

```text
«Не выдавай посылку №XXXX»
```

Quest связан с конкретной Package.

Результат может быть:

- Completed;
- Failed;
- Ignored/Expired.

## Критерий готовности

В Evening Player может купить расходник, оформить доставку на следующий день и взять Quest, состояние которого переживает переход дня.
