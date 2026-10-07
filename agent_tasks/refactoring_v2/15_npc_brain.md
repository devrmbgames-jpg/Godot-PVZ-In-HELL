# Refactoring v2.15 — NPC brain, perception и traits

Status: **DONE**

Зависимости: [14_district_lifecycle.md](14_district_lifecycle.md).

## Goal

Убрать `S_NpcDecision -> NpcBrainService.tick` как скрытый AI scheduler, сохранив LimboAI как decision runtime.

## Keep as runtime adapter

`NpcBrainService.install/update_tree/abort` могут оставаться adapter API, потому что они управляют LimboAI runtime.

## Move scheduled ownership

Явно распределить:
- decision interval/budget;
- perception cadence;
- footsteps/noise ageing;
- trait progression;
- service-role advancement;
- BT update scheduling;
- post-decision cleanup.

Не создавать новый Mega-System. Если perception/traits/noise имеют самостоятельную cadence/query — выделить Systems.

## Acceptance

- `NpcBrainService.tick()` удалён или перестал быть scheduler;
- LimboAI tree update остаётся явным узким adapter call;
- AI execution order виден из Systems/deps;
- BT/Blackboard не становится второй authority базой.

## Validation

NPC behavior/performance contracts, BT validator, parser.

## Completed migration

- Removed NpcBrainService.tick, NpcPerceptionService.sense/footsteps and NpcTraitService.tick.
  Migrated every direct runtime/test caller; no compatibility scheduling wrapper remains.
- S_NpcCadence owns eligibility and interval accumulation after district/customer/day commits.
  C_NpcDecision contains one transient captured due interval/day/phase, shared by sampled
  stages. Dormant/dead/night actors cannot accumulate another AI clock.
- Explicit graph: cadence -> footsteps -> all due perception -> traits -> native decisions
  -> noise ageing. S_NpcPerception owns search/hearing timers, S_NpcTraits owns authored
  exposure/retreat progression; pure gaze/vulnerability predicates moved to NpcTraitRules.
- S_NpcDecision publishes NpcDecisionReady with the exact committed due interval before
  native BT. Existing O_CustomerServiceClock remains its sole role-clock writer. Native
  tree update is a narrow adapter call; branch cleanup stays immediate after each update.
- Queued stages capture/revalidate component identity, retained participation and calendar.
  After synchronous ready publication, decision revalidates participation again, preventing
  BT execution if a consumer retired the actor. Blackboard gained no gameplay authority.
- Native install/participation/update/abort adapters remain NpcBrainService. Sight/hear/noise
  operations and authored immunity/aura/refuge commands remain explicit Services/Rules.
- Test-only NpcAiFixture executes real owners through World groups, including isolated
  sensor/trait progression; it does not recreate removed production Service ticks.
- Route tick/pending-budget behavior is intentionally the immediately following dependency
  task 16. Its existing one lexical allowance moved from the removed brain dispatcher to
  S_NpcDecision._decide, with task 16 ownership and unchanged final 26/27 removal gate.
  This is unfinished route scope, not a permanent native-decision Service allowance.

## Acceptance result

**PASS**: hidden brain/perception/trait scheduling removed; interval, sensing, trait, BT and
noise owners/order are explicit, and the native adapter/Blackboard remain narrow runtime glue.

## Validation result

- NPC scheduling/native BT/stage behavior/performance/perception/service queue/hunger/rules
  GUT: **230/230**, **1548 assertions**.
- Final scheduling batch after explicit calendar ordering: **42/42**, **255 assertions**.
  New cases verify all sensors before either native decision, one shared accumulated interval,
  noise consumption before expiry, night/dormant freeze, component replacement at MANUAL
  flush and synchronous ready-consumer death before native update.
- District tree validator: **7 resources, 120 leaves, PASS**.
- Final changed-script Godot parser: **21 files, 0 failures**.
- Actual main-level headless native inspection smoke: **PASS**, repeated after final
  calendar ordering; authored booth walking, parcel return and refusal preserved.
- Structure, architecture (**22** remaining lexical findings), persistence baseline,
  roadmap preflight and diff checks: **PASS**. No old-save migration or visual QA required.
- Headless editor import only refreshed metadata/UIDs; known addon shutdown diagnostics
  are separate from the clean parser/GUT/runtime checks.

Next: [16_npc_route_service_role.md](16_npc_route_service_role.md).
