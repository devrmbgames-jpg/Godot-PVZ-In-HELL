# Refactoring v2.13 — Customer outcomes, settlement и reactive transitions

Status: **DONE**

Зависимости: [12_customer_flow_runtime.md](12_customer_flow_runtime.md).

## Goal

Отделить outcome/settlement/reactive последствия от регулярного Customer tick и убрать polling там, где результат уже является дискретным событием.

## Scope

Аудировать:
- `CustomerOutcomeService`;
- complaint resolution;
- settlement/payment;
- delivered/lost/refused/fraud/missed registration;
- inspection completion;
- customer death/disappearance outcomes;
- challenge/customer outcome bridge.

## Direction

- one-shot финансовая операция может оставаться Service transaction;
- реакция на завершённый outcome должна быть Observer/event там, где это естественно;
- presentation/dialogue не становится authority;
- idempotency IDs и существующая экономика сохраняются.

## Acceptance

- outcome authority и settlement boundary явно разделены;
- нет повторного frame polling уже завершённых состояний без необходимости;
- однократность платежей/штрафов сохранена.

## Validation

Customer outcome + wallet/economy regression tests, parser.

## Current / Acceptance result (2026-10-08)

PASS. Removed the final `CustomerFlowService.tick` and `_settle_visit` polling paths.
Outcome mutations and synchronous wallet transactions remain in CustomerOutcomeService;
reactive reconciliation belongs to explicit Observers. No old tick, compatibility alias
or hidden replacement scheduler remains in this scope.

- `CustomerOutcomeChanged` targets the owning flow/day session with stable visit identity.
  `O_CustomerOutcomes` reconciles eligible committed record changes, appearance/death/role
  closure facts and day/bootstrap facts. Completed complaints are not polled each frame.
- `CustomerOutcomeService.settle` is the single transaction eligibility boundary. A delivered
  TAKEN receipt waits while its appearance has an ARMED/ACTIVE challenge or uncommitted
  pending consequences. The same gate covers explicit home-delivery and declaration callers.
  Financial IDs, rates, flags and wallet journal idempotency are preserved.
- Complaint delay is gameplay-day based: calendar entry/bootstrap attempts pending complaints
  once. Explicit debug/manual resolution remains a synchronous transaction. Missing optional
  wallets retry on an explicit command or calendar/bootstrap reaction, without frame polling.
- Morning overdue marking keeps the planning command's explicit optional wallet endpoint;
  its record receipt does not silently substitute a currently available global wallet.
- `O_CustomerChallengeOutcome` replaces the polling System. ChallengeResolution.EVENT follows
  actual terminal state/payload mutation; consequences commit at the Observer's real flush,
  then publish the visit change that releases settlement. Replayed/stale results cannot
  repeat satisfaction, escalation or payment. `ChallengeSessionClosed` is a distinct cleanup
  fact for cancellation; it cannot pretend to be another success/failure resolution.
- Physical removal and retained-role release publish after the live gate is gone. Death
  attribution changes publish even for already-finished records. No presentation authority.
- Preserved bridge script UID and escalation signal; migrated actual game_world node/path,
  scheduling deps, test fixtures and historical smoke caller. Before raw scene migration,
  MCP reported no connected editor and process inspection confirmed no Godot Editor.
- Current-format restore still invalidates the planning cache; its next bootstrap fact
  reconciles restored outstanding transactions. No old-save migration is required.

## Validation result

- Final outcome/wallet/dialogue/complaint/inspection/light/gaze/floor GUT: **134/134**,
  **1250 assertions**, including seven new event/deferred/replay/calendar/cancel/removal fixtures.
- Home delivery, district service queue, current-format world snapshot and customer timing
  regression GUT: **92/92**, **637 assertions**.
- Godot changed-script parser: **20 files, 0 failures**; relevant script diagnostics clean.
- Actual main-level headless inspection smoke: **PASS**, including migrated World wiring,
  authored booth navigation, physical parcel return/refusal and clean teardown.
- Structure, architecture (**27** remaining lexical findings), persistence baseline, roadmap
  preflight and diff checks: **PASS**. Both final CustomerFlow execution allowances removed.
- Headless editor import refreshed metadata only; existing third-party import/shutdown
  diagnostics are separate from the clean parser/GUT/runtime results.

Next: [14_district_lifecycle.md](14_district_lifecycle.md). No owner visual/gameplay QA is required here.
