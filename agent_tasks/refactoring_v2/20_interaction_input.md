# Refactoring v2.20 — Interaction input и action routing

Status: **PLANNED**

Зависимости: [19_hunger_quests.md](19_hunger_quests.md), [10_service_inventory.md](10_service_inventory.md).

## Goal

Проверить, не стал ли `InteractionActionResolver` вторым input scheduler'ом, и сделать приоритеты/ownership видимыми в Interaction Systems.

## Scope

- `InteractionActionResolver.handle_input`;
- `ProlongedInteractionService.tick`;
- focus/capture priorities;
- contextual action routing;
- input edge consumption;
- interaction targeting/highlight boundaries.

## Direction

System владеет регулярным input tick и приоритетным orchestration.
Service/Resolver может остаться, если он разрешает одну явную action request без собственного clock/query lifecycle.
Долгие interaction timers/state progression должны иметь явного scheduled владельца.

## Acceptance

По Interaction Systems можно понять, кто каждый physics tick читает input и в каком порядке.
Нет скрытого generic service tick.

## Validation

Grab/input/interaction tests + parser.
