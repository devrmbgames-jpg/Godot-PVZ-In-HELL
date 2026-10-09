# Refactoring v2.11 — CustomerFlow: planning, arrival и day transitions

Status: **DONE** (2026-10-08)

Зависимости: [40_typed_commands_events.md](40_typed_commands_events.md), [10_service_inventory.md](10_service_inventory.md).

## Goal

Убрать из `CustomerFlowService.tick()` planning/day-transition/arrival orchestration и сделать соответствующий execution ownership видимым в ECS graph.

## Scope

Разобрать как минимум:
- arrival cooldown progression;
- `plan_day`;
- package history synchronization;
- morning-only missed registration;
- due followup reactivation;
- `actionable_remaining`;
- `spawn_next_due`.

Дискретные действия, которые должны выполняться один раз на переход фазы/дня, предпочитать Observer/event path вместо polling каждый frame.

## Preserve

- стабильные visit/package/history IDs;
- registration eligibility;
- district vs isolated-scene behavior;
- arrival cooldown semantics;
- CommandBuffer/GECS safety.

## Target shape

`S_CustomerFlow` или несколько узких Systems владеют регулярным scheduling/query.
Morning/day transitions принадлежат отдельному Observer/transition path.
`CustomerFlowService` сохраняет только явные reusable commands/lookups, которым действительно нужен service boundary.

## Acceptance

- planning/arrival graph виден по Systems/Observers и deps;
- отсутствует morning logic, проверяемая каждый обычный frame без причины;
- `CustomerFlowService.tick()` больше не является владельцем этого lifecycle.

Active visit progression остаётся существующим owner до 12: это другой responsibility slice. Planning/arrival/day transitions уже не выполняются вторым legacy path. Не добавлять compatibility API для callers мигрированного planning; active-visit callers принадлежат следующему scope и не дублируют новый planning.

## Validation

Parser changed files + профильные customer timing/flow tests. Не запускать весь проект.

## Result

- `O_CustomerPlanning` owns actual calendar loops, morning-only missed-registration reconciliation
  and due-followup reactivation. `DayPhaseChanged` follows committed phase mutation; bootstrap/load
  reconcile once through derived day/phase cache. Registration facts release due followups in the
  same phase. Explicit debug/data-fixture commands use the sole typed CustomerPlanningRequest handler.
- `S_CustomerFlow` owns arrival cooldown, history synchronization, live actionable count and dispatch
  of selected arrivals before DayPhase/NpcIntent. Service keeps reusable next-arrival lookup and
  one selected-visit materialization command. District role enqueue remains its distinct task-16 slice.
- Removed Service plan_day/sync_package_history/finalize_missed_unregistered/reactivate_due_followups/
  spawn_next_due APIs with all direct callers. No compatibility alias. Test-only helper drives real
  World/Observer/System rather than reimplementing scheduling.
- `CustomerFlowService.tick` contains only active visit/outcome responsibilities pending 12/13;
  it no longer plans, reconciles morning, decrements cooldown, counts arrivals or spawns the queue.
  Architecture budget stays 34; surviving S_CustomerFlow forwarder entry now names its actual
  `_advance` location and task 12. No allowance was increased or introduced.
- Stable visit/package/history IDs, registration gates, district/isolated behavior, configured gap
  and synchronous command-batch live-entity visibility preserved. Pending planning is not reported
  as success; stale queued phase/runtime commands reject before mutation.
- Current-format in-place restore invalidates transient planning cache and arrival cooldown.
  Cache fields are excluded from codecs. No old-save converter, alias or migration was added.

## Validation result

- Core planning/timing/flow/receipts/district-service/shift GUT: **70/70**, **522 assertions**.
- Final planning/timing/shift/in-place restore GUT: **34/34**, **242 assertions** (includes 5 new
  planning fixtures). Current-format snapshot + Phase-1 durable baseline: **19/19**, **375 assertions**.
- Direct-caller batch: **117/121**, 1062/1071 assertions. All customer/challenge/dialogue/remains/debug
  callers passed; four receiving placement failures reproduced unchanged on isolated **pre-task11
  commit 1c52565a**: truck_shift_gate **19/23**, 148/157 assertions. See incoming findings in task 23.
  This additional receiving surface is not claimed PASS and does not alter the task-11 acceptance.
- Additional legacy customer_flow smoke fails its historical eight-box expectation at line 36;
  the script already declares it needs reconciliation with current district supply. No PASS claimed.
  Receiving smoke/fixture alignment belongs to task 23 before the broad 27/49 gates.
- Godot 4.7.1 headless changed-file parser: **PASS**, **28 files**, zero failures/new script warnings.
- Full structure, architecture and persistence baseline validators: **PASS**; scoped diff-check PASS.
  Headless editor import has the known third-party AssetPlacer/extension shutdown diagnostics;
  standalone parser/runtime checks above ran independently. Addons and authored scenes untouched.
- Rendered gameplay/subjective QA not run. No owner QA or product choice required.

Next: 12, split active visit phases and migrate district step_service callers.
