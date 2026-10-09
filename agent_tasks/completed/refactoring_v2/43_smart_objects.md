# Refactoring v2.43 — Smart Objects / Affordances / Reservations

Status: **DONE**

Зависимости: [42_visual_entity_authoring.md](../../refactoring_v2/42_visual_entity_authoring.md), [40_typed_commands_events.md](40_typed_commands_events.md).

## Goal

Сделать единый capability-based язык взаимодействия Entity с миром.

## Scope

- authored Smart Object definition;
- affordances;
- slots/markers;
- reservation Relationships;
- eligibility/preconditions;
- execute/cancel lifecycle;
- common contract для player, LimboAI, quests и Dialogue; future optional GOAP использует тот же API без mandatory implementation здесь.

## Constraints

Smart Object не должен становиться новым gameplay authority. Runtime state хранится в ECS/Relationships; scene markers — authoring/presentation.

Slot = authored marker + stable slot ID; отдельная slot Entity не нужна. Reservation Relationship направлен actor→object и содержит slot/token. Eligibility/executor schema валидируется и доступна в Inspector через тот же provider, что headless. Новая вариация существующего executor не требует script или правки global registry.

## Acceptance

Минимум один существующий service/interaction object (counter/return/delivery point) мигрирован через общий contract без проверки concrete scene class; второй placed/spawned variant использует те же данные/executor. Chair/Sit и Bed/Sleep — optional examples, не обязательные новые gameplay mechanics.

Reservation token/slot exclusivity проверяются при execute и cancel; target loss/death/world removal освобождают связь идемпотентно. Eligibility failure не публикует success; stale token не отменяет новый reservation. Providers ловят missing executor/slot/marker до запуска.

Acquire выполняется одной serialized owning operation без yield между eligibility/exclusivity check и relationship mutation. Occupancy reverse index — derived cache из Relationships, не второй slot authority. Race/conflict fixture доказывает единственного победителя и отсутствие leaked reservation при failed execute.

If structural mutation is deferred, eligibility/exclusivity is checked when the owning queued operation executes, not only when requests enqueue. Caller remains pending until the relation is committed; stale target/slot is rejected at that boundary. Token includes world/session + object incarnation + acquisition sequence; it is transient and is not serialized as durable identity. Late callback from a removed/recreated object or pre-load world cannot release a new reservation even when stable actor/object IDs match. Fixtures cover two queued contenders, object reincarnation and world reload.

## Validation

Reservation/content validation + representative interaction tests.

## Current / Next

Authorized by active Goal. Task42 implementation/re-review passes; required owner visual
acceptance is still pending and does not affect this runtime/schema implementation.
Owner scope: interaction Smart Object C/R, typed definitions/request/receipt, one queued
Observer commit boundary, pure Trait validation, generic interaction adapter, native
package return point and a data-only variant, focused contention/lifetime/return fixtures.
No second occupancy authority or concrete scene-class checks. Reservation is transient.
Implementation, required non-visual verification and immutable independent review **PASS**.
Baseline: `4975105e9eb6da2f1eeabaf8f0a5929a0cf26da3`.
Reviewed target: `9e7a139fbe473107ecf249e6116158a2269999d5`; no material findings.
Reviewer ARCHITECTURE/STYLE PASS; reviewer validation NOT_RUN (main ran the recorded checks).
The generic API and input adapter replace the old independent return-point action provider.
Native wall variant uses the same definition/executor; original action ID/control is preserved.
Same-World accepted restore emits a shared fact before buffer clearing: pending receipts are
rejected and reservations retired, without saving tokens or changing the snapshot schema.
Tree-exit and native relationship retirement disconnect derived lifetime callbacks.
Runtime task43 is complete. Continue task44; task42 required visual acceptance remains open.

## Evidence

- Formatter **PASS**, 17 owned scripts; strict architecture/project structure/agent changes PASS.
- Parser **PASS**, 17 checked / 0 failed.
- Smart Object + actual return GUT **PASS**, 20/20 tests, 136 assertions, no script/runtime errors.
- Affected Smart Object/return/snapshot/startup batch **PASS**, 51/51 tests, 470 assertions
  before the final tree-exit addition; unchanged persistence behavior covered in that batch.
- Authored main-level interaction smoke **PASS**, `R06.1 interaction hands smoke PASS`.
- Logs: `tests/artifacts/refactoring_v2_43_{final_gut,regression,parser,interaction_smoke}.log`.
  Godot 4.7.1 shutdown-only retention is owner-deferred; raw logs retained, no visual QA claimed.
- Product contract/API/authoring: [Smart Objects](../../../docs/smart_objects.md).
