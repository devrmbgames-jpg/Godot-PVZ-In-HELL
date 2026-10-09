# Refactoring v2.12 — CustomerFlow: активный lifecycle визита

Status: **DONE**

Зависимости: [11_customer_flow_planning.md](11_customer_flow_planning.md).

## Goal

Вынести регулярный lifecycle активного Customer из монолитного `CustomerFlowService` в явное scheduled ECS поведение.

## Scope

Разобрать `_step/step_service` и фазовое состояние Customer:
- queued/approaching/waiting/service/dialogue/inspection/leaving/aggressive;
- timers и timeout progression;
- intent/navigation handoff;
- disappearance/death cleanup;
- связь Customer ↔ visit ↔ package.

Не переносить код механически в один огромный System. Если разные фазы имеют разные scheduling/query contracts — разделить их.

## Service boundary

Оставить в Service только хорошо названные one-shot operations, например lookup/bind/finish/explicit transition, если они действительно переиспользуются из разных владельцев.

## Acceptance

- регулярный Customer lifecycle читается из `S_*` и query/deps;
- Service не владеет generic per-frame `_step`;
- не появляется новый hidden dispatcher под другим именем.

Временные adapters внутри этого scope удалены до DONE; visit phases не выполняются и в Service, и в System. Outcome transactions могут оставаться scope 13, но их однократный commit path сохраняется уже здесь.

## Validation

Customer flow/service/inspection профильные GUT + parser изменённых файлов.

## Current / Acceptance result (2026-10-08)

PASS. Removed generic `CustomerFlowService._step/step_service` and the recurring
Arrival/Greeting/Inspection Service ticks. No compatibility aliases or second phase clocks.

- `S_CustomerClock` owns isolated elapsed time and parcel binding. `S_CustomerGreeting`
  requests first contact, then captures a transient phase snapshot. Approach, Waiting,
  Inspection and Departure Systems declare separate phase queries/deps and consume that
  snapshot without executing a newly entered phase again in the same step.
- `S_CustomerCleanup` owns orphan/death appearance cleanup and attribution;
  `S_CustomerVisitPresence` closes disappeared appearances. Arrival clock/history remain
  in `S_CustomerFlow`; `S_CustomerArrivals` projects remaining visits and selects the next
  appearance after terminal phase commits, preserving the former tick ordering.
- District service decisions remain native LimboAI leaves. The actual hidden clock was
  `NpcServiceRole.advance` called by `NpcBrainService`, not the unused `step_service` API.
  Removed `advance`; `NpcDecisionReady` captures the committed perception interval and
  `O_CustomerServiceClock` synchronously applies scalar role/entrance clocks before BT.
  This also closes the shared clock part of inventory slice 16.B; task 15 must preserve
  the due-step fact when migrating its publisher. The structural flush mode cannot
  defer or repeat these scalar writes.
- `CustomerGreetingRequest` has one `O_CustomerGreeting` handler; isolated scheduling
  and the authored wait-for-parcel BT leaf share first-contact eligibility/ray checks.
  Announce/begin/result/bind/inspection/finish/transition commands remain synchronous.
- Retained bodies, physical ownership, authored phase enum values/messages and intent
  APIs are preserved. `scheduled_phase` is a derived per-step cache excluded from saves.
  Current-format saves only; old-save migration is not required by the owner.
- `CustomerFlowService.tick` now contains only settlement/complaint polling, explicitly
  unfinished scope 13. All nested active phase/clock dispatch has been removed.

## Validation result

- Final focused GUT: **113/113**, **883 assertions** across customer timing/handoff/
  inspection/introductions, challenge light, district service and district service queue.
- Flow/dialogue/planning/gaze/inspection/shift regressions: **83/83**, **829 assertions**.
  Covers disappearance, player death attribution and remaining-event visibility after cleanup.
- Added meaningful cadence/snapshot fixtures: one isolated delta increment, distinct
  arrival/greeting steps, district clock excluded from isolated frames and unaffected by
  MANUAL structural buffer flush. Migrated direct `_step/tick/advance` test callers.
- Corrected one inherited district fixture to create a new context after `end()`;
  task 40 intentionally seals a closed context. It now also asserts closed-context reuse fails.
- Godot changed-script parser: **31 files, 0 failures**, no relevant script diagnostics.
- Actual main-level headless inspection smoke: **PASS** (native walk to authored booth,
  return/refusal, physical parcel reservation/release). No rendered gameplay or visual QA.
- Structure, architecture (**29** remaining lexical findings), persistence baseline and
  roadmap preflight validators: **PASS**. Removed all five closed tick/query allowances.
- Headless editor import only refreshed class/UID metadata; existing third-party shutdown
  diagnostics remain distinct from the clean standalone parser/runtime checks.

Next: [13_customer_outcomes.md](13_customer_outcomes.md). No owner gameplay/visual QA is needed for this gate.
