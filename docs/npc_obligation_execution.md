# NPC obligations and native execution

The district roster owns `NpcRecord.planned_day`, `planned_phase`, `goal_id` and
`phase_complete`. `O_DistrictLifecycle` assigns deterministic schedule obligations;
ordinary authored schedules go directly through the native LimboAI schedule subtree.
Emergency, combat, conversation and customer service priority remain visible in the
existing native trees. Utility and GOAP add no runtime path in this milestone.

`C_NpcDecision` owns the transient schedule action incarnation and
ACCEPTED/RUNNING/COMPLETED/FAILED/CANCELLED result. `NpcScheduleActionService` performs
explicit synchronous transitions; it neither selects branches nor advances time.
Moving and finishing share an incarnation, so repeated decision ticks do not restart
the action. The finish leaf queries a receipt; `O_DistrictLifecycle` commits completion
only after validating the captured record, goal, owner, Component and incarnation.
Higher-priority intent cancels execution without completing the obligation. Route timeout
or a missing authored destination fails execution, allowing a later bounded retry.
An explicit street-activity skip retains its existing roster policy and cannot convert a
failed action into successful execution. Home/portal departures still require arrival.

Idle activity selection writes `C_NpcDecision.local_activity_id`, never the required
schedule goal. Its movement continues through the existing intent and body owners.
The current customer role/visit owners retain their existing authoritative lifecycle;
the schedule action state does not duplicate a service visit or combat state.

`S_NpcCadence` publishes at most `DEF_District.decision_work_units` due intervals per
pass (default 12), shared by sampled sensing, traits and native decisions. Route planning
retains its separate authored frame cap. Due records are ordered by stable NPC ID and
selected after the previous cursor, wrapping once. With a fixed eligible roster of N
actors and cap C, all pending actors receive work within ceil(N/C) passes even when an
already processed actor repeatedly requests another wake. Duplicate wakes occupy one
flag per actor. Urgent social reactions and obligation replacement invalidate the old
queued lifecycle generation before fair resampling; they do not create another scheduler.
Inactive bodies do not consume the sampled interval, and paused GameClock stops selection.

`NpcDecisionDiagnostics.actor_state()` returns detached current obligation/source,
selection reason, native owner/behavior, action incarnation/status/reason and local activity.
`budget_state()` reads due/processed/deferred, authored cap, stable cursor and maximum
observed wait in GameClock ticks. These reads never advance or choose behavior. Action
state, pending wakes, cursor and counters are excluded from save authority and reset at
same-world reconstruction; persisted cadence still uses the existing clock contract.

Focused acceptance: `test_npc_obligation_execution.gd`, `test_npc_decision_budget.gd`,
existing district BT/route regressions and the native district queue smoke. Headless
acceptance does not claim visual behavior or game feel.
