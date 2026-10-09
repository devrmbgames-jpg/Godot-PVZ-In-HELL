# Refactoring v2.20 — Interaction input и action routing

Status: **DONE**

Зависимости: [19_hunger_quests.md](19_hunger_quests.md), [10_service_inventory.md](10_service_inventory.md).

## Goal

Проверить, не стал ли `InteractionActionResolver` вторым input scheduler'ом, и сделать приоритеты/ownership видимыми в Interaction Systems.

## Scope

- `InteractionActionResolver.handle_input`;
- `ProlongedInteractionService.tick`;
- focus/capture priorities;
- contextual action routing;
- input edge consumption;
- interaction targeting/highlight boundaries.

## Direction

System владеет регулярным input tick и приоритетным orchestration.
Service/Resolver может остаться, если он разрешает одну явную action request без собственного clock/query lifecycle.
Долгие interaction timers/state progression должны иметь явного scheduled владельца.

## Acceptance

По Interaction Systems можно понять, кто каждый physics tick читает input и в каком порядке.
Нет скрытого generic service tick.

## Validation

Grab/input/interaction tests + parser.

## Result / Current / Next

DONE: S_InteractionInput owns captured input arbitration, invalid-grip cleanup, focus/drop/channel priorities and active prolonged clock. Native World scheduling and default command-buffer flush make order explicit after input/targeting/proxy setup and before marker continuation. Positive input_tick is consumed once; immutable queued values plus actor/Component/input-tick revalidation prevent stale commands. S_Grab no longer dispatches input; its physical/cache migration remains task 21.

ProlongedInteractionService retains explicit begin/cancel/lookup/cleanup only; no tick/decay. S_ProlongedDecay owns idle query/iteration and S_InteractionInput owns active progression/effect completion. READY cannot begin a competing same-record session. Completion callback cleanup checks its captured Relationship, preserving a distinct reentrantly created session. Required controller removal still cancels participation through O_ProlongedLifecycle.

S_Marker owns pointer/sample/stroke continuation and transient input/capture receipts, with queued tool/grip/Component/input identity. MarkerSessionService retains begin/end; update removed. InteractionTargetingGeometry, InteractionHighlightRules and ProlongedProgressSolver retain their original UIDs, all callers migrated and no compatibility aliases remain.

LightCircuitService commits gameplay state and emits LightCircuitCommitted; O_LightCircuitPresentation projects the committed state, S_LightCircuit reconciles late/loaded lamps through LightCircuitPresentation. Flicker remains presentation intent. PlayerInteractionEvents is a pure committed-fact publisher; O_PlayerInteractionNoise consumes facts, seals position and revalidates source/actor IDs, lifetime and loaded district aggregate before noise creation. No new input source, gameplay priority, balance or subjective visual behavior.

Validation:
- Final 11-surface headless GUT 200/200, 1189 assertions: grab/input/focus/overlay, prolonged session/progress, anchoring, melee, committed events/noise, owner controls, persistent runtime, light circuit/light/gaze challenges. New regressions cover duplicate pointer/input ticks, immutable queued values, input/component/capture replacement, reentrant completion, committed vs deferred projection, and source/aggregate loss for queued noise.
- Godot changed-script parser 52 files PASS; final changed smoke/owner/test parser also PASS.
- Actual main-level/Jolt interaction_actions headless smoke PASS through production Interaction group: keyboard/mouse mapping, scanner/hand channels, Carry ownership/throw, modal terminal capture/release, physical override and no same-frame hand leak. Obsolete removed parcel/body assumptions replaced with a real current package/current CharacterBody player; assertions preserved.
- Architecture PASS (3 bounded findings for 21/25), project structure, persistence baseline, roadmap preflight and diff whitespace PASS. Moves affect no save-visible persisted type/path/shape; schema remains 3.

No rendered gameplay or subjective visual QA performed; no owner/product decision required. Next: 21_grab_push_slots.md. Phase 3 remains prohibited.
