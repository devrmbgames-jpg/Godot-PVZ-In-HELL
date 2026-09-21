# ТЗ 17 — Сценарий вертикального среза

## Цель

Объединить системы в один полностью проходимый игровой день.

## Morning

В приемке появляются:

1. Normal Package;
2. Fragile Package;
3. Heavy Package;
4. Liquid Package;
5. Hazard Package;
6. еще 1–3 обычных заказа.

Player:

- сканирует Package;
- видит номера на Terminal;
- вручную маркирует часть коробок;
- раскладывает их;
- может случайно или намеренно повредить/открыть.

## Day — Customer 1

Обычный Customer:

- приходит;
- сообщает номер;
- ждет;
- получает правильную Package;
- уходит.

Проверяет основной service loop.

## Day — Customer 2

Customer с Light Challenge:

- требует включить или выключить свет;
- дает ограниченное время;
- затем просит Package;
- wrong/damaged/opened Package влияет на Satisfaction.

## Day — Customer 3

Customer с Don't Look или Keep Looking:

- запускает horror pressure;
- Player одновременно ищет Package;
- failure способен привести к Aggressive.

## Optional Package Event

Разрушение Hazard Package создает ToxicLeak или Explosion.

Событие возникает из gameplay/physics, а не обязательного scripted trigger.

## Combat Path

Один Customer способен стать Aggressive.

Player может:

- использовать melee;
- бросать тяжелые предметы;
- блокировать проход коробками;
- использовать помещение для маневра.

## Evening

После завершения дневных Customer Events:

- смена закрывается;
- доступен Trader;
- можно купить Food/MedItem;
- можно взять Quest;
- можно заказать предмет на завтра.

## Night

Player использует SleepPoint.

Начинается новый Morning.

PendingDelivery доставлена.

## Definition of Done

Vertical slice готов, если сценарий можно пройти от Morning первого дня до Morning второго дня без debug-команд и ручной перезагрузки сцены.
