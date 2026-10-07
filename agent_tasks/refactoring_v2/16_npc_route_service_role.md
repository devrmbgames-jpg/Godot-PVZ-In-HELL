# Refactoring v2.16 — NPC route, service role и district behavior

Status: **DONE**

Зависимости: [15_npc_brain.md](15_npc_brain.md).

## Goal

Перенести time-based route/service-role progression в явные Systems, оставив сервисам расчёт маршрута и explicit commands.

## Scope

- `NpcRouteService.tick/process_pending`;
- route interval, stall/blocked timers, per-frame planning budget;
- `C_NpcRoute`;
- scheduled части `NpcServiceRole`;
- social/activity/home-delivery lifecycle, если inventory классифицировал их как scheduled;
- взаимодействие с `S_NpcIntent`.

## Direction

Вероятный целевой дизайн:
- `S_NpcRoute` владеет route state progression/budget;
- route calculation helper остаётся `NpcRouteSolver/Rules` или узким Service;
- explicit enqueue/defer/finish commands могут оставаться service API.

## Acceptance

- route lifecycle и budget видны в ECS graph;
- `NpcRouteService.tick()` отсутствует;
- нет service chain, которая после BT скрытно запускает route scheduler.

## Validation

NPC route/performance/district tests + parser.

## Completed migration

- Removed NpcRouteService.tick/process_pending and the final native-decision route chain.
  S_NpcRoute owns interval/stall/blocked/progress clocks and route abandonment reactions;
  S_NpcRoutePlanning owns FIFO consumption and one planning budget per physics frame.
- Explicit order: native decision -> route progression -> fair route planning -> noise
  ageing and downstream combat/navigation. A captured due interval remains available
  through route progression; native interval accumulation still resets once after BT.
- Remaining authored/native path, risk, refuge and hazard calculations moved to
  NpcRouteSolver, preserving the original script UID. All native leaf, trait, test and
  benchmark references migrated; no old Service class/path or scheduling alias remains.
- C_NpcRoute documents clock/path/waypoint consumers. Systems only sample physical
  positions; Godot/Jolt still integrates the actual body and velocity. S_NpcIntent keeps
  waypoint playback and native movement/avoidance composition.
- Queue commit revalidates district aggregate identity, current intent, body participation,
  pending state and native map iteration. Invalid/cancelled requests are discarded or
  retained for map readiness without spending another actor's fair budget.
- Service-role elapsed/entrance clock was completed in 12 and publication preserved in 15.
  Verified enqueue/defer/finish/suspend/release remain explicit operations. Activity,
  community/social and home-delivery/offers remain selected native actions or one-shot
  event/day operations, as inventory specifies; no additional recurring scheduler exists.
- Removed both route lexical allowances, including the temporary decision call carried
  from 15. Real-owner test fixture separates progress from queue consumption to retain
  fairness, stale-map, timeout, cancellation and hazard assertions.

## Acceptance result

**PASS**: route lifecycle and frame budget are visible in ECS graph, tick/process_pending
Service APIs are gone, and native decision cannot invoke a hidden route scheduler.

## Validation result

- Route performance/district plan/native BT/scheduling/service queue/physical avoidance/
  warehouse navigation/community/home delivery/offers GUT: **264/264**, **1809 assertions**.
- Final scheduling/lifetime batch: **44/44**, **261 assertions**; new MANUAL cases reject
  a departed route body and a replaced district aggregate before mutation.
- Changed-script Godot parser: **16 files, 0 failures**.
- Actual main-level headless native inspection smoke: **PASS**, including authored booth
  navigation, physical parcel return/refusal and migrated route graph.
- Structure, architecture (**20** remaining lexical findings), persistence baseline,
  roadmap preflight and diff checks: **PASS**. UID preserved; current-format state intact.
- Known third-party headless editor-import shutdown diagnostics are separate from the clean
  parser/GUT/runtime results. No rendered or subjective owner QA is required here.

Next: [17_combat.md](17_combat.md).
