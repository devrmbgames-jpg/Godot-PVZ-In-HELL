# ТЗ 17 — Сценарий вертикального среза

> **Implementation coverage:** Scenario requirements feed several tasks; final end-to-end validation is **R23**.

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
- уходит;
- Player отмечает в Terminal `Забрал`.

Проверяет основной service loop и раздельный actual/declaration contract.

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

## Optional Service / Dispute Path

Минимум один альтернативный walkthrough должен проверить одно из решений Player:

- Customer добровольно отказался, а Package осталась до утреннего возврата/выкупа;
- Player нажал `Потеряна` и получил гарантированный 120% settlement;
- Player отказал в выдаче;
- Player не выдал Package, но указал `Забрал`, создав риск Complaint/aggression.

Вертикальный срез не обязан за один день показывать все 120/150/200% ветки, но underlying contracts должны быть совместимы с ТЗ 07.

Минимум одна Package должна пережить смену дня и остаться активной утром второго дня. Это подтверждает, что поздний Customer/10+ day retention не ломается daily reset.

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

Carry-over Package предыдущего дня остается в учете/мире со своим номером, если её lifecycle не был закрыт.

## Definition of Done

Vertical slice готов, если сценарий можно пройти от Morning первого дня до Morning второго дня без debug-команд и ручной перезагрузки сцены.
