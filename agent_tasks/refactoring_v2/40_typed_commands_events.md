# Refactoring v2.40 — typed Commands / Events

Status: **PLANNED**

Зависимости: stable domain boundaries.

## Goal

Сделать cross-domain gameplay flow явным: Request/Command означает намерение, Event/Outcome — уже произошедший authoritative факт.

## Work

- инвентаризировать существующие typed requests/events/results;
- выделить повторяемый project contract без нового тяжёлого framework;
- заменить скрытые Service→Service orchestration chains там, где нужен domain boundary;
- сохранить direct synchronous call внутри одного domain, если он проще и корректнее;
- обеспечить idempotency для transaction-like commands, где она уже нужна;
- UI отправляет Commands и читает Events/state, но не становится ECS participant.

## Acceptance

Ключевые cross-domain flows Damage, Commerce, Interaction, Customer outcomes и Quests имеют явные boundaries.
Event не используется как скрытая команда.
Command не объявляет факт до успешного authoritative mutation.

## Validation

Contract tests + профильные domain regressions.
