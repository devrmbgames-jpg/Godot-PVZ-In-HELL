# Refactoring v2.40 — typed Commands / Events

Status: **PLANNED**

Зависимости: [10_service_inventory.md](10_service_inventory.md), [04_identity_persistence_contract.md](04_identity_persistence_contract.md).

## Goal

Закрепить typed-contract foundation до execution migration: Request/Command означает намерение, Event/Outcome — уже произошедший authoritative факт. Владельцы 11–25 используют этот contract сразу, без повторной migration после 27.

## Work

- инвентаризировать существующие typed requests/events/results;
- выделить повторяемый project contract без нового тяжёлого framework;
- мигрировать существующие request/result boundaries и их direct callers в bounded slices, назначенные inventory 10; scheduled orchestration остаётся scope 11–25;
- сохранить direct synchronous call внутри одного domain, если он проще и корректнее;
- обеспечить idempotency для transaction-like commands, где она уже нужна;
- UI отправляет Commands и читает Events/state, но не становится ECS participant.
- Customer/NPC Dialogue ctx methods — narrow read/action API с declared cues/tags, session validity и commit result. Success branch не следует за merely accepted submit; repeated entry и late async result не повторяют mutation и не возобновляют закрытый session. Preserve pinned resource cleanup; generic Dialogue action registry не вводить.

Контракты вводятся **до** execution migration 11–25 и vertical-domain moves. Owner определяется inventory 10, layout ещё horizontal. Для Damage, Commerce, Interaction, Customer outcomes и Quests зафиксировать handler, submit/result semantics, допустимый synchronous call и smallest regression. Завершить все объявленные boundary slices с обновлением callers; не оставлять aliases старого payload/API. Удаление scheduled service dispatchers принадлежит последующим owners, это отдельная ответственность, а не adapter этого milestone. Задача 28 переносит contracts; 33 проверяет границы. Global bus/dispatcher не вводить.

Trace/diagnostics: bounded reason-coded accepted/rejected/completed result, origin/target stable ID и correlation/operation ID. Handler/consumers discoverable по public contract и owning domain, без wildcard subscriptions. Provider tests возникают здесь, UI view — в 48.

## Acceptance

Ключевые cross-domain flows Damage, Commerce, Interaction, Customer outcomes и Quests имеют явные boundaries и contract fixtures; их final execution acceptance проверяется в 27. Single synchronous domain operation не требует отдельной пары Command/Event classes ради единообразия.
Event не используется как скрытая команда.
Command не объявляет факт до успешного authoritative mutation.

## Validation

Contract tests + профильные domain regressions.
