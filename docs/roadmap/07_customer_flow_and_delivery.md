# ТЗ 07 — Поток клиентов и выдача заказов

## Цель

Создать базовую дневную работу ПВЗ.

## Customer Event Schedule

Day состоит из 3–5 клиентских событий.

Завершение смены определяется количеством завершенных обязательных events, а не таймером.

## Customer Lifecycle

Базовые состояния:

```text
Approaching
Waiting
Dialogue
WaitingForPackage
Receiving
OptionalFitting
Leaving
Aggressive
Finished
```

Не каждый Customer обязан использовать все состояния.

## Получение номера

Customer может сообщить package number:

- обычной репликой;
- запиской;
- загадкой;
- косвенной подсказкой.

Базовый Customer сообщает номер напрямую.

## Выдача

Игрок должен:

1. получить номер;
2. самостоятельно найти физическую Package;
3. принести ее;
4. положить на DeliveryCounter;
5. завершить выдачу interaction/dialogue действием.

Package нельзя автоматически телепортировать из хранилища к Customer.

## Проверка

Customer должен различать:

- correct Package;
- wrong Package;
- Damaged Package;
- Opened Package.

## Satisfaction

Результат меняет Customer Satisfaction.

Satisfaction влияет на:

- оплату;
- штраф;
- реплики;
- дальнейший challenge;
- вероятность Aggressive.

## После выдачи

Customer может:

- сразу уйти;
- отказаться;
- перейти в примерочную;
- запустить special event;
- стать Aggressive.

## Критерий готовности

Обычный Customer приходит, сообщает номер, ждет, игрок физически находит нужную коробку, приносит ее и завершает выдачу.
