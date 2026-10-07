# Refactoring v2.40 — typed Commands / Events

Status: **DONE** (2026-10-08)

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
Fixtures include synchronous Observer reentrancy and deferred structural mutation: deps alone does not imply PER_GROUP buffer was flushed. Result after flush, pending before it; no consumer observes half-committed links/state. Terminal facts may be consumed by multiple domain owners for distinct effects, each effect idempotent; there is one handler for a command.

## Validation

Contract tests + профильные domain regressions.

## Result

All five inventory slices 40.D/C/I/U/Q are DONE. [Boundary catalog](../../content/contracts/README.md)
classifies intent/fact/state payloads and records sole handlers, submit/result semantics,
commit points, idempotency and regressions. Synchronous Commerce/outcome/quest APIs are preserved;
no new bus/framework. Scheduled orchestration remains tasks 11–25.

- Damage submit snapshots attribution/incident/correlation/stable target ID; accepted means
  dispatch, DamageResult follows committed HP or an explicit terminal rejection.
- Package opening returns typed pending/committed/rejected receipts; prolonged completion requires
  COMMITTED. All bool callers migrated. Hazard traces follow materialization.
  LightFlickerEvent replaced completely by LightFlickerRequest; channel/UID preserved, no alias.
- Commerce receipts, CustomerVisit flags and quest/wallet operation IDs remain the sole idempotency
  authorities. Diagnostics follow mutations and distinguish completed/duplicate/rejected.
- Dialogue riddle mutation belongs to outcome owner. Closed/invalidated contexts reject late actions;
  panel serializes awaited advancement and checks current session, preserving pinned resource cleanup.
  Tree teardown invalidates the session without re-entering gameplay.
- BoundaryTrace is the sole writer of transient C_BoundaryTrace; detached snapshots, 128-entry limit,
  explicit origin/target IDs, correlation, reason/stage. Save codecs do not serialize it.
  Read-only presentation remains task 48.

Real-World fixtures prove synchronous nested Observer dispatch without replay, pending before MANUAL
flush, deps without PER_GROUP flush, fact after structural link commit and two distinct real idempotent
terminal consumers (O_HealthLifecycle, O_DepletionEffects) of a single DamageResult.

## Validation result

- Godot 4.7.1 headless changed-file parser: **PASS**, 39 files, 0 failures; no project script warnings.
  Autoload-aware utils/parse_gdscript.gd does not load a gameplay scene.
- Final headless GUT: **55/55**, **928 assertions**, 7 suites: boundaries, commerce, customer_dialogue,
  refusal_quest, package_contents, damage_feedback, refactoring_v2_persistence_baseline.
  Includes current-format roundtrip, real links and retained body identity in an isolated slot.
- Earlier domain batch: **60/60**, 691 assertions (dialogue, commerce, quests, contents,
  prolonged session, interaction facts, light circuit).
- Headless doors_contents smoke: **PASS** (360-frame budget).
- Full structure, architecture, persistence baseline, refactoring preflight: **PASS**;
  architecture baseline remains 34 findings until execution migration.
- Scoped git diff --check: **PASS**. Formatter unavailable (gdtoolkit not installed); no formatter
  run claimed. Headless editor import emitted third-party AssetPlacer/extension reload diagnostics;
  clean parser and standalone runtime checks above ran separately. Addons were not changed.
- No rendered gameplay/subjective visual QA. No owner QA required for this milestone.

Next: task 11 planning/arrival/day-transition migration.
