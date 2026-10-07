# Refactoring v2.40 — typed Commands / Events

Status: **PLANNED**

Зависимости: [27_architecture_acceptance.md](27_architecture_acceptance.md), [04_identity_persistence_contract.md](04_identity_persistence_contract.md).

## Goal

Сделать cross-domain gameplay flow явным: Request/Command означает намерение, Event/Outcome — уже произошедший authoritative факт.

## Work

- инвентаризировать существующие typed requests/events/results;
- выделить повторяемый project contract без нового тяжёлого framework;
- заменить скрытые Service→Service orchestration chains там, где нужен domain boundary;
- сохранить direct synchronous call внутри одного domain, если он проще и корректнее;
- обеспечить idempotency для transaction-like commands, где она уже нужна;
- UI отправляет Commands и читает Events/state, но не становится ECS participant.

Контракты вводятся **до** vertical-domain moves. На этом шаге owner определяется service inventory, а layout ещё horizontal. Задача 28 переносит уже выбранные public contracts; задача 33 проверяет их границы. Новый global bus/dispatcher не вводить.

Trace/diagnostics: bounded reason-coded accepted/rejected/completed result, origin/target stable ID и correlation/operation ID. Handler/consumers discoverable по public contract и owning domain, без wildcard subscriptions. Provider tests возникают здесь, UI view — в 48.

## Acceptance

Ключевые cross-domain flows Damage, Commerce, Interaction, Customer outcomes и Quests имеют явные boundaries.
Event не используется как скрытая команда.
Command не объявляет факт до успешного authoritative mutation.

## Validation

Contract tests + профильные domain regressions.
