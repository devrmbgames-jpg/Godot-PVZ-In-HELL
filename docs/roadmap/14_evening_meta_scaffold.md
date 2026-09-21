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
- Pending Deliveries.

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
