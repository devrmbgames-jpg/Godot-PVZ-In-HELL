# Refactoring v2.24 — Economy, Inventory и Commerce

Status: **PLANNED**

Зависимости: [23_hazards_receiving_loot.md](23_hazards_receiving_loot.md), [13_customer_outcomes.md](13_customer_outcomes.md).

## Goal

Проверить крупные transaction-oriented services и не перенести их в Systems без причины.

## Scope

- `WalletService`;
- inventory services;
- commerce/order purchasing;
- food/effects;
- day summary/economy progression.

## Direction

Transaction API с idempotency (`submit/apply/purchase/transfer`) обычно остаётся Service.
Регулярный day/frame progression должен принадлежать System/Observer.
Derived calculations могут стать Rules/Calculation.

## Acceptance

Сервисный слой экономики остаётся явным и синхронным.
Нет scheduled clock внутри transaction service.
Idempotency operation IDs и save-visible semantics не изменены.

## Validation

Wallet/inventory/commerce профильные tests + parser.
